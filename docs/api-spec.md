# API 명세 v0.1

이 문서는 구현을 위한 **제안 계약**이다. 실제 배포 주소·로그인 방법·게임 수치는 미확정이다. 앱은 Firebase Authentication SDK로 로그인하고 ID 토큰을 발급받는다. 아래 API는 앱 서버가 제공할 업무 기능이며 Firebase 로그인 API 자체가 아니다.

## 공통 규칙

| 항목 | 규칙 |
| --- | --- |
| Base URL | `https://{api-host}/v1` — 배포 주소 미정 |
| 인증 | 모든 엔드포인트에 `Authorization: Bearer {Firebase ID token}`. 서버는 토큰을 검증한 뒤 `uid`를 사용한다. |
| 형식 | JSON, UTF-8. 날짜는 `YYYY-MM-DD`, 시간은 UTC ISO 8601 문자열 |
| 일자 기준 | 임시로 `Asia/Seoul`. 다른 시간대의 정책은 [D13](open-decisions.md#걸음성장-정책) |
| 변경 요청 | `POST`, `PUT`, `PATCH` 모두 `Idempotency-Key: {client-generated-UUID}` 필수. 같은 사용자·메서드·경로·키와 동일 본문을 72시간 안에 재요청하면 최초 성공 응답을 반환한다. |
| 키 보관 | 성공 응답을 72시간 보관하는 안. 모든 성공한 변경 요청은 사용자·메서드·경로·키에서 파생한 명령 ID와 본문 해시도 영속 보관한다. 같은 키에 다른 본문을 보내면 `409 IDEMPOTENCY_CONFLICT`. 응답이 만료된 동일 요청은 `409 ALREADY_PROCESSED`와 명령 ID 및 존재하면 기존 리소스 ID를 반환한다. 실패 요청은 성공 기록을 남기지 않는다. |
| 목록 | `limit` 기본 20, 최대 100; `cursor`는 직전 응답의 `meta.nextCursor`를 그대로 사용한다. 정렬과 필터를 바꾸면 처음부터 조회한다. |
| 소유권 | `me`와 내 데이터는 토큰의 `uid` 기준. 친구 상세·선물·청혼은 친구 관계와 참여자 여부를 서버에서 확인한다. |

성공 시 `GET`·`PUT`·`PATCH`와 별도 표시가 없는 `POST`는 `200`을 반환한다. `POST /pets`, `/purchases`, `/gifts`, `/proposals`, `/friend-visits`의 새 리소스 생성은 `201`이다. `POST /friends`는 새 관계일 때 `201`, 이미 친구일 때 `200`이다.

성공 응답은 다음 형식을 사용한다. `meta.nextCursor`는 목록에만 있고, 다음 페이지가 없으면 `null`이다.

```json
{ "data": { "id": "pet_123" }, "meta": { "requestId": "req_123" } }
```

오류 응답:

```json
{
  "error": {
    "code": "INSUFFICIENT_POINTS",
    "message": "포인트가 부족합니다.",
    "details": { "balance": 40, "required": 60 },
    "requestId": "req_123"
  }
}
```

| HTTP | 대표 코드 | 의미 |
| --- | --- | --- |
| 400 | `INVALID_ARGUMENT` | 형식·범위 오류, 미래 날짜 등 |
| 401 | `UNAUTHENTICATED` | ID 토큰 누락·만료·검증 실패 |
| 403 | `FORBIDDEN` | 본인·친구·청혼 참여자 권한 없음 |
| 404 | `NOT_FOUND` | 접근 가능한 대상이 없음 |
| 409 | `IDEMPOTENCY_CONFLICT`, `ALREADY_PROCESSED`, `STALE_STEP_SNAPSHOT`, `STEP_SOURCE_MISMATCH`, `ACTIVE_PET_REQUIRED`, `PET_NOT_ACTIVE`, `INSUFFICIENT_POINTS`, `INSUFFICIENT_ITEMS`, `PET_NOT_ADULT`, `NOT_FRIENDS`, `PROPOSAL_NOT_PENDING` | 요청 충돌 또는 현재 상태에서 처리 불가 |
| 429 | `RATE_LIMITED` | 코드 조회·상태 변경 등의 호출 제한 초과 |
| 503 | `TEMPORARILY_UNAVAILABLE` | 일시적 서비스 장애. 같은 키·본문으로 재시도 가능 |

## 공통 객체

아래 표에서 `?`는 `null`이 될 수 있음을 뜻한다. ID는 불투명 문자열이며 숫자가 아니다.

| 객체 | 필드 |
| --- | --- |
| `User` | `uid`, `nickname`, `friendCode`, `activePetId?`, `stepSourceDeviceId?`, `timeZone`, `createdAt` |
| `Pet` | `id`, `ownerUid`, `name`, `stage` (`EGG`, `BABY`, `TEEN`, `ADULT`), `speciesId?`, `growthSteps`, `growthRuleVersion`, `stageProgress`, `stats?`, `careScore?`, `createdAt` |
| `stageProgress` | `currentSteps`, `requiredSteps?`, `remainingSteps?`, `percent?`, `nextStage?`; 어른이면 다음 단계 관련 값은 `null` |
| `stats` | `satiety`, `happiness`, `cleanliness`, `health` — 정수 0~100. 알 단계는 `null` 가능 |
| `StepDay` | `date`, `totalSteps?`, `goalSteps`, `pointsEarned`, `isSynced`, `lastSyncedAt?`. 미동기화 시 `totalSteps=null`, `isSynced=false` |
| `Wallet` | `balance`, `todayEarned` — 0 이상의 정수 포인트 |
| `Product` | `id`, `itemId`, `name`, `category` (`FOOD`, `RARE_EGG`, `TOY`, `MEDICINE`), `price`, `effectText`, `imageUrl?`, `available` |
| `InventoryItem` | `itemId`, `name`, `category`, `quantity`, `effectText`, `imageUrl?` |
| `Friend` | `uid`, `nickname`, `pet?` (`id`, `name`, `stage`, `speciesId?`, `careScore?`), `todaySteps?`, `lastSeenAt?`. 공개하지 않는 값은 `null` |
| `Proposal` | `id`, `senderUid`, `recipientUid`, `senderPetId`, `recipientPetId`, `status` (`PENDING`, `ACCEPTED`, `DECLINED`, `CANCELED`), `createdAt`, `resolvedAt?`, `familyId?` |
| `SpeciesEntry` | `speciesId`, `name?`, `imageUrl?`, `discovered`, `firstDiscoveredAt?`, `discoverySource?` (`OWN_GROWN`, `FRIEND_VISIT`), `firstPetId?`. 미발견 정보 노출은 기획 미결정 |
| `Notification` | `id`, `type` (`CARE`, `HATCH`, `GROWTH`, `PROPOSAL`, `GIFT`, `WALK_SUMMARY`), `title`, `body`, `createdAt`, `readAt?`, `targetType?`, `targetId?` |
| `NotificationSettings` | `pushEnabled`, `care`, `hatch`, `growth`, `proposal`, `gift`, `walkSummary` — 모두 boolean, 해당 유형의 푸시 수신 여부 |

`StepDay.pointsEarned`는 그 날짜의 걸음으로 적립된 포인트이고, `Wallet.todayEarned`는 과거 걸음의 지연 동기화를 포함해 **오늘 지급된** 포인트 합계다.

## 화면별 주요 API

| 화면 | 주요 조회 및 행동 |
| --- | --- |
| 홈 | `GET /home`, `POST /pets/{petId}/care-actions` |
| 알 부화 | `GET /pets/{petId}`, `PUT /steps/days/{date}` |
| 걸음 기록 | `GET /steps/summary`, `PUT /steps/days/{date}` |
| 상점 | `GET /products`, `POST /purchases`, `GET /inventory` |
| 친구 목록 | `GET /me/friend-code`, `GET /friends`, `POST /friends`, `POST /friend-visits`, `POST /gifts` |
| 친구 방문과 청혼 | `GET /friends/{friendUid}/visit`, `POST /proposals` 및 수락·거절·취소 API |
| 도감 | `GET /encyclopedia` |
| 알림함 | `GET /notifications`, 읽음·모두 읽음·설정 API, 필요한 경우 청혼 수락 API |

## 계정·공통

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `POST /me/bootstrap` | `{ "nickname": "지우" }` | `{ "user": User, "pet": Pet, "wallet": Wallet, "created": true }`. 최초 1회 초기화; 이미 초기화된 계정은 기존 데이터와 `created=false` |
| `GET /me` | 없음 | `{ "user": User }` |
| `PATCH /me` | `{ "nickname": "새 이름" }` | `{ "user": User }` |
| `GET /home` | 없음 | `{ "user": User, "pet": Pet?, "today": StepDay, "wallet": Wallet, "unreadCount": 3 }` |
| `GET /me/friend-code` | 없음 | `{ "friendCode": "...", "qrPayload": "pocketwalk://friend?code=..." }` |
| `PUT /devices/{deviceId}` | `{ "platform": "ANDROID", "pushToken": "..." }` | `{ "deviceId": "...", "platform": "ANDROID" }`. `platform`은 `ANDROID`/`IOS`; `pushToken`은 null 가능 |
| `PUT /me/step-source` | `{ "deviceId": "..." }` | `{ "stepSourceDeviceId": "..." }`. 등록된 본인 기기만 대표 기기로 설정 |

`deviceId`는 앱 설치 단위의 무작위 식별자다. 식별자 자체가 기기의 진위나 걸음 데이터의 진위를 증명하지는 않는다.

## 반려동물·돌봄

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `GET /pets` | `cursor`, `limit` | `{ "items": [Pet], "activePetId": "..." }` |
| `GET /pets/{petId}` | 없음 | `{ "pet": Pet, "active": true }`. 알 부화 화면은 `stageProgress`를 사용 |
| `POST /pets` | `{ "sourceItemId": "moon_egg" }` | `{ "pet": Pet, "inventoryItem": InventoryItem }`. 알 아이템 1개를 소비해 비활성 알 생성 |
| `POST /pets/{petId}/activate` | `{}` | `{ "activePetId": "...", "pet": Pet }` |
| `POST /pets/{petId}/care-actions` | `{ "action": "FEED", "itemId": "carrot" }` | `{ "pet": Pet, "inventoryItem": InventoryItem?, "appliedEffects": { "satiety": 20 } }` |

`action`은 `FEED`, `CLEAN`, `PLAY`, `MEDICINE`, `SLEEP`. 소비할 아이템이 없는 행동은 `itemId=null`; 아이템 필요 여부·적용량·재사용 조건은 서버 규칙으로 검증한다. 알에는 돌봄 행동을 적용하지 않는다. 한 번의 행동에서 아이템 차감, 상태 변경, 행동 기록과 알림 이벤트를 원자적으로 저장한다.

## 걸음 동기화와 산책 기록

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `PUT /steps/days/{date}` | 아래 예시. 앱에서 읽은 **해당 일자의 누적 합계** | `{ "day": StepDay, "wallet": Wallet, "activePet": Pet, "creditedSteps": 1240, "pointsGranted": 12, "transitions": ["HATCHED"] }`. `transitions` 값은 `HATCHED`, `BECAME_TEEN`, `BECAME_ADULT` |
| `GET /steps/days/{date}` | 없음 | `{ "day": StepDay }`; 아직 수집하지 않은 날짜는 미동기화 `StepDay` |
| `GET /steps/summary` | `period=DAY\|WEEK`, `endDate=YYYY-MM-DD` | `{ "period", "startDate", "endDate", "days": [StepDay], "totalSteps", "syncedDays", "averageSteps?", "goalAchievedDays", "previousPeriodSyncedDays", "previousPeriodChangePercent?" }` |

요청 예시:

```http
PUT /v1/steps/days/2026-11-02
Authorization: Bearer <Firebase-ID-token>
Idempotency-Key: 7f9fa256-c499-4f3e-959f-995e2ed21c42
Content-Type: application/json

{
  "deviceId": "device_123",
  "provider": "HEALTH_CONNECT",
  "totalSteps": 6240,
  "observedAt": "2026-11-02T07:00:00Z"
}
```

처리 규칙은 기획 확정 전의 임시안이다.

1. `provider`는 `HEALTH_CONNECT` 또는 `HEALTHKIT`; 대표 기기와 플랫폼이 맞아야 한다. 가입일을 포함한 이후 날짜 중 오늘 포함 최근 7일만 동기화하고 미래 일자·음수는 거절한다. 가입 당일의 첫 합계에는 가입 전 걸음이 포함될 수 있다.
2. `observedAt`은 앱이 합계를 관측한 UTC 시간이다. 서버 현재 시각보다 5분 넘게 미래이거나 형식이 잘못되면 `400 INVALID_ARGUMENT`. 이미 처리한 스냅샷보다 과거이거나 같으면 `409 STALE_STEP_SNAPSHOT`. 단, 같은 멱등 키·본문의 성공 재시도는 저장된 성공 응답을 돌려준다.
3. 표시용 `totalSteps`는 가장 최근 관측값으로 대체하므로 원본 수정으로 감소할 수 있다. 일자별 `creditedHighWater`는 감소하지 않는다.
4. 새 최대 걸음이 기존 최대보다 커지면 차이만 성장에 더한다. 포인트는 `floor(새 최대/100) - floor(기존 최대/100)`만 지급한다. 감소분에 대한 회수는 하지 않는다. 예: 최초 6,240걸음이면 6,240 성장 걸음·62P, 같은 값 재전송이면 추가 0, 이후 7,000이면 추가 760걸음·8P.
5. 새로 인정된 성장 걸음은 **동기화 시점의 활성 개체**에 더한다. 지연 동기화에서 실제 걷던 때의 개체와 달라질 수 있다. 활성 개체가 없다면 `409 ACTIVE_PET_REQUIRED`로 거절해 걸음을 소비하지 않는다.
6. 일별 갱신·포인트 원장·반려동물 성장·전환 이벤트를 한 트랜잭션으로 처리한다. 단계별 기준은 개체에 고정된 규칙 버전의 누적 걸음으로 해석하고, 한 번의 동기화에서 여러 기준을 넘으면 순서대로 전환하며 초과분도 누적한다. 기기 교체 시에도 일별 최대 보상 기준은 유지하고 둘 이상의 기기 합계를 서로 더하지 않는다.

`DAY`는 종료일 1일, `WEEK`는 종료일 포함 7일이다. 미동기화 일자를 `days`에 `totalSteps=null`로 포함한다. 임시 평균은 동기화된 일자의 합계를 `syncedDays`로 나누어 가장 가까운 정수로 반올림한 값이고, 동기화된 일자가 없으면 `null`이다. 목표 달성은 동기화 일자만 센다. 현재 또는 직전 기간에 동기화되지 않은 날짜가 있거나 직전 기간의 합계가 0이면 비교율은 `null`이다. 오늘은 당일 중간 집계일 수 있으므로 비교 표시에도 그 사실을 함께 안내한다.

## 상점·보관함

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `GET /products` | `category=ALL\|FOOD\|RARE_EGG\|TOY\|MEDICINE`, `cursor`, `limit` | `{ "items": [Product] }` |
| `GET /inventory` | `cursor`, `limit` | `{ "items": [InventoryItem] }` |
| `POST /purchases` | `{ "productId": "carrot", "quantity": 1 }` | `{ "purchaseId": "...", "wallet": Wallet, "inventoryItem": InventoryItem }` |
| `GET /wallet/transactions` | `cursor`, `limit` | `{ "items": [{ "id": "...", "amount": -60, "type": "PURCHASE", "createdAt": "..." }] }` |

구매 수량은 양의 정수다. 서버가 현재 판매 가능 여부와 가격을 확인하고, 잔액 검사·차감·아이템 지급·원장 기록을 원자적으로 처리한다. 실제 가격, 수량 상한과 구매 확인 UI는 미결정이다.

## 친구 방문 선물 청혼

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `POST /friends` | `{ "friendCode": "..." }` | `{ "friend": Friend, "created": true }`. 임시 정책은 상대 수락 없이 양방향 친구 생성 |
| `GET /friends` | `cursor`, `limit` | `{ "items": [Friend], "totalCount": 12 }` |
| `POST /friend-visits` | `{ "friendUid": "..." }` | `{ "visitId": "...", "friend": Friend, "pet": Friend.pet?, "canPropose": true, "newDiscovery": SpeciesEntry? }`. 방문 기록과 성체 첫 발견을 처리 |
| `GET /friends/{friendUid}/visit` | 없음 | `{ "friend": Friend, "pet": Friend.pet?, "canPropose": true }`. 읽기 전용 새로고침. 친구가 아닌 사용자는 접근 불가. 상대의 상세 `stats` 등 비공개 필드는 반환하지 않음 |
| `POST /gifts` | `{ "recipientUid": "...", "itemId": "carrot", "quantity": 1 }` | `{ "giftId": "...", "senderInventoryItem": InventoryItem }` |
| `POST /proposals` | `{ "senderPetId": "...", "recipientPetId": "..." }` | `{ "proposal": Proposal }` |
| `GET /proposals/{proposalId}` | 없음 | `{ "proposal": Proposal, "eggPreview": { "parentTraitLabels": ["잎사귀", "볼"], "isGuaranteed": false } }` |
| `POST /proposals/{proposalId}/accept` | `{}` | `{ "proposal": Proposal, "familyId": "...", "myEgg": Pet }` |
| `POST /proposals/{proposalId}/decline` | `{}` | `{ "proposal": Proposal }` |
| `POST /proposals/{proposalId}/cancel` | `{}` | `{ "proposal": Proposal }` |

청혼 생성 시 발신자 본인의 활성 어른 반려동물과 친구의 활성 어른 반려동물인지 확인한다. 중복 청혼과 여러 관계의 허용 범위는 [D21](open-decisions.md#상점친구가족-정책)에서 확정한다. 임시로 동일 개체 쌍의 `PENDING` 청혼은 하나만 허용한다. 수신자만 수락·거절하고 발신자만 취소한다. 상태는 `PENDING → ACCEPTED | DECLINED | CANCELED`로 단방향 전환하며 이미 처리된 요청에는 `409 PROPOSAL_NOT_PENDING`을 반환한다. 동일 멱등 키의 성공 재시도는 72시간 안에 최초 응답을 반환한다.

수락 트랜잭션은 두 사용자가 여전히 친구이고 청혼 당시의 두 개체가 여전히 각자의 활성 어른 개체인지 다시 확인한 뒤 상태를 `ACCEPTED`로 바꾸고 가족 관계와 **각 소유자에게 별도 알 1개씩** 생성한다. 응답의 `myEgg`는 요청자인 수신자의 알이다. 상대 알은 상대 사용자에게만 표시하며 알림으로 안내한다. 선물은 친구인지 검증한 뒤 발신자 보관함에서 수량을 차감하고 수신자 보관함에 추가한다. 선물·청혼 결과 알림은 별도 알림 문서로 저장한다.

## 도감

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `GET /encyclopedia` | `filter=ALL\|DISCOVERED\|UNDISCOVERED`, 선택 `search`, `cursor`, `limit` | `{ "totalCount": 24, "discoveredCount": 8, "discoveryRatePercent": 33, "items": [SpeciesEntry] }` |

임시 정책에서는 종별 첫 발견만 기록한다. 내 개체가 어른이 되거나 친구 집에서 어른 종을 처음 만나면 발견 처리한다. 목록은 발견된 종을 첫 발견 시간 오름차순으로 먼저 표시하고, 미발견 종은 고정 도감 순서로 뒤에 표시한다. 검색·필터와 페이지 이동은 이 순서에 적용한다. 응답의 24·8·33은 예시다.

## 알림·설정

| 메서드와 경로 | 요청 | 성공 시 `data` |
| --- | --- | --- |
| `GET /notifications` | `filter=ALL\|UNREAD`, `cursor`, `limit` | `{ "items": [Notification], "unreadCount": 3 }` |
| `PATCH /notifications/{notificationId}` | `{ "read": true }` | `{ "notification": Notification }` |
| `POST /notifications/read-all` | `{ "before": null, "cursor": null }` | `{ "before": "...", "processed": 100, "nextCursor": "...", "complete": false }` |
| `GET /me/notification-settings` | 없음 | `{ "settings": NotificationSettings }` |
| `PATCH /me/notification-settings` | `{ "pushEnabled": false, "care": false }`; 전달된 필드만 변경 | `{ "settings": NotificationSettings }` |

모두 읽음은 첫 요청에서 서버가 정한 `before` 시각까지의 안 읽은 알림을 최대 100개씩 처리한다. `complete=false`이면 응답의 `before`와 `nextCursor`를 다음 요청에 전달하고 새 멱등 키를 사용한다. 기준 시각 이후 새로 생성된 알림은 읽지 않음으로 유지된다. 푸시 설정 변경은 알림함 기록 생성과 별개이며, 앱에 보이는 청혼 수락 버튼은 청혼 수락 API를 호출한다.
