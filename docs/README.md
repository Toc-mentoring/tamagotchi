# 포켓산책 설계 문서

이 문서는 `img`의 화면 8장과 프로젝트 [README](../README.md)를 바탕으로 작성한 **구현 전 설계안**이다. 디자인 원본의 숨겨진 화면이나 실제 API·DB·앱 코드는 확인되지 않았다. 이미지 속 숫자와 이름은 화면 예시이며 확정된 운영 정책이 아니다.

## 문서 안내

1. [기능 명세](requirements.md): 화면·도메인별 작업과 의존 관계
2. [API 명세](api-spec.md): 인증, 요청·응답, 오류, 상태 변경 규칙
3. [ERD와 데이터 모델](erd.md): 엔터티 관계, Firestore 저장 경로와 무결성
4. [시스템 아키텍처](architecture.md): 앱·서버·Firebase·헬스 데이터 연동
5. [기획 결정 사항](open-decisions.md): 결정이 필요한 값, 임시 제안, 영향 범위
6. [Firestore 설정](firestore-setup.md): 데이터 모델, 마이그레이션과 실행 방법
7. [4주 개발 일정](development-schedule.md): MVP 범위, 주차별 작업과 완료 기준

## 설계의 기준과 가정

| 구분 | 내용 |
| --- | --- |
| 확인된 자료 | 8개 화면, Android·iOS용 Flutter 앱과 Firebase 사용 계획 |
| 문서의 기술 제안 | Firebase Authentication, Cloud Firestore, Cloud Functions, Firebase Cloud Messaging을 사용한 구조. 구체적인 Firebase 제품과 서버 구성은 최종 확정 전이다. |
| 게임 규칙 | API와 데이터 구조를 설명하기 위한 임시 정책이다. [기획 결정 사항](open-decisions.md)의 숫자·정책은 승인 전 확정값이 아니다. |
| 사용자 식별 | Firebase Authentication의 `uid`를 사용한다. 로그인 방식과 게스트 계정 지원은 미결정이다. |
| 서버 권한 | 앱은 ID 토큰을 사용해 업무 API를 호출하고, 서버가 게임 상태를 쓰는 구조를 제안한다. |

용어: **반려동물**은 알부터 어른까지 하나의 개체이고, **종**은 도감에 등록되는 캐릭터 종류다. **포인트**는 걷기로 얻는 게임 재화이며, **아이템**은 구매·선물·돌봄에 사용하는 물건이다.
