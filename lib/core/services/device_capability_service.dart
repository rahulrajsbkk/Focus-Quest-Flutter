import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device can run the on-device AI assistant, and if not, why.
@immutable
class DeviceCapability {
  const DeviceCapability({required this.aiSupported, this.reason});

  final bool aiSupported;

  /// Human-readable reason shown in the UI when [aiSupported] is false.
  final String? reason;
}

/// Minimum physical RAM (in MB) needed for the Gemma 4 E4B model. Its weights
/// are ~4.3 GB, so realistically an 8 GB-class device is required.
const int kMinRamMb = 7000;

/// Minimum Android SDK level. Matches the app's `minSdk` and LiteRT-LM's floor.
const int kMinAndroidSdk = 26;

const String _kLowRamReason =
    'The AI assistant needs a more powerful device (about 8 GB of RAM).';
const String _kCheckFailedReason =
    'Could not determine whether this device supports the AI assistant.';

/// Probes the device to decide whether the on-device Gemma model is viable.
///
/// Used to gate the AI feature: the chat tab and settings entry only appear
/// when [DeviceCapability.aiSupported] is true.
class DeviceCapabilityService {
  factory DeviceCapabilityService() => _instance;
  DeviceCapabilityService._();
  static final DeviceCapabilityService _instance = DeviceCapabilityService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DeviceCapability? _cached;

  /// Returns the (cached) capability result.
  Future<DeviceCapability> check() async {
    return _cached ??= await _check();
  }

  Future<DeviceCapability> _check() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const DeviceCapability(
        aiSupported: false,
        reason: 'The AI assistant is only available on Android and iOS.',
      );
    }

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        if (!info.isPhysicalDevice) {
          return const DeviceCapability(
            aiSupported: false,
            reason:
                'The AI assistant needs a physical device, not an '
                'emulator.',
          );
        }
        if (info.version.sdkInt < kMinAndroidSdk) {
          return const DeviceCapability(
            aiSupported: false,
            reason: 'The AI assistant needs Android 8.0 or newer.',
          );
        }
        if (info.isLowRamDevice || info.physicalRamSize < kMinRamMb) {
          return const DeviceCapability(
            aiSupported: false,
            reason: _kLowRamReason,
          );
        }
        return const DeviceCapability(aiSupported: true);
      }

      // iOS
      final info = await _deviceInfo.iosInfo;
      if (!info.isPhysicalDevice) {
        return const DeviceCapability(
          aiSupported: false,
          reason: 'The AI assistant needs a physical device, not a simulator.',
        );
      }
      if (info.physicalRamSize < kMinRamMb) {
        return const DeviceCapability(
          aiSupported: false,
          reason: _kLowRamReason,
        );
      }
      return const DeviceCapability(aiSupported: true);
    } on Object catch (e) {
      debugPrint('DeviceCapabilityService: capability check failed: $e');
      return const DeviceCapability(
        aiSupported: false,
        reason: _kCheckFailedReason,
      );
    }
  }
}

/// Resolves once per app launch; the chat tab and AI settings watch this.
final deviceCapabilityProvider = FutureProvider<DeviceCapability>((ref) async {
  return DeviceCapabilityService().check();
});
