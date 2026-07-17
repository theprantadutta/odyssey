import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// The running build's version and build number, e.g. "2.2.1 (15)".
///
/// Read from the bundle rather than written down. A hardcoded constant had the app
/// telling users it was 1.0.0 while it shipped 2.2.0: nothing made it follow
/// pubspec, so it silently rotted across fourteen releases.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
