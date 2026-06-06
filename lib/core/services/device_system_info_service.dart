import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class DeviceSystemInfo {
  const DeviceSystemInfo({
    required this.platform,
    required this.cpuCores,
    required this.cpuModel,
    required this.gpuModel,
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.totalStorageBytes,
    required this.freeStorageBytes,
    required this.abis,
  });

  final String platform;
  final int cpuCores;
  final String cpuModel;
  final String gpuModel;
  final int totalRamBytes;
  final int availableRamBytes;
  final int totalStorageBytes;
  final int freeStorageBytes;
  final List<String> abis;

  bool get hasStorageInfo => totalStorageBytes > 0;
  bool get hasRamInfo => totalRamBytes > 0;
}

class DeviceSystemInfoService {
  static const MethodChannel _channel = MethodChannel(
    'gena/device_system_info',
  );

  Future<DeviceSystemInfo>? _inFlight;
  DeviceSystemInfo? _cached;

  Future<DeviceSystemInfo> getInfo({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) {
      return Future.value(_cached);
    }
    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _loadInfo();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<DeviceSystemInfo> _loadInfo() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('getInfo');
      if (raw == null) {
        final fallback = _fallbackInfo();
        _cached = fallback;
        return fallback;
      }
      final info = DeviceSystemInfo(
        platform: (raw['platform'] as String?) ?? Platform.operatingSystem,
        cpuCores: _asInt(raw['cpuCores']) ?? Platform.numberOfProcessors,
        cpuModel: (raw['cpuModel'] as String?)?.trim().isNotEmpty == true
            ? (raw['cpuModel'] as String).trim()
            : 'Unknown CPU',
        gpuModel: (raw['gpuModel'] as String?)?.trim().isNotEmpty == true
            ? (raw['gpuModel'] as String).trim()
            : 'Unknown GPU',
        totalRamBytes: _asInt(raw['totalRamBytes']) ?? 0,
        availableRamBytes: _asInt(raw['availableRamBytes']) ?? 0,
        totalStorageBytes: _asInt(raw['totalStorageBytes']) ?? 0,
        freeStorageBytes: _asInt(raw['freeStorageBytes']) ?? 0,
        abis: ((raw['abis'] as List<Object?>?) ?? const <Object?>[])
            .map((value) => value?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      );
      _cached = info;
      return info;
    } on PlatformException {
      final fallback = _fallbackInfo();
      _cached = fallback;
      return fallback;
    }
  }

  DeviceSystemInfo _fallbackInfo() {
    return DeviceSystemInfo(
      platform: Platform.operatingSystem,
      cpuCores: Platform.numberOfProcessors,
      cpuModel: 'Unknown CPU',
      gpuModel: 'Unknown GPU',
      totalRamBytes: 0,
      availableRamBytes: 0,
      totalStorageBytes: 0,
      freeStorageBytes: 0,
      abis: const <String>[],
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
