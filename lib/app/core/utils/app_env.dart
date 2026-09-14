/// Ambiente injetado em build-time via --dart-define=APP_ENV=...
/// Valores possíveis: 'dev' | 'prod'
const String kAppEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
bool get kIsDev => kAppEnv != 'prod';

/// Hash curto do commit Git (7 chars) — muda a cada push no Vercel.
/// Localmente fica 'local'.
const String kBuildHash =
    String.fromEnvironment('BUILD_HASH', defaultValue: 'local');

/// Versão do aplicativo
const String kAppVersion = '1.0.0+1';
