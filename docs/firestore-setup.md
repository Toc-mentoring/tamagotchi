# Firestore 데이터 계층 설정

백엔드는 Node.js/TypeScript와 Firebase Admin SDK를 사용합니다. Firestore 저장 모델, 경로, 초기 스키마 마이그레이션, 보안 규칙과 인덱스 설정이 있으며, 현재 초기 마이그레이션은 메타데이터만 기록합니다. 사용자·반려동물 데이터는 만들지 않습니다.

## 구성

- [backend/src/models.ts](../backend/src/models.ts): 저장 문서의 TypeScript 타입. 런타임 검증이나 API 응답 형식은 아닙니다.
- [backend/src/paths.ts](../backend/src/paths.ts): 문서 경로와 결정적 ID.
- [backend/src/db.ts](../backend/src/db.ts): 명시한 프로젝트 ID와 Application Default Credentials(ADC)로 서버를 연결합니다.
- [backend/src/migrations/001_initial.ts](../backend/src/migrations/001_initial.ts): `system/schema` 메타데이터를 초기화합니다.
- [backend/firestore.rules](../backend/firestore.rules): 앱의 Firestore 직접 접근을 차단합니다. Admin SDK는 규칙을 우회하므로 서버에서 인증·소유권을 검사해야 합니다.
- [backend/firestore.indexes.json](../backend/firestore.indexes.json): 예상 복합 인덱스 설정입니다. 실제 쿼리 적용 후 다시 확인해야 합니다.
- [backend/.env.example](../backend/.env.example): 백엔드 환경변수 예시. 복사한 `backend/.env`는 Git에서 제외됩니다.

`backend/.env`는 Node 백엔드 전용입니다. Flutter 앱 설정 파일로 사용되지 않습니다.

## 준비

1. Firebase Console에서 Firebase 프로젝트를 만들거나 기존 프로젝트를 선택하고, Cloud Firestore의 기본 데이터베이스를 생성합니다. 데이터베이스 위치를 확인하세요. 이미 데이터가 있다면 기존 규칙·인덱스·문서를 먼저 검토합니다.
2. [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)를 설치하고 로컬 개발자 계정으로 ADC를 설정합니다. Firebase CLI가 없다면 `npm install -g firebase-tools`로 설치합니다. Firestore Emulator를 사용할 경우 Java도 필요합니다.

   ```powershell
   gcloud auth application-default login
   ```

   Firebase Admin SDK는 이 ADC를 사용합니다. 별도 서비스 계정 키를 사용할 수도 있지만 키 JSON을 `.env`나 저장소에 넣지 마세요. Firebase CLI 배포를 위해서는 별도로 `firebase login`을 실행합니다.
3. `backend` 디렉터리에서 의존성을 설치하고 환경 파일을 만듭니다.

   ```powershell
   cd backend
   npm install
   if (-not (Test-Path .env)) { Copy-Item .env.example .env }
   ```

   `backend/.env`에서 `FIREBASE_PROJECT_ID`를 Firebase 프로젝트의 **Project ID**로 바꿉니다. 표시 이름이나 앱 ID가 아닙니다. 로컬 Node 실행은 Node.js 20.6 이상이어야 합니다.

## 먼저 로컬 에뮬레이터에서 실행

`backend/.env`에서 프로젝트 ID를 `demo-pocketwalk`로 설정하고 `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` 행의 주석을 해제합니다. `ALLOW_LIVE_MIGRATION`은 빈 값으로 둡니다. 첫 번째 터미널에서 에뮬레이터를 실행합니다.

```powershell
cd backend
firebase emulators:start --only firestore --project demo-pocketwalk
```

두 번째 터미널에서도 `backend`를 현재 디렉터리로 두고 초기 마이그레이션을 실행합니다.

```powershell
cd backend
npm run migrate
```

결과가 `demo-pocketwalk: applied 001_initial`이면 새로 적용된 것이고, `already applied`이면 해당 메타데이터가 이미 있습니다. 에뮬레이터 데이터는 별도 내보내기 설정이 없으면 종료 후 유지되지 않습니다. Admin SDK는 `FIRESTORE_EMULATOR_HOST`가 설정되어 있으면 Firestore 에뮬레이터에 연결합니다. 호스트 값에 `http://`를 붙이지 않습니다. [에뮬레이터 연결 공식 문서](https://firebase.google.com/docs/emulator-suite/connect_firestore)

## 실제 Firebase 프로젝트에 적용

에뮬레이터에 먼저 적용한 뒤, 대상이 맞는지 확인하고 진행합니다.

1. `backend/.env`에서 실제 `FIREBASE_PROJECT_ID`를 설정합니다. `FIRESTORE_EMULATOR_HOST` 행은 주석 상태로 둡니다. 실제 쓰기를 허용하기 위해서만 `ALLOW_LIVE_MIGRATION`에도 **같은 Project ID를 정확히** 입력합니다.

   ```dotenv
   FIREBASE_PROJECT_ID=your-actual-project-id
   ALLOW_LIVE_MIGRATION=your-actual-project-id
   ```

2. `backend` 디렉터리에서 Firebase CLI로 규칙·인덱스를 배포합니다. 이 명령은 `.env`를 읽지 않으므로 명령의 Project ID를 실제 대상으로 지정합니다.

   ```powershell
   firebase login
   firebase deploy --only firestore --project your-actual-project-id
   ```

   현재 `firebase.json`은 `firestore.rules`와 `firestore.indexes.json`을 배포 대상으로 지정합니다. 배포는 대상 프로젝트의 기존 규칙·인덱스를 바꿀 수 있으므로 기존 설정과 차이를 확인한 다음 실행하세요. [Firebase CLI 배포 문서](https://firebase.google.com/docs/cli)
3. ADC 로그인과 프로젝트 권한을 확인한 후 같은 디렉터리에서 마이그레이션을 실행합니다.

   ```powershell
   npm run migrate
   ```

마이그레이션은 실행 기록과 `system/schema` 문서를 트랜잭션으로 기록합니다. `applied` 또는 `already applied`가 나오면 연결과 스키마 메타데이터 적용이 확인된 것입니다. 기존 기록과 메타데이터가 맞지 않으면 덮어쓰지 않고 중단합니다. 이 초기 마이그레이션은 실제 사용자 컬렉션을 미리 만들지 않습니다. Firestore 컬렉션은 문서가 처음 저장될 때 나타납니다.

중요: `ALLOW_LIVE_MIGRATION`을 대상 ID와 맞추고 에뮬레이터 변수를 제거한 상태에서 `npm run migrate`를 실행하면 실제 프로젝트에 쓰기 작업이 발생합니다. 대상 Project ID를 확인하고 실행하세요. `.env`는 로컬에만 두고 커밋하지 않습니다.
