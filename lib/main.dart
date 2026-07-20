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
import 'screens/admin_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/spending_alerts_screen.dart';
import 'screens/wish_receipt_review_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/transactions_screen.dart';
import 'widgets/finance_formatters.dart';
import 'widgets/responsive_layout.dart';
import 'services/firebase_bootstrap.dart';
import 'services/app_lock_service.dart';
import 'services/smart_clipboard_service.dart';
import 'widgets/app_menu_drawer.dart';

Future<void> main() => startFinanceTrackerApp();

Future<void> startFinanceTrackerApp({
  void Function()? registerPlatformPlugins,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerPlatformPlugins?.call();
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
        themeMode: ThemeMode.light,
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
      seedColor: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B259E),
      brightness: brightness,
    );
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFF101010),
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
          ? const Color(0xFF101010)
          : const Color(0xFFF6F8FC),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1E1E) : surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: .32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE1DFE7),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF484848)
                : const Color(0xFF8AA7BE).withValues(alpha: .30),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF6B259E),
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
        indicatorColor: isDark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFF6B259E).withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: Colors.transparent,
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
                  'assets/branding/maliyati_wallet_icon_v2.png',
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
  final _appLock = AppLockService();
  int _selectedIndex = 0;
  int _smartInputRequest = 0;
  String? _smartInputScript;
  bool _smartInputAutoRun = false;
  final _smartClipboard = SmartClipboardService.instance;
  StreamSubscription<SharedMedia>? _shareSubscription;
  bool _isAppLocked = false;
  bool _isUnlocking = false;
  bool _lockOnNextResume = false;

  @override
  void initState() {
    super.initState();
    _isAppLocked = !kIsWeb && widget.controller.isAppLockEnabled;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showInitialLock());
    // These integrations are Android-only. Starting platform channels on the
    // browser immediately after Google authentication can crash the web view.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _smartClipboard.initialize(onOpenSmartInput: _openSmartInput);
      _initializeShareHandler();
    }
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
    if (kIsWeb) return;
    _smartClipboard.updateLifecycle(state);
    if (state == AppLifecycleState.paused &&
        widget.controller.isAppLockEnabled &&
        !_isUnlocking) {
      _lockOnNextResume = true;
    } else if (state == AppLifecycleState.resumed && _lockOnNextResume) {
      _lockOnNextResume = false;
      _showInitialLock();
    }
  }

  Future<void> _showInitialLock() async {
    if (kIsWeb ||
        !mounted ||
        !widget.controller.isAppLockEnabled ||
        _isUnlocking) {
      return;
    }
    setState(() => _isAppLocked = true);
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_isUnlocking || !mounted) return;
    setState(() => _isUnlocking = true);
    final unlocked = await _appLock.authenticate();
    if (mounted) {
      setState(() {
        _isUnlocking = false;
        if (unlocked) _isAppLocked = false;
      });
    }
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
    try {
      final handler = ShareHandler.instance;
      _shareSubscription = handler.sharedMediaStream.listen(
        _handleSharedMedia,
        onError: (error, stackTrace) {},
      );
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia != null) {
        _handleSharedMedia(initialMedia);
      }
    } catch (_) {
      // Sharing is an optional mobile convenience and must not block the app.
    }
  }

  void _handleSharedMedia(SharedMedia media) {
    SharedAttachment? attachment;
    for (final item in media.attachments ?? const <SharedAttachment?>[]) {
      if (item?.type == SharedAttachmentType.image) {
        attachment = item;
        break;
      }
    }
    final imagePath = attachment?.path.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WishReceiptReviewScreen(
            controller: widget.controller,
            imagePath: imagePath,
          ),
        ),
      );
      return;
    }
    final text = media.content?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    _openSmartInput(text, autoRun: false);
  }

  void _openMenu() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, animation, _) =>
            AppMenuScreen(controller: widget.controller),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Alerts'),
                subtitle: const Text('Review and adjust your spending alerts'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _selectedIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMenu();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final screens = [
          DashboardScreen(controller: controller, onOpenMenu: _openMenu),
          TransactionsScreen(controller: controller),
          AddTransactionScreen(
            key: ValueKey('smart-input-$_smartInputRequest'),
            controller: controller,
            initialScript: _smartInputScript,
            autoRunInitialScript: _smartInputAutoRun,
          ),
          AnalyticsScreen(controller: controller),
          SpendingAlertsScreen(controller: controller),
          if (controller.isAdmin) AdminScreen(controller: controller),
        ];
        final activeIndex = _selectedIndex >= screens.length
            ? screens.length - 1
            : _selectedIndex;
        final strings = controller.strings;
        FinanceFormatters.localeCode = controller.language.code;
        final indexedScreens = IndexedStack(
          index: activeIndex,
          children: screens,
        );
        final navigationBar = _CyberNavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          items: [
            _CyberNavData(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: strings.dashboard,
            ),
            _CyberNavData(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              label: strings.transactions,
            ),
            const _CyberNavData(
              icon: Icons.add_rounded,
              selectedIcon: Icons.add_rounded,
              label: 'Add',
              isAdd: true,
            ),
            _CyberNavData(
              icon: Icons.insights_outlined,
              selectedIcon: Icons.insights_rounded,
              label: controller.language.code == 'ar' ? 'التقارير' : 'Reports',
            ),
            _CyberNavData(
              icon: Icons.notifications_active_outlined,
              selectedIcon: Icons.notifications_active_rounded,
              label: controller.language.code == 'ar' ? 'المزيد' : 'More',
            ),
            if (controller.isAdmin)
              const _CyberNavData(
                icon: Icons.admin_panel_settings_outlined,
                selectedIcon: Icons.admin_panel_settings_rounded,
                label: 'Admin',
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
              body: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: AppResponsive.contentMaxWidth(
                                  context,
                                ),
                              ),
                              child: indexedScreens,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isAppLocked)
                      Positioned.fill(
                        child: _AppLockGate(
                          isUnlocking: _isUnlocking,
                          onUnlock: _unlock,
                        ),
                      ),
                    if (!_isAppLocked &&
                        Theme.of(context).brightness == Brightness.dark)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: Material(
                          color: const Color(0xFF1E1E1E),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Settings',
                            onPressed: _openMenu,
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              bottomNavigationBar: _isAppLocked
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

class GlobalTopBar extends StatelessWidget {
  const GlobalTopBar({
    super.key,
    required this.onOpenMenu,
    required this.selectedIndex,
    required this.isAdmin,
    required this.onDestinationSelected,
  });

  final VoidCallback onOpenMenu;
  final int selectedIndex;
  final bool isAdmin;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = AppResponsive.isWideWeb(context);
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/branding/maliyati_wallet_icon_v2.png',
            width: 30,
            height: 30,
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
      ],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: Container(
          height: isWide ? 68 : 58,
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
                  if (isWide) brand else const SizedBox(width: 56),
                  if (isWide) ...[
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
                            if (isAdmin)
                              _WebNavItem(
                                index: 5,
                                selectedIndex: selectedIndex,
                                icon: Icons.admin_panel_settings_outlined,
                                selectedIcon:
                                    Icons.admin_panel_settings_rounded,
                                label: 'Admin',
                                onSelected: onDestinationSelected,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    Expanded(child: Center(child: brand)),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: IconButton.filledTonal(
                      tooltip: 'Menu',
                      onPressed: onOpenMenu,
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLockGate extends StatelessWidget {
  const _AppLockGate({required this.isUnlocking, required this.onUnlock});

  final bool isUnlocking;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: .92),
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 44,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF252525),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Maliyati Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: isUnlocking ? null : onUnlock,
                    icon: isUnlocking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: const Text(
                      'Unlock',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: .55),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
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

class _CyberNavData {
  const _CyberNavData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isAdd = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isAdd;
}

class _CyberNavigationBar extends StatelessWidget {
  const _CyberNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<_CyberNavData> items;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withValues(alpha: .97)
              : const Color(0xFF061725).withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: light
                ? const Color(0xFFE1DFE7)
                : const Color(0xFF2B536E).withValues(alpha: .78),
          ),
          boxShadow: [
            BoxShadow(
              color: (light ? const Color(0xFF49366A) : Colors.black)
                  .withValues(alpha: light ? .14 : .42),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _CyberNavItem(
                  data: items[index],
                  selected: index == selectedIndex,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CyberNavItem extends StatelessWidget {
  const _CyberNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _CyberNavData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final color = selected
        ? (light ? const Color(0xFF6B259E) : const Color(0xFF12D9F4))
        : (light ? const Color(0xFF77717D) : const Color(0xFF90AABE));
    if (data.isAdd) {
      return InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: light
                    ? const [Color(0xFF8F2DC2), Color(0xFF5B1E9A)]
                    : const [Color(0xFF12D9F4), Color(0xFF256BE8)],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (light
                              ? const Color(0xFF7C38AD)
                              : const Color(0xFF12D9F4))
                          .withValues(alpha: .30),
                  blurRadius: 17,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 29),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? data.selectedIcon : data.icon,
              color: color,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              data.icon == Icons.notifications_active_outlined
                  ? 'Alerts'
                  : data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
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
