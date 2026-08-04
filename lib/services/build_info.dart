abstract final class BuildInfo {
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );
  static const String commitSha = String.fromEnvironment(
    'BUILD_SHA',
    defaultValue: 'local',
  );
  static const String buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'unknown',
  );

  static String get label => '$version · $commitSha · $buildTime';
}
