# Backend

Node.js/TypeScript, Express와 Firebase Admin SDK를 사용하는 API 서버입니다. 홈·걸음 동기화 및 요약·반려동물 조회와 기본 돌봄 API가 구현되어 있습니다.

Firestore 데이터베이스 설정, `.env` 구성, 로컬 에뮬레이터 및 실제 프로젝트 마이그레이션 절차는 [Firestore 설정 안내](../docs/firestore-setup.md)를 참고하세요. Firebase Admin SDK는 Application Default Credentials를 사용합니다. `.env`에는 프로젝트 ID와 환경 설정만 두고 서비스 계정 키 JSON은 넣지 마세요.
