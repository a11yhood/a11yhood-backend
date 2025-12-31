-- Add GOAT (Gets Organized About Things) to supported sources
-- GOAT uses LibraryThing's Web Services API to fetch book metadata and accessibility information

INSERT INTO supported_sources (domain, name, created_at, updated_at)
VALUES (
    'librarything.com',
    'GOAT',
    NOW(),
    NOW()
)
ON CONFLICT (domain) DO UPDATE SET
    name = 'GOAT',
    updated_at = NOW();
