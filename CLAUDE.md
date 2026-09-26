# CLAUDE.md

Claude Code가 이 저장소에서 작업할 때 참고하는 가이드다.

> **이 파일의 유지 규칙** — 매 세션 전량 로드되므로 길수록 준수율이 떨어진다. **200줄 안쪽**을 지킬 것.
> 새로 알게 된 것을 붙이기 전에 갈 곳을 먼저 정한다: 상세 스펙 → `docs/0X-*.md` · 작업 경과 → `docs/10-Change-History.md`.
> 여기 남길 것은 **매 세션 참인 사실**뿐이다: 명령, 컨벤션, 구조, "항상 X 하라".

## Project Overview

**Ttabong(따봉)** — Flutter로 만드는 **데스크톱 플러그인 호스트 앱**. 독립 실행되면서 기능을 플러그인으로 끼워 넣을 수 있다. 데이터·LLM은 직접 다루지 않고 코어의 HTTP API를 호출한다. 상세: `docs/00-Overview.md`.

짝이 되는 저장소: **`lianist/dochi`** (LLM & DB 코어, Next.js + Supabase, 로컬 `~/Projects/dochi`).

## 현재 단계

**2단계 코어 연동 진행 중** (2026-09-24) — 대시보드 웹뷰가 실제 dochi 배포 주소를 가리키고, 캡처 API가 api.md 계약대로 붙었고(엔드포인트·mode·Content-Type·타임존), 앱 로그인(시스템 브라우저 → 딥링크 → 코드 교환, 토큰 자동 갱신)이 실제로 동작한다. Dock 아이콘 대신 메뉴바 트레이 아이콘(`LSUIElement`)으로 상주한다.
남은 것: 로그인 시 자동 실행, 플러그인 호스트(3단계) 등 `tide-kit-v3.0/flutter-porting-guide.md`가 그리는 나머지 화면. 경위는 `docs/10-Change-History.md`.
단계를 건너뛰거나 다음 단계 작업을 미리 하지 않는다. 로드맵 SSOT는 `docs/00-Overview.md`.

## Tech Stack

| 영역 | 기술 |
|---|---|
| App | Flutter **3.47.5** (stable) · Dart 3.13.4 · macOS + Windows 데스크톱 |
| Backend | 없음 — Dochi API만 호출 |

상태 관리·라우팅·HTTP 클라이언트 선택은 스캐폴딩 시점에 정하고 `docs/02-Architecture.md`에 근거와 함께 고정한다.

## Architecture (경계는 `docs/00-Overview.md`가 SSOT)

```
Ttabong (Flutter)
  ├─ 플러그인 호스트 (매니페스트 · 호스트 API 표면)  ← 이 저장소가 정의한다
  └──HTTP──▶ Dochi 코어 ──▶ Supabase · LLM
```

- 🔑 **Supabase를 직접 호출하지 않는다.** Dochi API만 통과시킨다. `supabase_flutter` 같은 의존성을 추가하지 않는다.
- 🔑 **LLM 키를 앱이 들고 있지 않는다.** 데스크톱 바이너리는 뜯어볼 수 있다. 모델 선택·프롬프트 조립은 코어 소관.
- 🔑 **플러그인 규약은 이 저장소 소관이다.** 코어에 플러그인 관련 개념을 밀어 넣지 않는다.

## 명령

```bash
flutter doctor -v
flutter run -d macos     # Windows는 -d windows
flutter analyze
flutter test
```

## 환경

- Flutter SDK는 Homebrew cask로 설치돼 있다 (`/opt/homebrew/share/flutter`, `flutter`·`dart`는 `/opt/homebrew/bin`). `macos-desktop`은 활성화 완료.
- **macOS 빌드에는 Xcode가 필요하다.** CLT만으로는 안 된다. 설치 절차는 `README.md` 참고.
- Xcode가 없어도 `flutter create` · `analyze` · `test`는 동작한다. 빌드가 막혀도 코드 작업은 진행할 수 있다.
- 🔑 **Windows는 개발자 모드가 켜져 있어야 아무것도 안 막힌다.** 플러그인을 심볼릭 링크로 엮기 때문에, 꺼져 있으면 빌드는 물론 `pub get` · `analyze` · `test`까지 `Building with plugins requires symlink support`로 멈춘다(`start ms-settings:developers`). Windows 빌드에는 Visual Studio 2022의 C++ 데스크톱 워크로드 + ATL(`screen_capturer`가 요구)이 필요하다.
- 🔑 **`Runner` 타겟은 실제 Apple Developer 팀(`WB5PG6BWM2`)의 Automatic Signing으로 서명된다** (2026-09-24). 프로젝트 레벨 빌드 설정에 남아 있던 `CODE_SIGN_IDENTITY = "-"`(ad-hoc, Flutter 기본값)가 타겟의 `CODE_SIGN_STYLE = Automatic`을 덮어써서 매번 다른 정체성으로 서명되는 바람에, 빌드할 때마다 macOS가 화면 기록·손쉬운 사용 권한을 다시 물었다. 그 줄을 지워서 고쳤다 — **다시 넣지 않는다.** `codesign -dv <Tide.app>`에서 `TeamIdentifier=WB5PG6BWM2`가 보이면 정상이다(`flags=0x2(adhoc)`가 보이면 회귀).

## 규칙

- 🔴 API 키·비밀을 앱 코드나 에셋에 넣지 않는다.
- 🔑 **Windows 창 설정은 반드시 `windowManager.waitUntilReadyToShow`를 통한다.** `window_manager`가 `ITaskbarList3`를 만드는 곳이 그 네이티브 호출뿐이라, 건너뛰고 `setSkipTaskbar`를 부르면 널 역참조로 프로세스가 즉사한다(`0xC0000005`).
- 🔑 **플랫폼 분기는 조건부 import로 못 한다.** macOS와 Windows 둘 다 `dart:io`라 `dart.library.*`로는 구분이 안 된다 — `Platform.isWindows` 런타임 분기를 쓴다(`DashboardView` 참고).
- 🔑 **Windows 웹뷰는 `webview_win_floating`이다**(`webview_flutter`의 Windows 구현으로 등록되므로 양 플랫폼이 같은 `WebViewController`를 쓴다). **`webview_windows`로 돌아가지 않는다** — 그 텍스처 방식은 Windows 11 + 현행 WebView2에서 빈 흰 화면만 나온다. 대신 Windows에선 웹뷰 위에 Flutter 위젯을 그릴 수 없다(네이티브 자식 창).
- 🔑 **웹뷰 안 내비게이션을 Windows에서 가로막지 않는다.** Google 로그인은 그때그때 다른 호스트를 거쳐서, 호스트 허용 목록은 반드시 로그인을 깨뜨린다. macOS만 off-host를 외부 브라우저로 넘긴다(WKWebView는 Google이 거부한다).
- 🔑 **Windows 캡처는 `screen_capturer.capture()`를 쓰지 않는다.** 그쪽은 캡처 도구가 떴는지를 포그라운드 프로세스 이름으로 1초 뒤부터 판정해서, 사용자가 드래그하기도 전에 빈 클립보드를 읽고 끝난다. `ScreenshotService`가 직접 `ms-screenclip://`을 띄우고 클립보드를 폴링한다.
- 🔑 **앱 신원은 전부 `Tide`다** — 실행 파일 `tide.exe`, Dart 패키지 `tide`, 번들 ID `com.tide.app`, MSIX `Tide.TideDesktop`. 단 **`dochi://` 스킴과 `dochi-six.vercel.app`은 바꾸지 않는다** — 상대 제품(코어)의 계약이고, api.md가 redirect_uri를 "글자까지 정확히" 요구한다.
- 🔑 **WebView2 프로필은 `AppPaths.webViewDataFolder`(LOCALAPPDATA)에 둔다.** 기본값은 실행 파일 *옆*이라 읽기 전용 설치 위치(Program Files·MSIX)에서 쓰기가 실패하고, 증상은 대시보드가 **빈 흰 화면**으로 나온다.
- 🔑 **빌드 폴더에 아무것도 두지 않는다.** 설치 스크립트가 `Release\*`를 통째로 담아서, 거기 떨어진 것은 전부 배포본에 실린다(웹뷰 프로필 한 번, `tide.msix` 한 번 — 둘 다 크기가 두 배로 튀어서 잡았다). **깨끗한 설치 프로그램은 10MB대다.**
- 🔑 **웹뷰에 주입하지 않는다 — 지금은 하나도 없다.** 대시보드는 코어의 웹페이지라 소스를 못 고치지만, 덧칠은 저쪽이 바뀌면 조용히 깨진다(실제로 한 번 깨져 엉뚱한 열을 덮어썼다). 급해 보여도 먼저 **`docs/20-Core-Requests.md`에 적어 넘긴다** — 2026-09-26에 넘긴 넷이 전부 웹으로 갔고 주입 코드는 통째로 지웠다. 레이아웃(CSS)은 아예 손대지 않는다.
- 🔑 **웹뷰는 URL로 페이지를 열지 않는다.** `POST /api/v1/web-session`으로 일회용 로그인 주소를 받아 연다(`WebSessionService`). 경로를 직접 열면 웹 로그인 화면이 한 번 더 뜨고, macOS에서는 그 화면의 Google 로그인이 **끝나지 않는다**. 그 주소는 자격 증명이므로 **로그에 남기지 않는다** — 목적지 경로만 남긴다.
- 🔑 **GUI 빌드에는 콘솔이 없다 — `debugPrint`는 어디에도 남지 않는다.** 실행 중 동작을 남기려면 `AppLog.write`를 쓴다(`%APPDATA%\Tide\Tide\tide.log` — 첫 줄이 실행 중인 버전을 말한다).
- `pubspec.lock`은 앱이지만 현재 gitignore에 있다. 배포를 시작할 때 커밋 대상으로 전환할지 결정한다.
- 커밋 메시지는 한국어, Conventional Commits 접두사(`feat:`, `fix:`, `chore:`, `docs:`).
