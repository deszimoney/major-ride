import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/session_provider.dart';
import '../services/auth_repository.dart';
import '../theme/app_theme.dart';

enum AuthMode { login, signup, forgot, reset }

/// Ports the `#authModal` in auth.js: one sheet that switches between login,
/// sign-up, forgot-password and set-new-password states.
Future<void> showAuthSheet(BuildContext context, {AuthMode mode = AuthMode.login}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthSheet(initialMode: mode),
  );
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.initialMode});

  final AuthMode initialMode;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  late AuthMode _mode = widget.initialMode;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _title => switch (_mode) {
    AuthMode.signup => 'Create your account',
    AuthMode.forgot => 'Reset your password',
    AuthMode.reset => 'Choose a new password',
    AuthMode.login => 'Welcome back',
  };

  String get _subtitle => switch (_mode) {
    AuthMode.signup =>
      'Join the Mayor Ride Co. community and get ready for your next ride.',
    AuthMode.forgot =>
      'Enter your email and we will send instructions to reset your password.',
    AuthMode.reset => 'Choose a new password for your account.',
    AuthMode.login =>
      'Sign in to manage your account and keep your next ride moving.',
  };

  String get _submitLabel => switch (_mode) {
    AuthMode.signup => 'Create account',
    AuthMode.forgot => 'Send reset link',
    AuthMode.reset => 'Save new password',
    AuthMode.login => 'Login',
  };

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthRepository>();
    final session = context.read<SessionProvider>();

    setState(() {
      _submitting = true;
      _message = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = switch (_mode) {
      AuthMode.signup => await auth.register(
        name: name,
        email: email,
        password: password,
      ),
      AuthMode.forgot => await auth.requestPasswordReset(email),
      AuthMode.reset => await auth.updatePassword(password),
      AuthMode.login => await auth.login(email: email, password: password),
    };

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _submitting = false;
        _message = result.message ?? 'Something went wrong. Please try again.';
        _messageIsError = true;
      });
      return;
    }

    if (_mode == AuthMode.forgot) {
      setState(() {
        _submitting = false;
        _message = result.message;
        _messageIsError = false;
      });
      return;
    }

    if (_mode == AuthMode.reset) {
      setState(() {
        _submitting = false;
        _message = 'Password updated. You can now log in.';
        _messageIsError = false;
      });
      _setMode(AuthMode.login);
      return;
    }

    if (result.requiresConfirmation) {
      setState(() {
        _submitting = false;
        _message = result.message;
        _messageIsError = false;
      });
      _setMode(AuthMode.login);
      return;
    }

    if (result.user != null) {
      await session.setUser(result.user!);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Welcome to ${AppConfig.brandName}, ${result.user?.name ?? ''}! '
          'You are now signed in.',
        ),
      ),
    );
  }

  Future<void> _continueWithGoogle() async {
    final auth = context.read<AuthRepository>();
    setState(() {
      _submitting = true;
      _message = null;
    });

    final result = await auth.signInWithProvider('google');

    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!result.success) {
        _message = result.message;
        _messageIsError = true;
      }
    });

    if (result.success && result.redirecting) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForgot = _mode == AuthMode.forgot;
    final isReset = _mode == AuthMode.reset;
    final isSignup = _mode == AuthMode.signup;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.lightBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow(AppConfig.brandName),
                  const SizedBox(height: 6),
                  Text(_title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 18),
                  if (!isForgot && !isReset)
                    Row(
                      children: [
                        Expanded(
                          child: _ModeTab(
                            label: 'Login',
                            active: _mode == AuthMode.login,
                            onTap: () => _setMode(AuthMode.login),
                          ),
                        ),
                        Expanded(
                          child: _ModeTab(
                            label: 'Sign Up',
                            active: _mode == AuthMode.signup,
                            onTap: () => _setMode(AuthMode.signup),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (isSignup) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!isReset) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter your email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!isForgot)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'Use at least 6 characters.',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Password must be at least 6 characters long.'
                          : null,
                    ),
                  if (_mode == AuthMode.login)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _setMode(AuthMode.forgot),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _messageIsError
                            ? AppColors.danger
                            : AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_submitLabel),
                  ),
                  if (_mode == AuthMode.login) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: AppColors.line)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.line)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _continueWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 22),
                      label: const Text('Google'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.darkStrong : AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
