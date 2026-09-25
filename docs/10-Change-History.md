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

## 2026-09-25 — Windows 지원: 두 번째 데스크톱 타깃

macOS 전용이던 앱에 Windows 빌드를 붙였다. `flutter create --platforms=windows .`로 러너를 만들고, macOS 전용으로 짜여 있던 부분을 플랫폼별로 갈랐다. **macOS 동작은 건드리지 않는 것을 제약으로 두었다** — 기존 코드는 그대로 두고 Windows 분기를 더하는 방향으로만 작업했다.

- **대시보드 웹뷰를 플랫폼별로 나눴다.** `webview_flutter`에는 Windows 구현이 아예 없다(Android/iOS/macOS만). `webview_windows`(Edge WebView2)를 더하고 `DashboardScreen`이 런타임에 둘 중 하나를 고른다. 조건부 import(`dart.library.*`)로는 못 가른다 — macOS와 Windows 둘 다 `dart:io`라 구분이 안 되기 때문이다. 그래서 `Platform.isWindows` 분기로 갔고, 두 구현이 양쪽 플랫폼에서 다 컴파일된다(`webview_windows`의 Dart 코드는 순수 Flutter 의존뿐이라 macOS에서도 빌드는 된다).
  - ⚠️ **off-host 내비게이션 처리 방식이 다르다.** macOS는 `NavigationDelegate`로 이동을 *막고* 외부 브라우저로 넘기지만, WebView2에는 "이동할까요?" 훅이 없다. Windows 쪽은 `url` 스트림으로 *이미 시작된* 이동을 감지해 `stop()` 후 되돌리므로, 외부 URL이 잠깐 비칠 수 있다. 기능은 같고 체감이 다르다.
- **전역 단축키를 `Ctrl+Shift+1/2`로 바꿨다(Windows 한정).** `HotKeyModifier.meta`는 Windows에서 Windows 키인데, `Win+Shift+숫자`는 셸이 "작업 표시줄 N번째 앱 새 인스턴스"로 이미 쓰고 있다. macOS는 `⇧⌘1/2` 그대로다. 배지 표기도 갈랐다 — `⌘`/`⇧` 글리프는 Mac 관례라 Windows에선 `Ctrl`/`Shift` 글자로 쓴다.
- **딥링크(`dochi://auth/callback`)를 런타임 레지스트리 등록으로 옮겼다.** macOS는 `Info.plist`의 `CFBundleURLTypes`로 정적 선언하면 끝이지만, Windows엔 그런 매니페스트가 없고 실행 파일의 절대 경로를 적어야 해서 설치 후에야 알 수 있다. `UrlSchemeService`가 매 실행마다 `HKCU/Software/Classes/dochi`에 다시 쓴다(HKCU라 권한 상승 불필요, 실행 파일을 옮겨도 따라간다).
  - 단일 인스턴스 처리가 같이 필요했다 — 링크를 누르면 exe가 새로 뜨는데, 로그인 플로가 기다리는 스트림과 전역 단축키는 *기존* 프로세스에 있다. `main.cpp` 맨 앞에서 `SendAppLinkToInstance()`를 불러 이미 뜬 인스턴스로 URL을 넘기고 새 프로세스는 바로 끝낸다.
- **트레이 아이콘은 Windows 전용 `.ico`를 쓴다.** macOS의 `tide-menubar-template.png`는 OS가 알아서 반전시키는 템플릿 이미지라, 그런 반전이 없는 Windows에선 검은 얼룩으로만 보인다. 클릭 관례도 갈랐다(Windows는 좌클릭=열기 / 우클릭=메뉴, macOS는 양쪽 다 메뉴). "Quit Tide Completely"도 macOS는 `AppDelegate`로 넘기지만 Windows엔 그게 없어 `windowManager.destroy()`를 쓴다.
- **타임존은 `flutter_timezone`으로 가져온다(Windows 한정).** Windows는 자체 zone id(`Korea Standard Time`)를 쓰는데 캡처 API는 IANA 이름을 요구한다. CLDR 매핑 표를 들고 있기는 아까워서 플러그인에 맡겼다. macOS의 `/etc/localtime` 경로는 그대로 뒀다 — 이미 돌아가는 걸 바꿀 이유가 없다.
- **Windows에선 클립보드 복사를 하지 않는다.** `screen_capturer`가 Windows에서 `ms-screenclip://`(캡처 도구)로 캡처하는데, 그 결과를 *클립보드를 통해* 돌려받는 구조다(클립보드를 비우고 → 스니핑을 기다렸다가 → 클립보드를 PNG로 저장). 즉 캡처가 끝난 시점에 이미 클립보드에 들어 있다. 굳이 다시 복사하면 중복인 데다, `powershell`은 콘솔 바이너리라 캡처할 때마다 검은 창이 깜빡인다.
- **앱 아이콘을 만들었다.** 트레이용 `.ico`는 32px까지뿐이라 작업 표시줄/탐색기에서 뭉개진다. `tide-tray-windows.svg`를 헤드리스 Edge로 16~256px 8종으로 굽고 ICO로 묶어 `windows/runner/resources/app_icon.ico`를 갈아 끼웠다(Flutter 기본 로고 대체).

### 함정 두 가지

- 🔑 **`window_manager`의 `setSkipTaskbar`를 `waitUntilReadyToShow` 없이 부르면 프로세스가 죽는다** (`0xC0000005`). 그 플러그인이 `ITaskbarList3`를 만드는 곳이 **오직** 네이티브 `WaitUntilReadyToShow()`뿐이라, 건너뛰면 널 포인터를 역참조한다. 우아하게 실패하지 않고 그냥 크래시하므로, Windows 창 설정은 전부 `waitUntilReadyToShow`를 통해야 한다. 실제로 첫 빌드가 이걸로 즉사했다.
- 🔑 **Windows 빌드에는 개발자 모드가 켜져 있어야 한다.** Flutter가 플러그인을 심볼릭 링크로 엮는데 Windows는 심볼릭 링크 생성에 권한이 필요하다. 꺼져 있으면 `flutter build`뿐 아니라 `pub get`·`analyze`·`test`까지 전부 `Building with plugins requires symlink support`로 멈춘다. 설치 요건은 `README.md`에 적어 뒀다.

검증한 것: `flutter analyze` 무결, 테스트 5개 통과(단축키 테스트는 플랫폼별로 기대값을 갈랐다), 릴리스 빌드 성공, exe 기동 후 상주 확인, `dochi://` 레지스트리 등록과 단일 인스턴스 전달 동작 확인(링크를 열어도 새 프로세스가 생기지 않음), 창 제목·앱 아이콘·로그인 화면 렌더 확인.
**아직 사람 눈으로 확인하지 않은 것**: 트레이 아이콘의 실제 모양과 메뉴, 작업 표시줄에서 숨겨졌는지, 전역 단축키로 캡처→업로드가 실제로 도는지, 로그인 왕복 전체. Windows 머신에서 한 번 직접 돌려봐야 한다.

## 2026-09-25 — Windows에서 안 되던 네 가지: 빈 대시보드·캡처·비밀번호 보기·Google 로그인

Windows에서 쓰다 보니 드러난 문제들을 한 번에 잡았다. 넷 다 실제로 앱을 띄우고 화면을 찍어 확인했다.

- 🔴 **대시보드가 늘 흰 화면이었다.** `webview_windows`는 WebView2를 Flutter 텍스처에 그려 넣는 방식인데, Windows 11 + 요즘 WebView2 런타임 조합에서 그 텍스처가 갱신되지 않는다 — 페이지는 멀쩡히 살아 있어서(`executeScript`로 `location.href`·DOM 크기를 찍어 확인했다) 로그만 보면 정상으로 보이는데, 창에는 순백(`255,255,255`)만 나왔다. 페이지 배경을 빨강으로 바꿔도 화면이 그대로인 걸로 텍스처가 죽었다고 확정했다.
  - **`webview_win_floating`으로 갈아탔다.** 텍스처가 아니라 진짜 WebView2 창을 Flutter 창 위에 얹는 방식이라 렌더링 경로 자체가 없다. 게다가 이 패키지는 `webview_flutter`의 *Windows 구현*으로 등록되므로(`implements: webview_flutter`), macOS(WKWebView)와 Windows가 같은 `WebViewController` API를 쓴다 — `dashboard_view_macos.dart`와 `dashboard_view_windows.dart`를 지우고 `dashboard_view.dart` 하나로 합쳤다.
  - ⚠️ 대가: Windows에선 **웹뷰 위에 Flutter 위젯을 그릴 수 없다**(네이티브 자식 창이므로). 권한 배너 같은 건 Windows에선 가려진다고 보면 된다.
- 🔴 **캡처가 서버까지 가지 않았다.** `screen_capturer`는 `ms-screenclip://`로 캡처 도구를 띄운 뒤 **1초 있다가** 포그라운드 창이 `SnippingTool.exe`인지 보고 "아직 캡처 중"을 판정한다. 캡처 도구가 처음 뜰 때는 1초를 넘기는 일이 흔해서, 사용자가 드래그를 시작하기도 전에 "끝났다"고 보고 빈 클립보드를 읽고 실패로 끝났다 — 캡처 도구의 알림만 뜨고 Tide는 아무 말이 없던 게 이 때문이다.
  - `ScreenshotService`가 직접 오버레이를 띄우고 **클립보드를 폴링한다**(먼저 비우므로 그 뒤에 나타나는 이미지는 이번 캡처가 맞다, 최대 90초). 프로세스 이름 대신 결과물을 기다리니 경합이 없다.
  - `capturedAt`이 오프셋 없는 ISO 문자열(`2026-09-25T18:00:00.000`)로 나가고 있었다 — api.md는 오프셋이 붙은 값을 요구한다. UTC(`Z`)로 보낸다.
  - 캡처가 성공하면 대시보드 웹뷰를 다시 읽는다(`DashboardRefresh`). 전에는 서버에 태스크가 생겨도 창에 떠 있는 목록은 캡처 전 그대로였다.
- **비밀번호 보기 버튼이 안 먹었다.** dochi 로그인 폼에는 보기 버튼이 없다 — 사용자가 누르던 건 Edge가 비밀번호 칸에 그려 주는 기본 버튼(`::-ms-reveal`)인데, WebView2에선 그려지기만 하고 동작하지 않는다(브라우저 셸 UI라 임베디드 컨트롤이 연결하지 않는다). 그 버튼을 숨기고 동작하는 "보기/숨기기" 토글을 dochi 호스트 페이지에만 주입한다. 입력 요소를 **옮기지 않고** 형제로 덧붙인다 — React가 추적 중인 노드를 재부모화하면 예외가 나면서 페이지가 통째로 비어 버린다.
- 🔴 **웹뷰 안 Google 로그인이 중간에 시스템 브라우저로 튕겼다.** Windows 쪽은 허용 호스트 목록(`dochi` / `accounts.google.com` / `*.supabase.co`)을 벗어나는 이동을 잡아 외부 브라우저로 넘기고 있었는데, Google 로그인은 그날그날 다른 호스트(기기 확인·동의 화면·캡차)를 거친다. 목록에 없는 첫 호스트에서 플로가 뜯겨 나가고, 쿠키도 OAuth 상태도 없는 브라우저는 그대로 멈춘다 — "verify it's you 뜨고 앱 창이 떴는데 더 안 나간다"가 이것이다.
  - **Windows에선 내비게이션을 가로채지 않는다.** WebView2는 Edge이고 Edge로 보이므로 Google이 막지 않는다(실제로 앱 창 안에서 Google 로그인 화면까지 확인했다). 밖에서 로그인해 봐야 쿠키가 브라우저에 남아 웹뷰는 계속 로그아웃 상태인, 원래 목적과 정반대인 결과만 나온다.
  - macOS는 규칙을 그대로 둔다 — WKWebView는 Google이 임베디드 웹뷰로 알아보고 아예 거부한다.
- **Windows 단축키 배지를 `Ctrl ⇧ 1`로 바꿨다.** `Shift`를 글자로 쓰면 배지가 세 칸짜리 단어 줄이 된다. `⇧`는 Windows 자신도 쓰는 기호라 Mac 관례인 `⌘`/`⌥`/`⌃`와는 사정이 다르다.
- **진단 로그(`AppLog`)를 더했다.** `%APPDATA%\com.example\ttabong\tide.log`에 실행·캡처·업로드·웹뷰 이동이 한 줄씩 쌓인다. GUI 빌드는 콘솔이 없어서 `debugPrint`가 어디에도 남지 않는다 — 브라우저나 사람 손이 있어야 재현되는 두 플로(로그인·캡처)를 이것 없이 디버깅할 방법이 없었다. 기존 `AuthService`의 `auth.log`도 여기로 합쳤다.
