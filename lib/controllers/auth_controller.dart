import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends ChangeNotifier {
  final SupabaseClient? client;
  late final StreamSubscription<AuthState>? _subscription;

  AuthController(this.client) {
    _subscription = client?.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  bool get isConfigured => client != null;
  User? get user => client?.auth.currentUser;
  bool get isSignedIn => user != null;
  bool get isGarageOwner =>
      user?.userMetadata?['account_type'] == 'garage_owner';

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required bool garageOwner,
  }) async {
    final supabase = client;
    if (supabase == null) throw StateError('Backend not configured');
    await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': name.trim(),
        'phone': phone.trim(),
        'account_type': garageOwner ? 'garage_owner' : 'customer',
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    final supabase = client;
    if (supabase == null) throw StateError('Backend not configured');
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await client?.auth.signOut();
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    final supabase = client;
    if (supabase == null) throw StateError('Backend not configured');
    await supabase.auth.resetPasswordForEmail(email.trim());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
