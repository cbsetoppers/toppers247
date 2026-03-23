import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';
import 'supabase_provider.dart';

class AuthNotifier extends StateNotifier<AsyncValue<StudentModel?>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Called at app start to restore session from Supabase native session.
  /// Uses auth UUID (not email) as the lookup key — guarantees auth.users.id == students.id.
  Future<void> restoreSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    state = const AsyncValue.loading();
    try {
      final uuid = session.user.id; // ← authoritative UUID from auth.users
      final user = await ref
          .read(supabaseServiceProvider)
          .fetchProfileById(uuid); // UUID-first lookup: auth.id → students.id
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String identifier, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref
          .read(supabaseServiceProvider)
          .login(identifier, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register({
    required String name,
    required String dob,
    required String studentClass,
    String? stream,
    required String email,
    String? phone,
    required String password,
    List<String>? competitiveExams,
    String gender = 'OTHER',
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await ref
          .read(supabaseServiceProvider)
          .register(
            name: name,
            dob: dob,
            studentClass: studentClass,
            stream: stream,
            email: email,
            phone: phone,
            password: password,
            competitiveExams: competitiveExams,
            gender: gender,
          );
      // Always set data even with stub — never leave in loading state
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // So the RegisterScreen can show the error
    }
  }

  Future<void> resetPassword(String email) async {
    await ref.read(supabaseServiceProvider).sendPasswordReset(email);
  }

  Future<void> updateProfile({
    required String id,
    required String name,
    String? phone,
    required String gender,
    String? stream,
    required List<String> competitiveExams,
    String? board,
    required String dob,
    required String studentClass,
  }) async {
    final oldUser = state.value;
    if (oldUser == null) return;

    state = const AsyncValue.loading();
    try {
      await ref
          .read(supabaseServiceProvider)
          .updateProfile(
            id: id,
            name: name,
            phone: phone,
            gender: gender,
            stream: stream,
            competitiveExams: competitiveExams,
            board: board,
            dob: dob,
            studentClass: studentClass,
          );

      // Refetch profile using UUID — the only reliable join between auth and students
      final uuid = Supabase.instance.client.auth.currentUser?.id ?? oldUser.id;
      final user = await ref
          .read(supabaseServiceProvider)
          .fetchProfileById(uuid);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await ref.read(supabaseServiceProvider).signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateAvatarUrl(String avatarUrl) async {
    final oldUser = state.value;
    if (oldUser == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(supabaseServiceProvider).updateAvatarUrl(oldUser.id, avatarUrl);
      
      final uuid = Supabase.instance.client.auth.currentUser?.id ?? oldUser.id;
      final user = await ref
          .read(supabaseServiceProvider)
          .fetchProfileById(uuid);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeAvatar() async {
    final oldUser = state.value;
    if (oldUser == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(supabaseServiceProvider).updateAvatarUrl(oldUser.id, '');
      
      final uuid = Supabase.instance.client.auth.currentUser?.id ?? oldUser.id;
      final user = await ref
          .read(supabaseServiceProvider)
          .fetchProfileById(uuid);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> activateSubscription(String plan) async {
    final oldUser = state.value;
    if (oldUser == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(supabaseServiceProvider).updateSubscriptionPlan(oldUser.id, plan);
      
      final uuid = Supabase.instance.client.auth.currentUser?.id ?? oldUser.id;
      final user = await ref
          .read(supabaseServiceProvider)
          .fetchProfileById(uuid);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<StudentModel?>>((ref) {
      return AuthNotifier(ref);
    });
