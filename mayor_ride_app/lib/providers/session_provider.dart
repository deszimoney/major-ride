import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../services/auth_repository.dart';
import '../services/local_store.dart';

/// Holds the signed-in profile and mirrors `getCurrentUser` / `setCurrentUser`
/// / `clearCurrentUser` from database.js, backed by Supabase Auth sessions.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._auth, this._store) {
    _restoreCachedUser();
    _authSub = _auth.authStateChanges.listen(_onAuthStateChange);
  }

  final AuthRepository _auth;
  final LocalStore _store;
  StreamSubscription<AuthState>? _authSub;

  AppUser? _currentUser;
  bool _initializing = true;

  /// Set when a password-recovery deep link opens the app (mirrors the
  /// `location.hash.includes('type=recovery')` check in auth.js). The root
  /// widget listens for this to pop open the "choose a new password" sheet,
  /// then calls [consumePasswordRecoveryRequest] to clear it.
  bool passwordRecoveryRequested = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get initializing => _initializing;

  bool consumePasswordRecoveryRequest() {
    if (!passwordRecoveryRequested) return false;
    passwordRecoveryRequested = false;
    return true;
  }

  void _restoreCachedUser() {
    final cached = _store.readMap(LocalStore.currentUser);
    if (cached != null) {
      _currentUser = AppUser.fromMap(cached);
    }
  }

  Future<void> _onAuthStateChange(AuthState state) async {
    final authUser = state.session?.user;
    if (authUser == null) {
      if (state.event == AuthChangeEvent.signedOut) {
        await _setUser(null);
      }
      return;
    }

    final profile = await _auth.profileFor(authUser);

    if (state.event == AuthChangeEvent.passwordRecovery) {
      // Supabase signs the user in with a short-lived session so they can
      // call updatePassword(); surface that as a prompt rather than a
      // silent login.
      passwordRecoveryRequested = true;
    }

    await _setUser(profile);
  }

  Future<void> setUser(AppUser user) => _setUser(user);

  Future<void> _setUser(AppUser? user) async {
    _currentUser = user;
    if (user == null) {
      await _store.remove(LocalStore.currentUser);
    } else {
      await _store.writeMap(LocalStore.currentUser, user.toMap());
    }
    _initializing = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _setUser(null);
  }

  /// Called once the splash/root widget has had a chance to read the cache,
  /// so a stale "loading" spinner never lingers when there's no session.
  void finishInitializing() {
    if (_initializing) {
      _initializing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
