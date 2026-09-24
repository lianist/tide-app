enum AppCaptureMode {
  createTask,
  completeTask,
}

extension AppCaptureModeExtension on AppCaptureMode {
  String get displayName {
    switch (this) {
      case AppCaptureMode.createTask:
        return 'New Task';
      case AppCaptureMode.completeTask:
        return 'Complete';
    }
  }

  String get description {
    switch (this) {
      case AppCaptureMode.createTask:
        return 'Drag to select what should become a new task';
      case AppCaptureMode.completeTask:
        return 'Drag to select what marks a task as done';
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
