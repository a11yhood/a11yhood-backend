-- Standardize all timestamps to TIMESTAMPTZ format
-- Converts user_activities.timestamp from BIGINT (milliseconds) to TIMESTAMPTZ

-- Convert user_activities.timestamp from BIGINT to TIMESTAMPTZ
-- The BIGINT stores milliseconds since epoch, so divide by 1000 to get seconds
ALTER TABLE user_activities 
  ALTER COLUMN timestamp TYPE TIMESTAMPTZ 
  USING to_timestamp(timestamp / 1000.0);

-- Add comment explaining the standardization
COMMENT ON COLUMN user_activities.timestamp IS 'User activity timestamp in UTC (standardized to TIMESTAMPTZ from BIGINT)';
