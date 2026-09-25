enum AppCaptureMode {
  createTask,
  completeTask,
}

extension AppCaptureModeExtension on AppCaptureMode {
  /// 사용자에게 보이는 이름. 한국어인 이유는 서버가 돌려주는 알림 문구가
  /// 한국어라서다 — 같은 알림 목록에 두 언어가 섞이면 그게 더 이상하다.
  String get displayName {
    switch (this) {
      case AppCaptureMode.createTask:
        return '새 태스크';
      case AppCaptureMode.completeTask:
        return '완료';
    }
  }

  String get description {
    switch (this) {
      case AppCaptureMode.createTask:
        return '새 태스크로 만들 부분을 드래그해 선택하세요';
      case AppCaptureMode.completeTask:
        return '완료 처리할 태스크가 보이는 부분을 드래그해 선택하세요';
    }
  }

  /// The `mode` value the Dochi capture API expects (see `public/api.md`
  /// in the dochi repo — it's `create` | `complete`, not this enum's name).
  String get apiValue {
    switch (this) {
      case AppCaptureMode.createTask:
        return 'create';
      case AppCaptureMode.completeTask:
        return 'complete';
    }
  }
}
