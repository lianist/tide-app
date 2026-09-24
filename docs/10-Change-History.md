# 10 — Change History

작업 경과를 시간순으로 짧게 남긴다. 상세 스펙은 `docs/0X-*.md`에 둔다.

## 2026-09-22 — 앱 단순화: 로그인 → 웹뷰 + 단축키 2개

1단계 스캐폴딩(3-모드 캡처, 로컬 Gallery, 단축키 커스터마이징 Settings)을 `개발 가이드라인.md`(Dochi 제품 스펙)에 맞춰 대폭 걷어냈다.

- 전역 단축키를 `⇧⌘1`(생성) / `⇧⌘2`(완료) 두 개로 축소 (`CAP-2`). 항상 영역 드래그 캡처만 사용.
- 로그인 후 메인 화면을 전체화면 웹뷰(`https://www.google.com` 플레이스홀더)로 교체. 실제 대시보드 URL은 추후 연결.
- 캡처는 로컬에 남기지 않고 임시 파일로만 존재, `CaptureApiService`를 통해 서버로 업로드 시도 후 즉시 삭제. Dochi 캡처 엔드포인트가 아직 없어 `baseUrl`은 비워두고 스텁 상태로 둠 (`API-3`).
- Gallery, Settings(단축키 에디터 포함) 화면 전체 삭제 — 단축키 변경 기능은 Non-goal.
- 로그인은 실제 인증 없는 플레이스홀더(버튼 하나로 통과). 세션 상태만 로컬에 영속화.

로드맵상 이 작업이 **2단계 — 코어 연동**의 시작점이다. 남은 일: 실제 로그인(딥링크 인증, `AUTH-3`), Dochi 캡처 API 연동, 트레이 상주 UI.

## 2026-09-24 — 코어 연동: 실제 로그인·캡처 API·대시보드 URL

- 대시보드 웹뷰가 플레이스홀더(`google.com`) 대신 실제 배포 주소(`https://dochi-six.vercel.app/dashboard`)를 가리킨다.
- `CaptureApiService`가 api.md 계약대로 붙었다: `baseUrl`을 실제 값으로 채우고, 엔드포인트를 `/api/v1/captures`로 고치고, `mode`를 `create`/`complete` 문자열로 바꾸고, 이미지 파트에 `Content-Type: image/png`를 붙였다(넷 다 없으면 서버가 400을 낸다).
- **실제 로그인(`AUTH-3`)을 구현했다** — `AuthService`가 시스템 브라우저를 열어 `/auth/app/start`로 보내고, `dochi://auth/callback` 딥링크(`app_links`, `macos/Runner/Info.plist`에 스킴 등록)로 code를 받아 `/auth/app/token`과 교환하고, 세션을 macOS Keychain(`flutter_secure_storage`)에 둔다. 만료·401 시 한 번 갱신을 시도하고 실패하면 로그인 화면으로 되돌아간다. 플레이스홀더였던 `StorageService.loadIsLoggedIn`/`saveIsLoggedIn`은 삭제했다.
- 캡처 응답의 `outcome`/`created`/`completed`/`failure`를 실제로 파싱한다 — 전에는 `2xx`면 무조건 "성공"으로 봐서 "생성할 태스크가 없어요" 같은 정상적인 `failed` outcome도 성공으로 잘못 알렸다. `failure.code`는 절대 분기하지 않고 `message`를 그대로 띄운다(api.md §변경 규칙 — 새 코드가 예고 없이 늘 수 있다).
- 타임존 버그를 고쳤다 — `DateTime.now().timeZoneName`(`"KST"`)을 그대로 보내서 서버가 매번 `400 VALIDATION_FAILED`를 냈다. `/etc/localtime` 심볼릭 링크에서 IANA 이름(`Asia/Seoul`)을 읽도록 바꿨다(`StorageService.localIanaTimeZone`).
- 로그인 화면을 Tide 디자인 시스템에 맞춰 다시 그렸다 — Mist 배경, 그림자 없는 흰 카드, 인디고 버튼, 실제 워드마크 SVG(`tide-kit-v3.0/assets/brand/`에서 복사). 커스텀 폰트(Pretendard·Wanted Sans)는 `tide-kit-v3.0/flutter/`가 이 체크아웃에 없어 아직 시스템 폰트로 대체돼 있다.
- 대시보드 화면의 (dev용) 로그아웃 버튼을 없앴다. 지금은 웹뷰 안 dochi 자체 로그아웃(웹 세션만 지운다)이 유일한 경로다 — 앱 자체 세션까지 지우는 로그아웃이 필요해지면 별도로 만들어야 한다.
