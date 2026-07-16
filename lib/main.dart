import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

import 'config/app_config.dart';
import 'controllers/dashboard_controller.dart';
import 'l10n/app_strings.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/spending_alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transactions_screen.dart';
import 'widgets/finance_formatters.dart';
import 'widgets/responsive_layout.dart';
import 'services/firebase_bootstrap.dart';
import 'services/smart_clipboard_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeIfConfigured();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FinanceTrackerApp());
}

class FinanceTrackerApp extends StatefulWidget {
  const FinanceTrackerApp({super.key});

  @override
  State<FinanceTrackerApp> createState() => _FinanceTrackerAppState();
}

class _FinanceTrackerAppState extends State<FinanceTrackerApp> {
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: _controller.themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: !_controller.isInitialized
            ? const _SessionLoadingScreen()
            : _controller.isSignedIn
            ? FinanceHome(controller: _controller)
            : LoginScreen(controller: _controller),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kIsWeb ? const Color(0xFF2563EB) : const Color(0xFF0F766E),
      brightness: brightness,
    );
    final surface = isDark ? const Color(0xFF171C20) : Colors.white;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFF0E1215),
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0E1215)
          : kIsWeb
          ? const Color(0xFFF6F8FC)
          : const Color(0xFFF5F7FA),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF111619) : Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(systemOverlayStyle: overlayStyle),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/branding/maliyati_app_icon.png',
                  width: 74,
                  height: 74,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int _smartInputRequest = 0;
  String? _smartInputScript;
  bool _smartInputAutoRun = false;
  final _smartClipboard = SmartClipboardService.instance;
  StreamSubscription<SharedMedia>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _smartClipboard.initialize(onOpenSmartInput: _openSmartInput);
    _initializeShareHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSubscription?.cancel();
    _smartClipboard.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _smartClipboard.updateLifecycle(state);
  }

  void _openSmartInput(String script, {bool autoRun = true}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 2;
      _smartInputScript = script;
      _smartInputAutoRun = autoRun;
      _smartInputRequest += 1;
    });
  }

  Future<void> _initializeShareHandler() async {
    final handler = ShareHandler.instance;
    _shareSubscription = handler.sharedMediaStream.listen(_handleSharedMedia);
    final initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      _handleSharedMedia(initialMedia);
    }
  }

  void _handleSharedMedia(SharedMedia media) {
    final text = media.content?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    _openSmartInput(text, autoRun: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final screens = [
          DashboardScreen(controller: controller),
          TransactionsScreen(controller: controller),
          AddTransactionScreen(
            key: ValueKey('smart-input-$_smartInputRequest'),
            controller: controller,
            initialScript: _smartInputScript,
            autoRunInitialScript: _smartInputAutoRun,
          ),
          AnalyticsScreen(controller: controller),
          SpendingAlertsScreen(controller: controller),
        ];
        final strings = controller.strings;
        FinanceFormatters.localeCode = controller.language.code;
        final indexedScreens = IndexedStack(
          index: _selectedIndex,
          children: screens,
        );
        final navigationBar = NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: strings.dashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: strings.transactions,
            ),
            NavigationDestination(
              icon: const _AddNavIcon(selected: false),
              selectedIcon: const _AddNavIcon(selected: true),
              label: 'Add',
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded),
              label: strings.analytics,
            ),
            const NavigationDestination(
              icon: Icon(Icons.notifications_active_outlined),
              selectedIcon: Icon(Icons.notifications_active_rounded),
              label: 'Alerts',
            ),
          ],
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: const Color(0xFF0E1215),
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Directionality(
            textDirection: controller.language == AppLanguage.arabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              key: _scaffoldKey,
              drawerEdgeDragWidth: 28,
              drawerScrimColor: Colors.black.withValues(alpha: 0.42),
              drawer: SettingsDrawer(controller: controller),
              body: SafeArea(
                child: Column(
                  children: [
                    _GlobalTopBar(
                      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AppResponsive.contentMaxWidth(context),
                          ),
                          child: indexedScreens,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: AppResponsive.isWeb
                  ? null
                  : Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: AppResponsive.contentMaxWidth(context),
                        ),
                        child: navigationBar,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalTopBar extends StatelessWidget {
  const _GlobalTopBar({
    required this.onOpenMenu,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final VoidCallback onOpenMenu;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: theme.colorScheme.surface,
        child: Container(
          height: AppResponsive.isWideWeb(context) ? 68 : 58,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppResponsive.contentMaxWidth(context),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Open settings',
                    child: IconButton(
                      onPressed: onOpenMenu,
                      icon: const Icon(Icons.menu_rounded, size: 30),
                      splashRadius: 24,
                    ),
                  ),
                  const SizedBox(width: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/branding/maliyati_app_icon.png',
                      width: 29,
                      height: 29,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    AppConfig.appName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  if (AppResponsive.isWideWeb(context)) ...[
                    const SizedBox(width: 28),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _WebNavItem(
                              index: 0,
                              selectedIndex: selectedIndex,
                              icon: Icons.dashboard_outlined,
                              selectedIcon: Icons.dashboard_rounded,
                              label: 'Dashboard',
                              onSelected: onDestinationSelected,
                            ),
                            _WebNavItem(
                              index: 1,
                              selectedIndex: selectedIndex,
                              icon: Icons.receipt_long_outlined,
                              selectedIcon: Icons.receipt_long_rounded,
                              label: 'Transactions',
                              onSelected: onDestinationSelected,
                            ),
                            _WebNavItem(
                              index: 2,
                              selectedIndex: selectedIndex,
                              icon: Icons.add_circle_outline_rounded,
                              selectedIcon: Icons.add_circle_rounded,
                              label: 'Add',
                              onSelected: onDestinationSelected,
                            ),
                            _WebNavItem(
                              index: 3,
                              selectedIndex: selectedIndex,
                              icon: Icons.insights_outlined,
                              selectedIcon: Icons.insights_rounded,
                              label: 'Analytics',
                              onSelected: onDestinationSelected,
                            ),
                            _WebNavItem(
                              index: 4,
                              selectedIndex: selectedIndex,
                              icon: Icons.notifications_active_outlined,
                              selectedIcon: Icons.notifications_active_rounded,
                              label: 'Alerts',
                              onSelected: onDestinationSelected,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebNavItem extends StatelessWidget {
  const _WebNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onSelected,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelected(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNavIcon extends StatelessWidget {
  const _AddNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: selected ? 40 : 34,
      height: selected ? 40 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.add_rounded,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
