-- NOTE: DO NOT run this until your Flutter E2EE `StudentModel.fromJson` logic is completely updated!
-- Running this immediately will corrupt your existing data structure for old users.

-- 1. Add Encryption Configuration Columns to `students`
ALTER TABLE public.students 
ADD COLUMN IF NOT EXISTS public_key TEXT,
ADD COLUMN IF NOT EXISTS user_encrypted_key TEXT,
ADD COLUMN IF NOT EXISTS admin_encrypted_key TEXT,
ADD COLUMN IF NOT EXISTS crypto_iv TEXT;

-- 2. Once all previous unencrypted rows are migrated, enforce strong constraints if desired.
-- For true E2EE, the 'name' and 'phone' columns must store large Base64 strings.
ALTER TABLE public.students ALTER COLUMN name TYPE TEXT;
ALTER TABLE public.students ALTER COLUMN phone TYPE TEXT;

-- 3. In the React Admin Panel, we will use the `admin_encrypted_key` and decode it 
-- behind the scenes using the privately kept Admin Key!
