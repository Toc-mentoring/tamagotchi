import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models.dart';

/// 서버가 보낸 오류 { error: { code, message } }
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// 백엔드 API 호출. 로그인한 사용자의 Firebase ID 토큰을 자동으로 붙인다.
class Api {
  Api._();
  static final instance = Api._();

  // 크롬(웹)에서는 내 PC 주소, 안드로이드 에뮬레이터에서는 10.0.2.2가 내 PC
  static String get baseUrl => kIsWeb ? 'http://127.0.0.1:3000/v1' : 'http://10.0.2.2:3000/v1';
  final _uuid = const Uuid();

  // ----- 화면에서 쓰는 API -----

  /// 첫 로그인 때 사용자·첫 알·지갑 생성 (이미 있으면 그대로)
  Future<void> bootstrap(String nickname) => _send('POST', '/me/bootstrap', {'nickname': nickname});

  /// 홈 화면 데이터
  Future<HomeData> home() async => HomeData.fromJson(await _get('/home'));

  /// 돌보기 (FEED, CLEAN, PLAY, MEDICINE, SLEEP)
    /// 펫 하나 (알 돌보기 화면)
  Future<Pet> pet(String id) async => Pet.fromJson((await _get('/pets/$id'))['pet'] as Map<String, dynamic>);

  /// 최근 7일 걸음 (산책 기록 화면)
  Future<StepSummary> weekSummary() async => StepSummary.fromJson(await _get('/steps/summary?period=WEEK'));
  
  Future<Map<String, dynamic>> care(String petId, String action) =>
      _send('POST', '/pets/$petId/care-actions', {'action': action, 'itemId': null});

  // ----- 공통 -----

  Future<Map<String, String>> _headers({bool write = false}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
      if (write) 'Idempotency-Key': _uuid.v4(), // 변경 요청마다 새 키
    };
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic> body) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(await _headers(write: true))
      ..body = jsonEncode(body);
    return _decode(await http.Response.fromStream(await req.send()));
  }

  Map<String, dynamic> _decode(http.Response res) {
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return json['data'] as Map<String, dynamic>;
    final error = (json['error'] as Map<String, dynamic>?) ?? {};
    throw ApiException(res.statusCode, error['code'] as String? ?? 'UNKNOWN', error['message'] as String? ?? '오류가 발생했어요.');
  }
}