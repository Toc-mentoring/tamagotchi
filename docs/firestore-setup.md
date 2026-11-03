# Firestore 데이터 계층 설정

설계 문서의 제안에 따라 Cloud Firestore 기본 데이터베이스와 Node.js/TypeScript용 Firebase Admin SDK를 사용합니다. 현재 업무 API와 앱은 없으며, 저장 모델과 연결·초기 마이그레이션 기반을 제공합니다. 게임 수치는 [기획 결정 사항](open-decisions.md)을 참고하세요.

## 구성

- [backend/src/models.ts](../backend/src/models.ts): 저장 문서의 TypeScript 타입. 저장된 데이터의 런타임 검증이나 API 응답 형식은 아닙니다.
- [backend/src/paths.ts](../backend/src/paths.ts): 문서 경로와 친구·반려동물 쌍의 결정적 ID. 정렬한 경로를 JSON 배열로 직렬화해 SHA-256으로 해시합니다.
- [backend/src/db.ts](../backend/src/db.ts): 명시적인 프로젝트 ID와 Application Default Credentials(ADC)를 이용한 서버 연결.
- [backend/src/migrations/001_initial.ts](../backend/src/migrations/001_initial.ts): 스키마 메타데이터를 초기화합니다. 실행 기록과 같은 트랜잭션에서 적용하며, 사용자와 게임 데이터는 생성하지 않습니다.
- [backend/firestore.rules](../backend/firestore.rules): 앱의 Firestore 직접 접근을 차단합니다. Admin SDK는 규칙을 우회하므로 서버에서 토큰·소유권 검증을 구현해야 합니다.
- [backend/firestore.indexes.json](../backend/firestore.indexes.json): 설계상 예상되는 초기 인덱스입니다. 실제 쿼리를 구현한 후 추가 검증이 필요합니다.

## 로컬 실행

Node.js 20 이상, Java와 Firebase CLI가 필요합니다. 저장소 루트에서 두 터미널을 열고 각각 `backend`로 이동합니다. 첫 터미널에서 의존성을 설치하고 에뮬레이터를 시작합니다.

```powershell
cd backend
npm install
firebase emulators:start --only firestore --project demo-pocketwalk
```

다른 터미널에서도 같은 프로젝트 ID를 사용합니다.

```powershell
cd backend
$env:FIREBASE_PROJECT_ID = "demo-pocketwalk"
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
npm run migrate
npm test
```

에뮬레이터 호스트에 프로토콜을 넣지 않습니다. 에뮬레이터 데이터는 기본적으로 종료 시 사라집니다. [공식 연결 문서](https://firebase.google.com/docs/emulator-suite/connect_firestore)

## 실제 Firebase 프로젝트 연결

1. Firebase 프로젝트에서 Firestore 기본 데이터베이스를 만들고 위치·결제 설정을 확인합니다. 서버 계정에 필요한 IAM 권한을 부여하고 [ADC](https://cloud.google.com/docs/authentication/provide-credentials-adc)를 설정합니다. 자격 증명 파일은 저장소에 넣지 않습니다.
2. 대상 프로젝트의 기존 규칙과 인덱스를 확인한 뒤 `backend`에서 아래 명령을 실행합니다. 기존 설정이 변경될 수 있으므로 배포 전에 차이를 확인하세요.

```powershell
firebase deploy --only firestore --project YOUR_PROJECT_ID
```

3. 같은 프로젝트의 초기 마이그레이션을 실행합니다. 실환경에서는 프로젝트 ID를 두 번 명시해야 하며, 에뮬레이터 환경 변수는 제거합니다.

```powershell
Remove-Item Env:FIRESTORE_EMULATOR_HOST -ErrorAction SilentlyContinue
$env:FIREBASE_PROJECT_ID = "YOUR_PROJECT_ID"
$env:ALLOW_LIVE_MIGRATION = "YOUR_PROJECT_ID"
npm run migrate
```

결과는 `applied` 또는 `already applied`로 표시됩니다. 기록과 스키마 메타데이터가 일치하지 않으면 덮어쓰지 않고 중단합니다. 초기화는 DB 생성, 인덱스 배포, 사용자 초기화 또는 API 서버 시작을 대신하지 않습니다. 후속 스키마 변경은 별도 마이그레이션을 작성해야 합니다. 게임 상태 변경과 명령 기록은 같은 트랜잭션으로 처리하고, 외부 푸시는 트랜잭션 안에서 호출하지 않습니다. [공식 트랜잭션 문서](https://firebase.google.com/docs/firestore/manage-data/transactions)
