import 'main.dart' as app;
import 'services/firebase_web_plugin_registrar_web.dart';

Future<void> main() {
  return app.startFinanceTrackerApp(
    registerPlatformPlugins: registerFirebaseWebPlugins,
  );
}
