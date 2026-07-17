import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../controllers/dashboard_controller.dart';
import '../services/firebase_finance_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isCreatingAccount = false;
  bool _isCheckingUserId = false;
  bool? _isUserIdAvailable;
  String _userIdMessage = '';
  int _userIdCheckVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.clearError();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Color.lerp(
        theme.colorScheme.surface,
        theme.colorScheme.primaryContainer,
        0.12,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'assets/branding/vak_app_icon_3.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppConfig.appName,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      _isCreatingAccount
                                          ? 'Create your workspace'
                                          : 'Welcome back',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isCreatingAccount ? 'Registration' : 'Login',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_isCreatingAccount) ...[
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (value) {
                                if (!_isCreatingAccount) {
                                  return null;
                                }
                                if ((value ?? '').trim().length < 2) {
                                  return 'Enter your name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _userIdController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'User ID',
                                prefixIcon: const Icon(Icons.badge_rounded),
                                suffixIcon: _isCheckingUserId
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : _isUserIdAvailable == null
                                    ? null
                                    : Icon(
                                        _isUserIdAvailable!
                                            ? Icons.check_circle_rounded
                                            : Icons.error_rounded,
                                        color: _isUserIdAvailable!
                                            ? Colors.green
                                            : theme.colorScheme.error,
                                      ),
                                helperText: _userIdMessage.isEmpty
                                    ? 'Example: ali or store_1'
                                    : _userIdMessage,
                                helperStyle: theme.textTheme.bodySmall
                                    ?.copyWith(
                                      color: _isUserIdAvailable == false
                                          ? theme.colorScheme.error
                                          : _isUserIdAvailable == true
                                          ? Colors.green.shade700
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              onChanged: (_) => _checkUserId(),
                              validator: (value) {
                                if (!_isCreatingAccount) {
                                  return null;
                                }
                                final normalized =
                                    FirebaseFinanceService.normalizeAccountId(
                                      value ?? '',
                                    );
                                if (normalized.length < 2) {
                                  return 'Use at least 2 letters or numbers.';
                                }
                                if (_isUserIdAvailable == false) {
                                  return 'This User ID is already used.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_rounded),
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          if (!_isCreatingAccount) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: controller.isLoading
                                    ? null
                                    : _sendPasswordReset,
                                icon: const Icon(Icons.lock_reset_rounded),
                                label: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: controller.isLoading
                                ? null
                                : _submitEmail,
                            icon: controller.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isCreatingAccount
                                        ? Icons.person_add_rounded
                                        : Icons.login_rounded,
                                  ),
                            label: Text(
                              _isCreatingAccount ? 'Create account' : 'Sign in',
                            ),
                          ),
                          if (!_isCreatingAccount) ...[
                            const SizedBox(height: 14),
                            if (!kIsWeb) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                onPressed: controller.isLoading
                                    ? null
                                    : controller.signInWithGoogle,
                                icon: const Icon(Icons.account_circle_rounded),
                                label: const Text('Continue with Google'),
                              ),
                            ],
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: controller.isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isCreatingAccount = true;
                                        _isUserIdAvailable = null;
                                        _userIdMessage = '';
                                      });
                                      _checkUserId();
                                    },
                              child: const Text('Registration'),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: controller.isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isCreatingAccount = false;
                                        _isUserIdAvailable = null;
                                        _userIdMessage = '';
                                      });
                                    },
                              child: const Text('Back to login'),
                            ),
                          ],
                          if (controller.firebaseSetupMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageBox(
                              icon: Icons.settings_rounded,
                              message: controller.firebaseSetupMessage!,
                            ),
                          ],
                          if (controller.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageBox(
                              icon: Icons.error_outline_rounded,
                              isError: true,
                              message: controller.errorMessage!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isCreatingAccount) {
      final idReady = await _checkUserId(force: true);
      if (!idReady) {
        _formKey.currentState!.validate();
        return;
      }
      await widget.controller.createAccountWithEmail(
        name: _nameController.text,
        accountId: _userIdController.text,
        email: email,
        password: password,
      );
    } else {
      await widget.controller.signInWithEmail(email: email, password: password);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    final sent = await widget.controller.sendPasswordResetEmail(email);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Password reset email sent to $email.'
              : widget.controller.errorMessage ?? 'Could not send reset email.',
        ),
      ),
    );
  }

  Future<bool> _checkUserId({bool force = false}) async {
    if (!_isCreatingAccount) {
      return true;
    }
    final version = ++_userIdCheckVersion;
    final normalized = FirebaseFinanceService.normalizeAccountId(
      _userIdController.text,
    );
    if (normalized.length < 2) {
      setState(() {
        _isCheckingUserId = false;
        _isUserIdAvailable = null;
        _userIdMessage = 'Use at least 2 letters or numbers.';
      });
      return false;
    }
    setState(() {
      _isCheckingUserId = true;
      _userIdMessage = 'Checking $normalized...';
    });
    final available = await widget.controller.isAccountIdAvailable(normalized);
    if (!mounted || version != _userIdCheckVersion) {
      return false;
    }
    setState(() {
      _isCheckingUserId = false;
      _isUserIdAvailable = available;
      _userIdMessage = available
          ? '$normalized is available.'
          : '$normalized is already used. Choose another ID.';
    });
    return available;
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
