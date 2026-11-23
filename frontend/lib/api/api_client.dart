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

  // 웹·폰 모두 내 PC 서버 (폰은 adb reverse tcp:3000 tcp:3000 필요)
  static String get baseUrl => 'http://127.0.0.1:3000/v1';
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

  /// 걸음 기록 (period: DAY 또는 WEEK, endDate: YYYY-MM-DD)
  Future<StepSummary> stepSummary({required String period, required String endDate}) async =>
      StepSummary.fromJson(await _get('/steps/summary?period=$period&endDate=$endDate'));
  
  /// 내 친구 코드
  Future<String> friendCode() async => (await _get('/me/friend-code'))['friendCode'] as String;

  /// 친구 목록
  Future<FriendList> friends() async => FriendList.fromJson(await _get('/friends?limit=100'));

  /// 친구 코드로 친구 추가
  Future<Friend> addFriend(String code) async =>
      Friend.fromJson((await _send('POST', '/friends', {'friendCode': code}))['friend'] as Map<String, dynamic>);

  /// 친구 숲 방문 기록
    /// 친구 숲 방문 (방문 기록 + 친구 펫 정보)
  Future<FriendVisit> visitFriend(String friendUid) async =>
      FriendVisit.fromJson(await _send('POST', '/friend-visits', {'friendUid': friendUid}));

  /// 청혼하기
  Future<void> propose({required String recipientUid, required String senderPetId, required String recipientPetId}) =>
      _send('POST', '/proposals', {
        'recipientUid': recipientUid,
        'senderPetId': senderPetId,
        'recipientPetId': recipientPetId,
      });
  Future<Map<String, dynamic>> care(String petId, String action) =>
      _send('POST', '/pets/$petId/care-actions', {'action': action, 'itemId': null});

  /// 기기 등록
  Future<void> registerDevice(String deviceId, String platform) =>
      _send('PUT', '/devices/$deviceId', {'platform': platform, 'pushToken': null});

  /// 대표 기기 지정 (이 기기의 걸음만 서버가 받는다)
  Future<void> setStepSource(String deviceId) => _send('PUT', '/me/step-source', {'deviceId': deviceId});

  /// 그날 걸음 저장
  Future<StepSyncResult> putSteps({
    required String date,
    required String deviceId,
    required String provider,
    required int totalSteps,
    required DateTime observedAt,
  }) async =>
      StepSyncResult.fromJson(await _send('PUT', '/steps/days/$date', {
        'deviceId': deviceId,
        'provider': provider,
        'totalSteps': totalSteps,
        'observedAt': observedAt.toIso8601String(),
      }));
  /// 상점 상품 목록
  Future<List<Product>> products() async => ((await _get('/products?category=ALL'))['items'] as List)
      .map((p) => Product.fromJson(p as Map<String, dynamic>))
      .toList();

  /// 내 보관함
  Future<List<InventoryItem>> inventory() async => ((await _get('/inventory'))['items'] as List)
      .map((i) => InventoryItem.fromJson(i as Map<String, dynamic>))
      .toList();

  /// 상품 1개 구매 → 남은 포인트
  Future<Wallet> purchase(String productId) async => Wallet.fromJson(
      (await _send('POST', '/purchases', {'productId': productId, 'quantity': 1}))['wallet'] as Map<String, dynamic>);

  /// 친구에게 선물 (내 보관함에서 1개 차감)
  Future<void> gift({required String recipientUid, required String itemId}) =>
      _send('POST', '/gifts', {'recipientUid': recipientUid, 'itemId': itemId, 'quantity': 1});

  /// 내 아이들 목록 + 지금 키우는 아이 id
  Future<(List<Pet>, String?)> myPets() async {
    final data = await _get('/pets?limit=100');
    final pets = (data['items'] as List).map((p) => Pet.fromJson(p as Map<String, dynamic>)).toList();
    return (pets, data['activePetId'] as String?);
  }

  /// 희귀 알 사용 → 새 알 (아직 키우는 아이로 바뀌지는 않음)
  Future<Pet> createPet(String sourceItemId) async =>
      Pet.fromJson((await _send('POST', '/pets', {'sourceItemId': sourceItemId}))['pet'] as Map<String, dynamic>);

  /// 키울 아이 바꾸기
  Future<void> activatePet(String petId) => _send('POST', '/pets/$petId/activate', {});

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