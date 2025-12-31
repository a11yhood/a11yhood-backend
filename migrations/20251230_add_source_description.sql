-- Add description column to supported_sources table for storing markdown descriptions
-- This enables sources to provide detailed information about their platform and accessibility features

-- Add description column (nullable to allow existing records to work)
ALTER TABLE supported_sources ADD COLUMN IF NOT EXISTS description TEXT;

-- Add some example descriptions for existing sources
UPDATE supported_sources SET description = '# Ravelry

Ravelry is a free social networking site for people who knit, crochet, spin, and weave. The site provides tools for organizing projects, patterns, and yarn stashes, as well as forums and groups for community discussion.

## Accessibility Features
- Screen reader compatibility with ARIA labels
- Keyboard navigation support
- Alternative text for images of crafts and patterns' WHERE domain = 'ravelry.com';

UPDATE supported_sources SET description = '# GitHub

GitHub is a platform for version control and collaboration using Git. It allows developers to host and review code, manage projects, and build software together.

## Accessibility Features
- Built-in accessibility auditing tools
- Keyboard shortcuts for navigation
- High contrast themes available
- Screen reader optimized interface' WHERE domain = 'github.com';

UPDATE supported_sources SET description = '# Thingiverse

Thingiverse is a website dedicated to the sharing of user-created digital design files. It is widely used by makers, 3D printing enthusiasts, and the DIY community.

## Accessibility Features
- Search and filter options for finding accessible designs
- Community tags for accessibility-related modifications
- Support for adaptive and assistive technology designs' WHERE domain = 'thingiverse.com';
