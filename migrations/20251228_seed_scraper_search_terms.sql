-- Migration: Seed normalized scraper_search_terms
-- Date: 2025-12-28
-- Description: Insert default search terms for github, Thingiverse, and Ravelry (PA categories)

-- github search terms
insert into public.scraper_search_terms (platform, search_term) values
  ('github', 'assistive technology'),
  ('github', 'screen reader'),
  ('github', 'eye tracking'),
  ('github', 'speech recognition'),
  ('github', 'switch access'),
  ('github', 'alternative input'),
  ('github', 'text-to-speech'),
  ('github', 'voice control'),
  ('github', 'accessibility aid'),
  ('github', 'mobility aid software')
on conflict (platform, search_term) do nothing;

insert into public.scraper_search_terms (platform, search_term) values
  ('ravelry', 'medical-device-access'),
  ('ravelry', 'medical-device-accessory'),
  ('ravelry', 'mobility-aid-accessor'),
  ('ravelry', 'other-accessibility'),
  ('ravelry', 'therapy-aid')
on conflict (platform, search_term) do nothing;

-- thingiverse search terms
insert into public.scraper_search_terms (platform, search_term) values
  ('thingiverse', 'accessibility'),
  ('thingiverse', 'assistive device'),
  ('thingiverse', 'arthritis grip'),
  ('thingiverse', 'adaptive tool'),
  ('thingiverse', 'mobility aid'),
  ('thingiverse', 'tremor stabilizer'),
  ('thingiverse', 'adaptive utensil')
on conflict (platform, search_term) do nothing;
