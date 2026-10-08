import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';

/// Outcome of an auth call, shaped like the `{ success, message, user }`
/// objects database.js returns so the UI logic ports over directly.
class AuthResult {
  const AuthResult.success({
    this.user,
    this.message,
    this.requiresConfirmation = false,
    this.redirecting = false,
  }) : success = true;

  const AuthResult.failure(this.message)
    : success = false,
      user = null,
      requiresConfirmation = false,
      redirecting = false;

  final bool success;
  final String? message;
  final AppUser? user;

  /// Supabase returned a user but no session — the email needs confirming.
  final bool requiresConfirmation;

  /// An OAuth flow handed off to the browser; the session arrives via deep link.
  final bool redirecting;
}

/// Ports the auth half of database.js onto Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  GoTrueClient get _auth => _client.auth;

  Session? get session => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Reads `public.users`, falling back to a profile derived from the auth
  /// record when the row has not been created yet.
  Future<AppUser> profileFor(User authUser, {String fallbackName = ''}) async {
    final email = AppUser.normalizeEmail(authUser.email);

    try {
      final row = await _client
          .from('users')
          .select('id, name, email, provider, role')
          .eq('id', authUser.id)
          .maybeSingle();
      if (row != null) return AppUser.fromMap(row);
    } on PostgrestException {
      // Table missing or blocked by RLS — fall through to the derived profile.
    }

    final metadata = authUser.userMetadata ?? const {};
    final derivedName = fallbackName.isNotEmpty
        ? fallbackName
        : (metadata['name'] ?? metadata['full_name'] ?? '') as String? ?? '';

    return AppUser(
      id: authUser.id,
      name: derivedName.isNotEmpty ? derivedName : email.split('@').first,
      email: email,
      provider: authUser.appMetadata['provider'] as String? ?? 'email',
      role: AppUser.roleFor(email),
    );
  }

  Future<void> upsertProfile(AppUser user) async {
    try {
      await _client.from('users').upsert(user.toMap(), onConflict: 'id');
    } on PostgrestException {
      // Profile sync is best-effort, same as saveUsers() on the website.
    }
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = AppUser.normalizeEmail(email);

    if (!_emailPattern.hasMatch(normalized)) {
      return const AuthResult.failure('Enter a valid email address.');
    }
    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters long.',
      );
    }

    final displayName = name.trim().isNotEmpty
        ? name.trim()
        : normalized.split('@').first;

    try {
      final response = await _auth.signUp(
        email: normalized,
        password: password,
        data: {'name': displayName},
      );

      final authUser = response.user;
      if (authUser == null) {
        return const AuthResult.failure(
          'We could not create that account. Please try again.',
        );
      }

      final profile = AppUser(
        id: authUser.id,
        name: displayName,
        email: normalized,
        role: AppUser.roleFor(normalized),
      );
      await upsertProfile(profile);

      if (response.session == null) {
        return const AuthResult.success(
          requiresConfirmation: true,
          message:
              'Account created. Confirm your email if required, then log in.',
        );
      }

      return AuthResult.success(
        user: profile,
        message: 'Account created successfully.',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalized = AppUser.normalizeEmail(email);

    try {
      final response = await _auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        return const AuthResult.failure('No account found with that email.');
      }
      return AuthResult.success(user: await profileFor(authUser));
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  Future<AuthResult> requestPasswordReset(String email) async {
    final normalized = AppUser.normalizeEmail(email);
    if (!_emailPattern.hasMatch(normalized)) {
      return const AuthResult.failure('Enter a valid email address.');
    }

    try {
      await _auth.resetPasswordForEmail(
        normalized,
        redirectTo: AppConfig.authRedirectUrl,
      );
      return const AuthResult.success(
        message: 'Check your email for a password reset link.',
      );
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  /// Used after the recovery deep link has opened a session.
  Future<AuthResult> updatePassword(String password) async {
    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters long.',
      );
    }
    if (_auth.currentSession == null) {
      return const AuthResult.failure(
        'Open the reset link from your email first, then set a new password.',
      );
    }

    try {
      await _auth.updateUser(UserAttributes(password: password));
      return const AuthResult.success(message: 'Password updated.');
    } on AuthException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  Future<AuthResult> signInWithProvider(String provider) async {
    final name = provider.toLowerCase();
    final label = name == 'google' ? 'Google' : 'Apple';

    if (AppConfig.socialProviders[name] != true) {
      return AuthResult.failure(
        '$label sign-in is not enabled yet. Enable this provider in Supabase '
        'Authentication settings, then set its flag in app_config.dart to true.',
      );
    }

    final target = switch (name) {
      'google' => OAuthProvider.google,
      'apple' => OAuthProvider.apple,
      _ => null,
    };
    if (target == null) {
      return AuthResult.failure('$label sign-in is not supported.');
    }

    try {
      await _auth.signInWithOAuth(
        target,
        redirectTo: AppConfig.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return const AuthResult.success(redirecting: true);
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('provider is not enabled')) {
        return AuthResult.failure(
          '$label sign-in is not enabled in Supabase yet. Open Authentication '
          '> Providers > $label, add the client ID and secret, save, then retry.',
        );
      }
      return AuthResult.failure(error.message);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
