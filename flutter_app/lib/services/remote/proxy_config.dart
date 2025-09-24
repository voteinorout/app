class ProxyConfig {
  static const String defaultScriptProxyEndpoint =
      'https://app-git-vercel-lisa-mollicas-projects-f40db721.vercel.app/api/generate-script';

  static const String scriptProxyEndpoint = String.fromEnvironment(
    'SCRIPT_PROXY_ENDPOINT',
    defaultValue: defaultScriptProxyEndpoint,
  );
}
