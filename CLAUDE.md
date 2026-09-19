# CLAUDE.md

Claude Code가 이 저장소에서 작업할 때 참고하는 가이드다.

> **이 파일의 유지 규칙** — 매 세션 전량 로드되므로 길수록 준수율이 떨어진다. **200줄 안쪽**을 지킬 것.
> 새로 알게 된 것을 붙이기 전에 갈 곳을 먼저 정한다: 상세 스펙 → `docs/0X-*.md` · 작업 경과 → `docs/10-Change-History.md`.
> 여기 남길 것은 **매 세션 참인 사실**뿐이다: 명령, 컨벤션, 구조, "항상 X 하라".

## Project Overview

**Ttabong(따봉)** — Flutter로 만드는 **데스크톱 플러그인 호스트 앱**. 독립 실행되면서 기능을 플러그인으로 끼워 넣을 수 있다. 데이터·LLM은 직접 다루지 않고 코어의 HTTP API를 호출한다. 상세: `docs/00-Overview.md`.

짝이 되는 저장소: **`lianist/dochi`** (LLM & DB 코어, Next.js + Supabase, 로컬 `~/Projects/dochi`).

## 현재 단계

**0단계 뼈대 완료** (2026-09-19) — 저장소와 경계 문서만 있고 **Flutter 프로젝트는 아직 생성 전이다**.
다음은 **1단계 앱 스캐폴딩**: `flutter create . --platforms=macos` → 첫 창 띄우기.
단계를 건너뛰거나 다음 단계 작업을 미리 하지 않는다. 로드맵 SSOT는 `docs/00-Overview.md`.

## Tech Stack

| 영역 | 기술 |
|---|---|
| App | Flutter (Dart) · macOS 데스크톱 우선 |
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
flutter run -d macos
flutter analyze
flutter test
```

## 환경

- Flutter SDK는 Homebrew cask로 설치한다 (`brew install --cask flutter`).
- **macOS 빌드에는 Xcode가 필요하다.** CLT만으로는 안 된다. 설치 절차는 `README.md` 참고.
- Xcode가 없어도 `flutter create` · `analyze` · `test`는 동작한다. 빌드가 막혀도 코드 작업은 진행할 수 있다.

## 규칙

- 🔴 API 키·비밀을 앱 코드나 에셋에 넣지 않는다.
- `pubspec.lock`은 앱이지만 현재 gitignore에 있다. 배포를 시작할 때 커밋 대상으로 전환할지 결정한다.
- 커밋 메시지는 한국어, Conventional Commits 접두사(`feat:`, `fix:`, `chore:`, `docs:`).
