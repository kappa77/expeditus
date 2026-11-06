/// Version injected by the release pipeline with:
///   flutter build windows --release --dart-define=APP_VERSION=1.2.3
///
/// The fallback is the local development version.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.7',
);
