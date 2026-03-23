-- This script will permanently delete ALL data in your platform so you can start completely fresh with End-to-End Encryption.
-- WARNING: This action cannot be undone.

-- We use DELETE instead of TRUNCATE CASCADE to ensure the `operators` table is absolutely safe!
-- (If `operators` has a foreign key to `students`, using TRUNCATE CASCADE would accidentally destroy your operators too).

DELETE FROM public.subscription_receipts;
DELETE FROM public.purchase_history;
DELETE FROM public.materials;
DELETE FROM public.folders;
DELETE FROM public.subjects;
DELETE FROM public.store_banners;
DELETE FROM public.store_products;

-- Delete all students EXCEPT those who are also Operators (if they are linked).
-- If you want to delete ALL students and don't care if it breaks operator links, uncomment the line below:
-- DELETE FROM public.students;

-- Deletes all students except the ones whose IDs exist in the operators table
DELETE FROM public.students 
WHERE id NOT IN (SELECT id::text FROM public.operators)
  AND id NOT IN (SELECT student_id::text FROM public.operators WHERE student_id IS NOT NULL);
