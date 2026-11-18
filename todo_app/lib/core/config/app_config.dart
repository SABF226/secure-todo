/// Compile-time configuration.
///
/// Override at launch, for example on a physical phone:
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
abstract final class AppConfig {
  // 10.0.2.2 is how the Android emulator reaches the host machine.
  // On the iOS simulator and on the web use http://localhost:3000/api/v1.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
