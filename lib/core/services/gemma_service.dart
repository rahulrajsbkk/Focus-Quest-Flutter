import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gemma 4 E4B (LiteRT-LM) from the ungated `litert-community` repo.
const String kGemmaModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/'
    'resolve/main/gemma-4-E4B-it.litertlm';

/// Filename with extension — the id `FlutterGemma.isModelInstalled` expects
/// (it keys the model repository by the URL basename, not the base name).
const String kGemmaModelFilename = 'gemma-4-E4B-it.litertlm';

/// Approximate on-disk size, shown in the settings UI.
const String kGemmaModelSizeLabel = '~4.3 GB';

const int _kMaxTokens = 4096;

/// System persona for the conversational chat.
const String _kChatSystemPrompt =
    'You are Focus Quest, a warm, concise companion for people with ADHD. '
    'Help the user reflect on their day, untangle distractions, and find one '
    'small next step. Keep replies short, encouraging, and free of jargon.';

/// Thin wrapper around `flutter_gemma` for the on-device assistant.
///
/// Owns at most one loaded [InferenceModel] + conversational [InferenceChat].
/// One-shot extraction (e.g. journal inference) runs in a throwaway session via
/// [generateOnce] so it never pollutes the chat history.
class GemmaService {
  factory GemmaService() => _instance;
  GemmaService._();
  static final GemmaService _instance = GemmaService._();

  bool _initialized = false;
  InferenceModel? _model;
  InferenceChat? _chat;

  /// Whether a model + chat session are loaded in memory and ready to use.
  bool get isLoaded => _chat != null;

  /// Initializes the plugin once. Cheap and idempotent.
  Future<void> initialize({String? huggingFaceToken}) async {
    if (_initialized) return;
    await FlutterGemma.initialize(huggingFaceToken: _clean(huggingFaceToken));
    if (kReleaseMode) {
      FlutterGemma.logLevel = GemmaLogLevel.none;
    }
    _initialized = true;
  }

  /// Whether the model file is already present on disk.
  Future<bool> isModelInstalled({String? huggingFaceToken}) async {
    await initialize(huggingFaceToken: huggingFaceToken);
    return FlutterGemma.isModelInstalled(kGemmaModelFilename);
  }

  /// Downloads (and registers) the model, yielding progress from 0 to 100.
  ///
  /// Emits an error on the stream if the download fails or is cancelled.
  Stream<int> downloadModel({
    CancelToken? cancelToken,
    String? huggingFaceToken,
  }) {
    final controller = StreamController<int>();
    unawaited(_runDownload(controller, cancelToken, huggingFaceToken));
    return controller.stream;
  }

  Future<void> _runDownload(
    StreamController<int> controller,
    CancelToken? cancelToken,
    String? huggingFaceToken,
  ) async {
    try {
      await initialize(huggingFaceToken: huggingFaceToken);
      var builder =
          FlutterGemma.installModel(
                modelType: ModelType.gemma4,
                fileType: ModelFileType.litertlm,
              )
              .fromNetwork(
                kGemmaModelUrl,
                token: _clean(huggingFaceToken),
                foreground: true,
              )
              .withProgress(controller.add);
      if (cancelToken != null) {
        builder = builder.withCancelToken(cancelToken);
      }
      await builder.install();
      controller.add(100);
    } on Object catch (e, s) {
      controller.addError(e, s);
    } finally {
      await controller.close();
    }
  }

  /// Loads the model into memory and opens the conversational chat session.
  ///
  /// Re-registers the installed file as the active model first — required on
  /// every launch because the active-model spec isn't persisted, and idempotent
  /// (no re-download when the file is already present).
  Future<void> loadModel({String? huggingFaceToken}) async {
    await initialize(huggingFaceToken: huggingFaceToken);
    if (_chat != null) return;

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(kGemmaModelUrl, token: _clean(huggingFaceToken)).install();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: _kMaxTokens,
      preferredBackend: PreferredBackend.gpu,
    );
    _chat = await _model!.createChat(
      modelType: ModelType.gemma4,
      systemInstruction: _kChatSystemPrompt,
      temperature: 1,
      topK: 64,
      topP: 0.95,
    );
  }

  /// Sends a user message and streams the assistant's reply token-by-token.
  ///
  /// Internal "thinking" segments are not surfaced as chat text.
  Stream<String> sendMessage(String text) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Gemma model not loaded. Call loadModel() first.');
    }
    await chat.addQuery(Message.text(text: text, isUser: true));
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  /// Runs a one-shot prompt in a throwaway, low-temperature session and returns
  /// the full text. Used for structured extraction (e.g. journal inference) so
  /// the conversational chat history stays clean.
  Future<String> generateOnce(
    String prompt, {
    required String systemInstruction,
  }) async {
    final model = _model;
    if (model == null) {
      throw StateError('Gemma model not loaded. Call loadModel() first.');
    }
    final session = await model.openChat(
      modelType: ModelType.gemma4,
      systemInstruction: systemInstruction,
      temperature: 0.2,
    );
    final buffer = StringBuffer();
    try {
      await session.addQuery(Message.text(text: prompt, isUser: true));
      await for (final response in session.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }
    } finally {
      await session.close();
    }
    return buffer.toString();
  }

  /// Frees the loaded model and chat session.
  Future<void> unload() async {
    await _chat?.close();
    _chat = null;
    await _model?.close();
    _model = null;
  }

  /// Deletes the downloaded model file from disk.
  Future<void> deleteModel() async {
    await unload();
    await initialize();
    await FlutterGemma.uninstallModel(kGemmaModelFilename);
  }

  static String? _clean(String? token) =>
      (token != null && token.isNotEmpty) ? token : null;
}

/// Singleton accessor for [GemmaService].
final gemmaServiceProvider = Provider<GemmaService>((ref) => GemmaService());
