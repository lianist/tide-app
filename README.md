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
