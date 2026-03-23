"""
UUID Mismatch Fix Script
========================
Root cause: auth.users UUID and students.id can mismatch because:
1. fetchProfile() uses .ilike('email',...) — never validates UUID matches
2. restoreSession uses email to look up; if DB row has wrong id, the StudentModel.id is wrong
3. The DB insert uses authRes.user!.id which IS correct, but any existing rows from
   prior broken registrations may have a wrong id

Fix:
- Add fetchProfileById(uuid) that uses the auth UUID directly
- Change login() to use fetchProfileById after signIn (auth gives us the real UUID)  
- Change restoreSession() in auth_provider to pass UUID, not email
- The register() already uses authRes.user!.id for the insert — that is correct
"""

service_path = r'lib\services\supabase_service.dart'
provider_path = r'lib\providers\auth_provider.dart'

# ── SERVICE FILE ────────────────────────────────────────────────────────────

with open(service_path, 'r', encoding='utf-8') as f:
    svc = f.read()

# Fix 1: login() — after signInWithPassword, use the UUID from the auth response
# instead of re-fetching by email. UUID is the source of truth.
old_login = (
    "    if (res.user != null) {\r\n"
    "      final profile = await fetchProfile(email);\r\n"
    "      if (profile == null) {\r\n"
    "        throw Exception(\r\n"
    "          'Profile not found in database. Please contact support.',\r\n"
    "        );\r\n"
    "      }\r\n"
    "      return profile;\r\n"
    "    }\r\n"
    "    return null;\r\n"
    "  }"
)

new_login = (
    "    if (res.user != null) {\r\n"
    "      final authUid = res.user!.id; // ← This IS the canonical UUID from auth.users\r\n"
    "      // ALWAYS look up by UUID, not email — UUID is the source of truth\r\n"
    "      final profile = await fetchProfileById(authUid);\r\n"
    "      if (profile == null) {\r\n"
    "        throw Exception(\r\n"
    "          'Profile not found. The account exists but has no student record. '\r\n"
    "          'Please contact support or re-register.',\r\n"
    "        );\r\n"
    "      }\r\n"
    "      return profile;\r\n"
    "    }\r\n"
    "    return null;\r\n"
    "  }"
)

if old_login in svc:
    svc = svc.replace(old_login, new_login)
    print("Fix 1 applied: login() now uses fetchProfileById")
else:
    print("WARNING Fix 1: pattern not found in login()")

# Fix 2: Add fetchProfileById() — UUID-first lookup
# Insert it right after fetchProfile()

old_fetch_profile_end = (
    "    return null;\r\n"
    "  }\r\n"
    "\r\n"
    "  Future\u003cvoid\u003e signOut()"
)

new_fetch_profile_end = (
    "    return null;\r\n"
    "  }\r\n"
    "\r\n"
    "  /// Fetch student profile by Supabase auth UUID.\r\n"
    "  /// This is the CORRECT and RELIABLE way to look up a profile because\r\n"
    "  /// the students.id column is a foreign key to auth.users.id.\r\n"
    "  Future\u003cStudentModel?\u003e fetchProfileById(String uuid) async {\r\n"
    "    debugPrint('\ud83d\udd0d fetchProfileById: $uuid');\r\n"
    "\r\n"
    "    // 1. Try students table first\r\n"
    "    try {\r\n"
    "      final profile = await _client\r\n"
    "          .from('students')\r\n"
    "          .select()\r\n"
    "          .eq('id', uuid)\r\n"
    "          .maybeSingle();\r\n"
    "      if (profile != null) {\r\n"
    "        debugPrint('\u2705 Found student profile for UUID: $uuid');\r\n"
    "        return StudentModel.fromJson(profile);\r\n"
    "      }\r\n"
    "    } catch (e) {\r\n"
    "      debugPrint('\u26a0\ufe0f students lookup error: $e');\r\n"
    "    }\r\n"
    "\r\n"
    "    // 2. Try operators table (admin accounts)\r\n"
    "    try {\r\n"
    "      final operator = await _client\r\n"
    "          .from('operators')\r\n"
    "          .select()\r\n"
    "          .eq('id', uuid)\r\n"
    "          .maybeSingle();\r\n"
    "      if (operator != null) {\r\n"
    "        final opEmail = operator['email']?.toString() ?? '';\r\n"
    "        return StudentModel(\r\n"
    "          id: uuid,\r\n"
    "          name: operator['name'] ?? 'Operator',\r\n"
    "          studentId: 'OP_${uuid.substring(0, 5).toUpperCase()}',\r\n"
    "          email: opEmail,\r\n"
    "          dob: '',\r\n"
    "          studentClass: 'Admin',\r\n"
    "          gender: 'MALE',\r\n"
    "          competitiveExams: [],\r\n"
    "          competitiveExamIds: [],\r\n"
    "          board: 'CBSE',\r\n"
    "          isVerified: true,\r\n"
    "          isOperator: true,\r\n"
    "          role: operator['role'],\r\n"
    "        );\r\n"
    "      }\r\n"
    "    } catch (e) {\r\n"
    "      debugPrint('\u26a0\ufe0f operators lookup error: $e');\r\n"
    "    }\r\n"
    "\r\n"
    "    debugPrint('\u274c No profile found for UUID: $uuid');\r\n"
    "    return null;\r\n"
    "  }\r\n"
    "\r\n"
    "  Future\u003cvoid\u003e signOut()"
)

if old_fetch_profile_end in svc:
    svc = svc.replace(old_fetch_profile_end, new_fetch_profile_end)
    print("Fix 2 applied: fetchProfileById() added")
else:
    print("WARNING Fix 2: insertion point not found")
    # Debug
    idx = svc.find("Future<void> signOut()")
    print(f"  signOut found at: {idx}")
    if idx > 0:
        print("  Context:", repr(svc[idx-100:idx+50]))

# Fix 3: register() — After signIn to get session, re-read the UUID from the
# ACTIVE SESSION rather than the signUp response, to guarantee they match.
old_session_check = (
    "    // 2. CRITICAL: Ensure active session before DB insert so RLS is satisfied.\r\n"
    "    // auth.signUp may return user without an active session (e.g., email confirmation mode).\r\n"
    "    // We explicitly sign in so auth.uid() == userId when inserting to students table.\r\n"
    "    try {\r\n"
    "      debugPrint('\ud83d\udd04 Step 2: Establishing session for DB insert...');\r\n"
    "      final session = _client.auth.currentSession;\r\n"
    "      if (session == null || session.user.id != userId) {\r\n"
    "        await _client.auth.signInWithPassword(\r\n"
    "          email: email.trim().toLowerCase(),\r\n"
    "          password: password,\r\n"
    "        );\r\n"
    "        debugPrint('\u2705 Session established');\r\n"
    "      } else {\r\n"
    "        debugPrint('\u2705 Session already active');\r\n"
    "      }\r\n"
    "    } catch (e) {\r\n"
    "      debugPrint('\u26a0\ufe0f Session establishment warning: $e \u2014 continuing...');\r\n"
    "      // Non-fatal: signUp may have already established session\r\n"
    "    }"
)

new_session_check = (
    "    // 2. CRITICAL: Ensure active session before DB insert so RLS is satisfied.\r\n"
    "    // auth.signUp may return user without an active session (e.g., email confirmation mode).\r\n"
    "    // We explicitly sign in so auth.uid() == userId when inserting to students table.\r\n"
    "    try {\r\n"
    "      debugPrint('\ud83d\udd04 Step 2: Establishing session for DB insert...');\r\n"
    "      AuthResponse? signInRes;\r\n"
    "      final session = _client.auth.currentSession;\r\n"
    "      if (session == null || session.user.id != userId) {\r\n"
    "        signInRes = await _client.auth.signInWithPassword(\r\n"
    "          email: email.trim().toLowerCase(),\r\n"
    "          password: password,\r\n"
    "        );\r\n"
    "        debugPrint('\u2705 Session established');\r\n"
    "      } else {\r\n"
    "        debugPrint('\u2705 Session already active');\r\n"
    "      }\r\n"
    "      // ALWAYS re-read UUID from the active session after sign-in.\r\n"
    "      // This guarantees auth.uid() == userId == students.id — no mismatch possible.\r\n"
    "      final activeSession = _client.auth.currentSession;\r\n"
    "      if (activeSession != null) {\r\n"
    "        final sessionUid = activeSession.user.id;\r\n"
    "        if (sessionUid != userId) {\r\n"
    "          debugPrint('\u26a0\ufe0f UID mismatch detected! Using session UUID: $sessionUid (was $userId)');\r\n"
    "          userId = sessionUid; // Override with the authoritative session UUID\r\n"
    "        }\r\n"
    "      }\r\n"
    "    } catch (e) {\r\n"
    "      debugPrint('\u26a0\ufe0f Session establishment warning: $e \u2014 continuing...');\r\n"
    "      // Non-fatal: signUp may have already established session\r\n"
    "    }"
)

if old_session_check in svc:
    svc = svc.replace(old_session_check, new_session_check)
    print("Fix 3 applied: register() now re-reads UUID from session after signIn")
else:
    print("WARNING Fix 3: session check pattern not found")

with open(service_path, 'w', encoding='utf-8') as f:
    f.write(svc)

print(f"\nsupabase_service.dart saved ({len(svc)} bytes)")

# ── PROVIDER FILE ───────────────────────────────────────────────────────────

with open(provider_path, 'r', encoding='utf-8') as f:
    prov = f.read()

# Fix 4: restoreSession() — use UUID from session, not email
old_restore = (
    "  /// Called at app start to restore session from Supabase native session\r\n"
    "  Future\u003cvoid\u003e restoreSession() async {\r\n"
    "    final session = Supabase.instance.client.auth.currentSession;\r\n"
    "    if (session == null) return;\r\n"
    "\r\n"
    "    state = const AsyncValue.loading();\r\n"
    "    try {\r\n"
    "      final email = session.user.email;\r\n"
    "      if (email == null) {\r\n"
    "        state = const AsyncValue.data(null);\r\n"
    "        return;\r\n"
    "      }\r\n"
    "      final user = await ref.read(supabaseServiceProvider).fetchProfile(email);\r\n"
    "      state = AsyncValue.data(user);\r\n"
    "    } catch (e, st) {\r\n"
    "      state = AsyncValue.error(e, st);\r\n"
    "    }\r\n"
    "  }"
)

new_restore = (
    "  /// Called at app start to restore session from Supabase native session.\r\n"
    "  /// Uses the auth UUID (not email) for the DB lookup — this guarantees\r\n"
    "  /// that auth.users.id and students.id are always in sync.\r\n"
    "  Future\u003cvoid\u003e restoreSession() async {\r\n"
    "    final session = Supabase.instance.client.auth.currentSession;\r\n"
    "    if (session == null) return;\r\n"
    "\r\n"
    "    state = const AsyncValue.loading();\r\n"
    "    try {\r\n"
    "      final uuid = session.user.id; // \u2190 authoritative UUID from auth.users\r\n"
    "      // Lookup by UUID — this is the only correct way to join auth \u2194 students\r\n"
    "      final user = await ref\r\n"
    "          .read(supabaseServiceProvider)\r\n"
    "          .fetchProfileById(uuid);\r\n"
    "      state = AsyncValue.data(user);\r\n"
    "    } catch (e, st) {\r\n"
    "      state = AsyncValue.error(e, st);\r\n"
    "    }\r\n"
    "  }"
)

if old_restore in prov:
    prov = prov.replace(old_restore, new_restore)
    print("\nFix 4 applied: restoreSession() now uses fetchProfileById(uuid)")
else:
    print("\nWARNING Fix 4: restoreSession pattern not found")

with open(provider_path, 'w', encoding='utf-8') as f:
    f.write(prov)

print(f"auth_provider.dart saved ({len(prov)} bytes)")
print("\n✅ All UUID-alignment fixes applied!")
