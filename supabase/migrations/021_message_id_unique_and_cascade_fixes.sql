-- ============================================================
-- 021_message_id_unique_and_cascade_fixes.sql
--
-- 1. Unique constraint on messages.message_id
--    Prevents duplicate inserts when Meta retries webhooks.
--    ON CONFLICT DO NOTHING in the webhook handler relies on this.
--
-- 2. ON DELETE SET NULL on deals.stage_id
--    Allows deleting a pipeline stage even when deals reference it.
--    Without this, any attempt to delete a stage with existing deals
--    raises a FK constraint violation.
--
-- 3. Fix message_templates unique index to use account_id
--    Post-migration 017 templates are account-scoped. The old
--    (user_id, name, language) index allowed teammates to create
--    duplicate templates; replacing it with (account_id, name, language)
--    enforces correctness at the DB level.
--
-- Idempotent — safe to run multiple times.
-- ============================================================

-- ── 1. messages.message_id unique ────────────────────────────────────

-- Drop the old non-unique index first (idempotent).
DROP INDEX IF EXISTS idx_messages_message_id;

-- Add unique constraint. Scoped to conversation_id so two different
-- accounts receiving the same Meta message_id (unlikely but possible
-- in tests) don't collide. Within a conversation, a message_id must
-- be unique — Meta guarantees this; we enforce it so retries are safe.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'messages_message_id_conversation_unique'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT messages_message_id_conversation_unique
      UNIQUE (message_id, conversation_id);
  END IF;
END $$;

-- Keep a plain index on message_id alone for fast webhook status
-- lookups (handleStatusUpdate queries by message_id without knowing
-- conversation_id).
CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id);

-- ── 2. deals.stage_id ON DELETE SET NULL ─────────────────────────────

-- Drop and recreate the FK with the correct ON DELETE action.
-- The original migration 001 omitted ON DELETE, defaulting to RESTRICT.
ALTER TABLE deals DROP CONSTRAINT IF EXISTS deals_stage_id_fkey;
ALTER TABLE deals
  ADD CONSTRAINT deals_stage_id_fkey
  FOREIGN KEY (stage_id) REFERENCES pipeline_stages(id)
  ON DELETE SET NULL;

-- ── 3. message_templates unique index → account_id ───────────────────

-- Drop the old (user_id, name, language) unique index.
DROP INDEX IF EXISTS message_templates_user_id_name_language_key;
-- Some installations may have it named differently:
DROP INDEX IF EXISTS idx_message_templates_user_name_lang;

-- Create the correct account-scoped unique index.
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_templates_account_name_lang
  ON message_templates (account_id, name, language);
