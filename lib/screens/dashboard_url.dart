import '../services/dochi_config.dart';

/// The dashboard both platform webviews load. Shared so the macOS and
/// Windows implementations can't drift apart.
final Uri dashboardUri = Uri.parse('$dochiBaseUrl/dashboard');
