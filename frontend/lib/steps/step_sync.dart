import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// 폰의 걸음(안드로이드 Health Connect / 아이폰 HealthKit)을 읽어서 서버로 보낸다.
class StepSync {
  StepSync._();
  static final instance = StepSync._();

  final _health = Health();
  bool _configured = false;

  /// 웹(크롬)에서는 걸음을 읽을 수 없다
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  String get _platform => Platform.isIOS ? 'IOS' : 'ANDROID';
  String get _provider => Platform.isIOS ? 'HEALTHKIT' : 'HEALTH_CONNECT';

  /// 앱 설치마다 만드는 기기 ID (폰에 저장해 두고 계속 같은 값을 쓴다)
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('deviceId');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('deviceId', id);
    }
    return id;
  }

  /// 이 기기를 서버에 등록하고 대표 기기로 지정 (앱 시작 때)
  Future<void> registerDevice() async {
    if (!supported) return;
    final id = await _deviceId();
    await Api.instance.registerDevice(id, _platform);
    await Api.instance.setStepSource(id);
  }

  /// 걸음 읽기 권한 확인 → 없으면 권한 창 띄우기
  Future<bool> _ensurePermission() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
    const types = [HealthDataType.STEPS];
    const access = [HealthDataAccess.READ];
    if (await _health.hasPermissions(types, permissions: access) == true) return true;
    return _health.requestAuthorization(types, permissions: access);
  }

  /// 오늘 0시부터 지금까지 걸음을 읽어서 서버에 저장
  Future<StepSyncResult?> syncToday() async {
    if (!supported) return null;
    if (!await _ensurePermission()) throw Exception('걸음 수 읽기 권한이 필요해요.');

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${now.year}-${two(now.month)}-${two(now.day)}';

    return Api.instance.putSteps(
      date: date,
      deviceId: await _deviceId(),
      provider: _provider,
      totalSteps: steps,
      observedAt: now.toUtc(),
    );
  }
}
