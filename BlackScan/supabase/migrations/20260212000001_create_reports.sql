-- Migration: Create reports table for user feedback/reports
-- This table stores hierarchical user reports submitted via PostgREST.
--
-- Run with: supabase db push
-- Or manually in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS reports (
    id          BIGSERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    page        TEXT NOT NULL,
    category    TEXT NOT NULL,
    sub_category TEXT,
    detail      TEXT,
    user_notes  TEXT,
    product_name TEXT,
    product_company TEXT,
    product_id  TEXT,
    reported_category TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for lookup by user
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports (user_id);

-- Index for admin queries by category
CREATE INDEX IF NOT EXISTS idx_reports_category ON reports (category, created_at DESC);

-- Enable Row Level Security
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (controlled by anon key — anyone with the public anon key can submit)
-- This is intentional: feedback should be low-friction.
CREATE POLICY "Allow anonymous insert" ON reports
    FOR INSERT
    WITH CHECK (true);

-- Block anonymous reads — reports contain user feedback and should only be readable by admins
CREATE POLICY "Service role read only" ON reports
    FOR SELECT
    USING (false);

-- Block anonymous updates and deletes
CREATE POLICY "No anonymous update" ON reports
    FOR UPDATE
    USING (false);

CREATE POLICY "No anonymous delete" ON reports
    FOR DELETE
    USING (false);

-- Add length constraints via CHECK to prevent abuse
ALTER TABLE reports
    ADD CONSTRAINT check_user_notes_length CHECK (char_length(user_notes) <= 2000),
    ADD CONSTRAINT check_product_name_length CHECK (char_length(product_name) <= 500),
    ADD CONSTRAINT check_product_company_length CHECK (char_length(product_company) <= 500),
    ADD CONSTRAINT check_product_id_length CHECK (char_length(product_id) <= 100),
    ADD CONSTRAINT check_category_length CHECK (char_length(category) <= 100),
    ADD CONSTRAINT check_page_length CHECK (char_length(page) <= 100);

COMMENT ON TABLE reports IS 'User-submitted reports and feedback. Anon insert allowed, read restricted to service role.';
