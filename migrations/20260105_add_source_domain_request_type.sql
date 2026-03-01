-- Add 'source-domain' type to user_requests.type CHECK constraint
-- 2026-01-05: Enable source-domain requests for user-submitted product sources

-- Drop the existing constraint and recreate it with the new value
ALTER TABLE user_requests
DROP CONSTRAINT IF EXISTS user_requests_type_check;

ALTER TABLE user_requests
ADD CONSTRAINT user_requests_type_check
CHECK (type IN ('moderator', 'admin', 'product-ownership', 'source-domain'));
