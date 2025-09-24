class ProxyConfig {
  static const String defaultScriptProxyEndpoint =
      'https://vioo-app.vercel.app/api/generate-script';

  static const String scriptProxyEndpoint = String.fromEnvironment(
    'SCRIPT_PROXY_ENDPOINT',
    defaultValue: defaultScriptProxyEndpoint,
  );
}
