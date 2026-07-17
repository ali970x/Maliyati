{{flutter_js}}
{{flutter_build_config}}

(async () => {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));
    } catch (_) {
      // A stale service worker should never block the app from opening.
    }
  }

  let buildId = 'latest';
  try {
    const response = await fetch('/.last_build_id', { cache: 'no-store' });
    if (response.ok) {
      buildId = (await response.text()).trim() || buildId;
    }
  } catch (_) {
    // The no-cache response headers still keep the entrypoint fresh.
  }

  const dartBuild = _flutter.buildConfig.builds.find(
    (build) => build.compileTarget === 'dart2js',
  );
  if (dartBuild) {
    dartBuild.mainJsPath = `main.dart.js?v=${encodeURIComponent(buildId)}`;
  }

  await _flutter.loader.load({
    config: {
      canvasKitBaseUrl: '/canvaskit/',
    },
  });
})();
