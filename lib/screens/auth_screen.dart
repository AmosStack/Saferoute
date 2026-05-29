import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/modern_surface.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.localeCode,
    required this.onAuthenticated,
  });

  final String localeCode;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = AuthService.instance;
      final session = _isRegisterMode
          ? await authService.registerWithEmail(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
            )
          : await authService.signInWithEmail(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

      if (!mounted) return;
      widget.onAuthenticated(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final session = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      widget.onAuthenticated(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _continueWithFacebook() async {
    setState(() {
      _isSubmitting = true;
    });
    final session = await AuthService.instance.signInWithFacebook();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    widget.onAuthenticated(session);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings(widget.localeCode);

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: HoverSurface(
                    borderRadius: 28,
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GreenSectionHeader(
                              title: _isRegisterMode ? strings.createAccount : strings.welcomeBack,
                              subtitle: _isRegisterMode ? strings.registerPrompt : strings.loginPrompt,
                              trailing: const Icon(Icons.safety_check_rounded, color: Colors.white),
                            ),
                            const SizedBox(height: 18),
                            if (_isRegisterMode) ...[
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.person_outline),
                                ).copyWith(labelText: strings.fullName),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return strings.enterName;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _emailController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.email_outlined),
                              ).copyWith(labelText: strings.emailAddress),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty || !text.contains('@')) {
                                  return strings.enterValidEmail;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_isRegisterMode) ...[
                              TextFormField(
                                controller: _phoneController,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ).copyWith(labelText: strings.phoneNumber),
                                validator: (value) {
                                  if (value == null || value.trim().length < 7) {
                                    return strings.enterValidPhone;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.lock_outline),
                              ).copyWith(labelText: strings.password),
                              validator: (value) {
                                if (value == null || value.length < 8) {
                                  return strings.passwordMin;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: Text(
                                _isRegisterMode ? strings.register : strings.logIn,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRegisterMode = !_isRegisterMode;
                                      });
                                    },
                              child: Text(
                                _isRegisterMode ? strings.alreadyHaveAccount : strings.needAccount,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    strings.or,
                                    style: TextStyle(color: scheme.tertiary),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _continueWithGoogle,
                              icon: const _SocialMark(
                                text: 'G',
                                color: Color(0xFF1A73E8),
                              ),
                              label: Text(strings.continueGoogle),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _continueWithFacebook,
                              icon: const _SocialMark(
                                text: 'f',
                                color: Color(0xFF1877F2),
                              ),
                              label: Text(strings.continueFacebook),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialMark extends StatelessWidget {
  const _SocialMark({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerHighest],
        ),
      ),
    );
  }
}
