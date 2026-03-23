-- ============================================
-- SUBSCRIPTION & RECEIPT DATABASE SETUP
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Add subscription columns to students table (if not exists)
ALTER TABLE students 
ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free',
ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'inactive';

-- 2. Add transaction_id to purchase_history for receipts
ALTER TABLE purchase_history 
ADD COLUMN IF NOT EXISTS transaction_id TEXT,
ADD COLUMN IF NOT EXISTS receipt_url TEXT,
ADD COLUMN IF NOT EXISTS payment_method TEXT,
ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT,
ADD COLUMN IF NOT EXISTS purchase_type TEXT DEFAULT 'product';

-- 3. Create subscription_receipts table for detailed receipts
CREATE TABLE IF NOT EXISTS subscription_receipts (
    id TEXT PRIMARY KEY DEFAULT 'REC_' || gen_random_uuid(),
    student_id TEXT REFERENCES students(id) ON DELETE CASCADE,
    receipt_number TEXT UNIQUE NOT NULL,
    plan_name TEXT NOT NULL,
    plan_type TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    transaction_id TEXT,
    razorpay_order_id TEXT,
    razorpay_signature TEXT,
    payment_status TEXT DEFAULT 'success',
    payment_method TEXT,
    purchase_date TIMESTAMPTZ DEFAULT NOW(),
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_subscription_receipts_student_id ON subscription_receipts(student_id);
CREATE INDEX IF NOT EXISTS idx_subscription_receipts_receipt_number ON subscription_receipts(receipt_number);
CREATE INDEX IF NOT EXISTS idx_purchase_history_transaction_id ON purchase_history(transaction_id);

-- 5. Enable Row Level Security
ALTER TABLE subscription_receipts ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for subscription_receipts
DROP POLICY IF EXISTS "Users can view their own receipts" ON subscription_receipts;
CREATE POLICY "Users can view their own receipts"
ON subscription_receipts FOR SELECT
USING (student_id = auth.uid()::text);

DROP POLICY IF EXISTS "Users can insert their own receipts" ON subscription_receipts;
CREATE POLICY "Users can insert their own receipts"
ON subscription_receipts FOR INSERT
WITH CHECK (student_id = auth.uid()::text);

DROP POLICY IF EXISTS "Service role can manage receipts" ON subscription_receipts;
CREATE POLICY "Service role can manage receipts"
ON subscription_receipts FOR ALL
USING (true)
WITH CHECK (true);

-- 7. Update purchase_history with trigger to auto-set purchase_type
CREATE OR REPLACE FUNCTION set_purchase_type_default()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.product_code = 'SUBSCRIPTION' THEN
        NEW.purchase_type := 'subscription';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_purchase_type ON purchase_history;
CREATE TRIGGER set_purchase_type
BEFORE INSERT ON purchase_history
FOR EACH ROW
EXECUTE FUNCTION set_purchase_type_default();
