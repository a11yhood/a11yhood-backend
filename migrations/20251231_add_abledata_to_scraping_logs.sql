-- Add 'AbleData' to scraping_logs source check constraint

-- Drop the old constraint
ALTER TABLE scraping_logs 
DROP CONSTRAINT IF EXISTS scraping_logs_source_check;

-- Add new constraint including AbleData
ALTER TABLE scraping_logs 
ADD CONSTRAINT scraping_logs_source_check 
CHECK (source IN ('thingiverse', 'ravelry', 'github', 'abledata', 'goat'));
