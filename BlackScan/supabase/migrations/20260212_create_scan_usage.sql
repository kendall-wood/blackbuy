-- Migration: Create scan_usage table for server-side rate limiting
-- This table tracks per-user daily scan counts to prevent API abuse.
--
-- Run with: supabase db push
-- Or manually in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS scan_usage (
    user_id TEXT NOT NULL,
    date    DATE NOT NULL DEFAULT CURRENT_DATE,
    scan_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (user_id, date)
);

-- Index for fast lookups by user + date
CREATE INDEX IF NOT EXISTS idx_scan_usage_user_date 
    ON scan_usage (user_id, date);

-- Auto-cleanup: delete rows older than 30 days (run via pg_cron or scheduled function)
-- This keeps the table small and respects data minimization principles.
COMMENT ON TABLE scan_usage IS 'Server-side rate limiting for AI scan requests. Rows auto-expire after 30 days.';

-- Row Level Security: only the service role can read/write (edge function uses service role key)
ALTER TABLE scan_usage ENABLE ROW LEVEL SECURITY;

-- No public access — only the edge function (via service_role) can access this table
CREATE POLICY "Service role only" ON scan_usage
    FOR ALL
    USING (false)
    WITH CHECK (false);
