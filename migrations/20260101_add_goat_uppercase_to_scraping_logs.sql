-- Allow uppercase 'GOAT' in scraping_logs source check constraint

ALTER TABLE scraping_logs 
DROP CONSTRAINT IF EXISTS scraping_logs_source_check;

ALTER TABLE scraping_logs 
ADD CONSTRAINT scraping_logs_source_check 
CHECK (source IN ('thingiverse', 'Thingiverse', 'ravelry', 'Ravelry', 'github', 'GitHub', 'abledata', 'AbleData', 'goat', 'GOAT'));
