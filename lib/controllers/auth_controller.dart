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
    String? garageAddress,
    double? garageLatitude,
    double? garageLongitude,
  }) async {
    final supabase = client;
    if (supabase == null) throw StateError('Backend not configured');
    if (garageOwner &&
        (garageAddress == null ||
            garageAddress.trim().length < 3 ||
            garageLatitude == null ||
            garageLongitude == null ||
            garageLatitude < -90 ||
            garageLatitude > 90 ||
            garageLongitude < -180 ||
            garageLongitude > 180)) {
      throw ArgumentError('A valid garage location is required');
    }
    await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: kIsWeb
          ? Uri.base.resolve('/auth/callback').toString()
          : null,
      data: {
        'display_name': name.trim(),
        'phone': phone.trim(),
        'account_type': garageOwner ? 'garage_owner' : 'customer',
        if (garageOwner) 'garage_address': garageAddress!.trim(),
        if (garageOwner) 'garage_latitude': garageLatitude,
        if (garageOwner) 'garage_longitude': garageLongitude,
      },
    );
  }

  Future<void> resendSignupConfirmation(String email) async {
    final supabase = client;
    if (supabase == null) throw StateError('Backend not configured');
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: kIsWeb
          ? Uri.base.resolve('/auth/callback').toString()
          : null,
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
