# Ttabong (따봉)

**Dochi 코어 위에서 동작하는 Flutter 데스크톱 플러그인 호스트 앱.**

독립 실행되는 데스크톱 앱이면서, 기능을 플러그인으로 끼워 넣을 수 있는 호스트다.
데이터와 LLM은 직접 다루지 않고 코어 저장소 [Dochi](https://github.com/lianist/dochi)의 HTTP API를 호출한다.

```
Ttabong (Flutter · macOS 우선)
  ├─ 플러그인 호스트 (매니페스트 · 호스트 API 표면)
  └──HTTP──▶ Dochi 코어 ──▶ Supabase · LLM
```

## Tech Stack

| 영역 | 기술 |
|---|---|
| App | Flutter (Dart) · macOS 데스크톱 우선 |
| Backend | 없음 — Dochi API만 호출 |

## 현재 상태

**뼈대 단계.** 저장소와 문서만 있고 Flutter 프로젝트는 아직 생성 전이다.
다음 단계는 `flutter create . --platforms=macos` 부터.

## 개발 환경

Flutter SDK는 Homebrew로 설치한다.

```bash
brew install --cask flutter
flutter config --enable-macos-desktop
flutter doctor -v
```

### macOS 빌드에는 Xcode가 필요하다

Command Line Tools만으로는 macOS 앱을 빌드할 수 없다. **App Store에서 Xcode를 설치한 뒤** 아래를 실행한다:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

Xcode 없이도 `flutter create`와 Dart 분석·테스트는 동작하므로, 코드 작업 자체는 먼저 시작할 수 있다.

### Windows 빌드에는 Visual Studio와 개발자 모드가 필요하다

**Visual Studio 2022**의 "C++를 사용한 데스크톱 개발" 워크로드를 설치한다(Build Tools만으로도 된다). `screen_capturer`가 **ATL**을 요구하므로 같이 체크한다.

그리고 **개발자 모드를 켜야 한다** — 켜지 않으면 `flutter pub get`부터 `Building with plugins requires symlink support`로 멈춘다(플러그인을 심볼릭 링크로 엮기 때문이고, Windows는 심볼릭 링크 생성에 관리자 권한을 요구한다). `analyze`와 `test`도 같이 막히므로 코드 작업 전에 먼저 켜 둔다.

```powershell
start ms-settings:developers   # "개발자 모드" 켜기
```

대시보드 웹뷰는 **Edge WebView2 런타임**을 쓴다. Windows 11에는 기본 탑재돼 있어 보통 따로 설치할 필요가 없다.

```powershell
flutter build windows --release
# build\windows\x64\runner\Release\ttabong.exe
```

산출물은 단일 실행 파일이 아니다 — `Release` 폴더 통째로 배포해야 한다(`flutter_windows.dll`·플러그인 DLL·`data\` 포함).
