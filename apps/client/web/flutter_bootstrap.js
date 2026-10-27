{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString(),
    canvasKitVariant: 'full',
    fontFallbackBaseUrl: new URL('assets/font-fallback/', document.baseURI).toString(),
  },
});
