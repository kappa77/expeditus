/// Version injected by the release pipeline with:
///   flutter build windows --release --dart-define=APP_VERSION=2.0.0
///
/// The fallback is the local development version.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '2.3.0',
);
