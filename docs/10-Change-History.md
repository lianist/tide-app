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

## 2026-09-24 — 백그라운드 상주, OS 알림, 웹뷰 Google 로그인

- **대시보드 웹뷰의 Google 로그인이 시스템 브라우저에서 열리게 했다** — Google이 임베디드 웹뷰 안의 로그인 시도를 그대로 막기 때문이다. `dochi-six.vercel.app`을 벗어나는 모든 내비게이션을 `NavigationDelegate`로 가로채 `url_launcher`로 외부 브라우저에 넘긴다(같은 호스트 안 이동은 웹뷰에 그대로 둔다). 단, 그렇게 완료한 로그인 세션 쿠키는 시스템 브라우저 쪽에 남지 웹뷰로 넘어오지 않는다 — 웹뷰 자체는 여전히 로그아웃 상태로 남는 별개 문제이고, 아직 손대지 않았다.
- **창을 닫아도, `⌘Q`로 꺼도 앱이 종료되지 않는다** — 전역 캡처 단축키가 창이 아니라 프로세스에 등록돼 있어서, 종료되면 단축키도 함께 죽는다(사용자 결정, 2026-09-24: 일반적인 Mac 앱 관례와 다르게 `⌘Q`도 의도적으로 종료하지 않는다). `AppDelegate.applicationShouldTerminateAfterLastWindowClosed`가 `false`를 돌려주고 `MainFlutterWindow.isReleasedWhenClosed = false`로 창 객체를 살려 두며, `applicationShouldTerminate`를 오버라이드해 `⌘Q`·Dock의 "Quit"까지 가로채 창만 숨긴다. Dock 아이콘을 다시 누르면 `applicationShouldHandleReopen`이 숨겨 둔 창을 되살린다.
  - 이제 앱을 실제로 끌 방법이 없어지므로, 앱 메뉴에 **"Quit Tide Completely"(⌘⌥Q)**를 코드로 추가했다 — 이것만 진짜 종료로 이어진다. 표준 "Quit Tide"(⌘Q) 항목의 문구는 그대로 두었다(더 이상 실제로 종료하지 않지만, XIB를 손대지 않고는 라벨을 못 바꾼다).
- **캡처 결과를 macOS 알림(Notification Center)으로 띄운다** — 창이 닫혀 있으면 인앱 스낵바는 아무도 못 본다. `flutter_local_notifications`로 교체했고(`NotificationService`), 첫 실행에 알림 권한을 요청한다. 여러 건이 생성되면 그만큼 알림도 여러 개 뜬다(`api.md`의 "건마다 알림" 그대로).

## 2026-09-24 — 재서명할 때마다 권한을 다시 묻는 문제를 해결

`flutter build macos --release`는 ad-hoc 서명이라, 빌드할 때마다 macOS가 다른 앱으로 인식해 화면 기록·손쉬운 사용 권한을 매번 다시 물었다(TCC는 정체성을 코드 서명으로 구분한다). 처음엔 이 머신 로그인 키체인에 자체 서명 인증서("Tide Local Dev")를 만들어 매 빌드 뒤 수동으로 재서명하는 우회로 막았는데, 사용자가 Apple Developer 계정이 있다고 해서 더 나은 방법으로 바꿨다.

**진짜 원인은 따로 있었다.** 프로젝트 레벨 빌드 설정에 `CODE_SIGN_IDENTITY = "-"`(Flutter 기본 템플릿 값)가 박혀 있어서, Xcode에서 팀을 고르고 "Automatically manage signing"을 켜도 타겟의 `CODE_SIGN_STYLE = Automatic`을 이 값이 덮어써 계속 ad-hoc으로 서명됐다. 세 군데(Debug/Release/Profile 프로젝트 설정)에서 그 줄을 지우자 타겟 설정(`DEVELOPMENT_TEAM = WB5PG6BWM2`)이 제대로 먹혀 실제 "Apple Development" 인증서로 서명된다(`codesign -dv`의 `TeamIdentifier=WB5PG6BWM2`로 확인). 자체 서명 인증서는 이제 안 쓴다 — 진짜 팀 서명이 훨씬 안정적이고, 나중에 배포용 노터라이즈도 이 경로로만 가능하다.

## 2026-09-24 — Dock 아이콘 대신 메뉴바 트레이 아이콘

앱이 완전히 종료된 상태에서는 단축키를 쓸 방법이 원천적으로 없다(등록해 둘 프로세스 자체가 없으므로). 대신 로그인 시 자동 실행 얘기가 나왔고, 그러려면 "떠 있는지 한눈에 알 수 있어야 한다"는 요구가 붙어 Dock 아이콘의 대안으로 메뉴바 트레이 아이콘을 만들었다 — `tide-kit-v3.0/flutter-porting-guide.md`가 원래 그리던 방향이기도 하다.

- `Info.plist`에 `LSUIElement = true`를 넣어 Dock 아이콘과 Cmd+Tab 노출을 없앴다(`lsappinfo`의 `type="UIElement"`로 확인).
- `tray_manager`로 메뉴바에 Tide 심볼 템플릿 아이콘(`tide-kit-v3.0/assets/tray/tide-menubar-template@2x.png`에서 복사, `isTemplate: true`라 다크 모드에서 OS가 알아서 흰색으로 바꾼다)을 달았다. 클릭하면 "Show Dashboard"(창을 되살림, `window_manager`)와 "Quit Tide Completely"(진짜 종료) 두 항목이 뜬다.
- Dock 아이콘이 없어지면서 기존의 "Dock 아이콘 클릭 → 창 복귀" 경로(`applicationShouldHandleReopen`)가 사실상 쓸모없어졌다 — 트레이의 "Show Dashboard"가 그 자리를 대신한다. 코드는 남겨 뒀다(해가 없고, Spotlight로 재활성화하는 드문 경우엔 여전히 도움이 될 수 있다).
- "Quit Tide Completely"는 여전히 네이티브(`AppDelegate.quitCompletely()`)에 있다 — Dart 쪽 트레이 메뉴 클릭은 새 메서드 채널(`com.dochi.tide/app`)로 그걸 부르기만 한다. 두 실행 경로(앱 메뉴의 ⌘⌥Q, 트레이 메뉴 클릭)가 같은 종료 로직을 공유한다.
- `tray_manager`·`window_manager`는 0.7.x/0.6.x대에 새 C++ 코어(`nativeapi`)로 다시 쓰여지는 중이라 API가 크게 바뀌었다 — 검증된 구식 API(`trayManager` 싱글턴, `TrayListener`)가 남아 있는 마지막 버전(`0.5.3`/`0.5.2`)에 고정했다. 나중에 올릴 때는 마이그레이션 가이드를 먼저 읽는다.
