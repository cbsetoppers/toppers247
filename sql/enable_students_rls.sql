-- Enable Row Level Security on the students table and allow users to access only their own records
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- Allow inserts only for the authenticated user matching the id field
CREATE POLICY "students_insert_own" ON public.students
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Allow selects only for the authenticated user's own record
CREATE POLICY "students_select_own" ON public.students
FOR SELECT
USING (auth.uid() = id);
