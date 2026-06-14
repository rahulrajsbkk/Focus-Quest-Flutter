import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/gemma_service.dart';

/// Lifecycle of the on-device model file.
///
/// "Ready to chat" (model loaded into memory) is handled lazily by
/// ChatNotifier on the first message — this state machine only tracks the
/// downloaded file on disk.
sealed class GemmaModelState {
  const GemmaModelState();
}

/// Model file is not on disk yet.
class GemmaNotInstalled extends GemmaModelState {
  const GemmaNotInstalled();
}

/// Model file is downloading. [progress] is 0–100.
class GemmaDownloading extends GemmaModelState {
  const GemmaDownloading(this.progress);
  final int progress;
}

/// Model file is present on disk.
class GemmaInstalled extends GemmaModelState {
  const GemmaInstalled();
}

/// A download or check failed.
class GemmaModelError extends GemmaModelState {
  const GemmaModelError(this.message);
  final String message;
}

class GemmaModelNotifier extends AsyncNotifier<GemmaModelState> {
  GemmaService get _service => ref.read(gemmaServiceProvider);
  CancelToken? _cancelToken;

  String? get _token =>
      dotenv.isInitialized ? dotenv.maybeGet('HUGGINGFACE_TOKEN') : null;

  @override
  Future<GemmaModelState> build() async {
    final installed = await _service.isModelInstalled();
    return installed ? const GemmaInstalled() : const GemmaNotInstalled();
  }

  /// Downloads the model, streaming progress into the state.
  Future<void> download() async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const AsyncData(GemmaDownloading(0));
    try {
      await for (final progress in _service.downloadModel(
        cancelToken: cancelToken,
        huggingFaceToken: _token,
      )) {
        state = AsyncData(GemmaDownloading(progress));
      }
      state = const AsyncData(GemmaInstalled());
    } on Object catch (e) {
      if (cancelToken.isCancelled) {
        state = const AsyncData(GemmaNotInstalled());
      } else {
        state = AsyncData(GemmaModelError(_describe(e)));
      }
    } finally {
      _cancelToken = null;
    }
  }

  /// Cancels an in-flight download.
  void cancelDownload() => _cancelToken?.cancel('Cancelled by user');

  /// Deletes the model file and unloads it from memory.
  Future<void> deleteModel() async {
    try {
      await _service.deleteModel();
    } on Object {
      // Best-effort: even if deletion fails, treat the model as gone so the
      // user can re-download.
    }
    state = const AsyncData(GemmaNotInstalled());
  }

  String _describe(Object e) {
    if (e is BackendInitException || e is BackendInitAttemptFailure) {
      return 'This device could not start the AI engine.';
    }
    return 'The download failed. Check your connection and try again.';
  }
}

final gemmaModelProvider =
    AsyncNotifierProvider<GemmaModelNotifier, GemmaModelState>(
      GemmaModelNotifier.new,
    );
