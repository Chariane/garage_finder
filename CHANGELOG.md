# Changelog

All notable project milestones are documented here.

## [1.4.0] - 2026-10-07

- Added garage editing, weekly opening hours, and explicit live availability states.
- Added customer roadside-service requests with optional location sharing and owner response/ETA workflow.
- Added customer reviews, garage reports with an admin moderation queue, and realtime in-app notifications.
- Added a garage approval queue with mandatory rejection feedback and automatic resubmission after substantive owner edits.
- Added customer cancellation for pending requests and server-side expiry with in-app status notifications after 30 minutes without a response.
- Added RLS policies, request state-transition guards, request rate limiting, and notification triggers.

## [1.3.0] - 2026-10-07

- Added Supabase email authentication, customer/garage-owner account roles, and owner dashboard.
- Added a PostGIS migration with row-level security, moderation states, storage policies, and filtered nearby search.
- Added garage address geocoding, GPS/manual coordinate entry, radius search, and owner photo upload.
- Added a SQLite schema upgrade for moderation and distance metadata; remote public listings are cached locally.
- Added French/English account and location flows plus mapping and proximity tests.

## [1.2.0] - 2026-10-06

- Added a SQLite database and repository layer for garages and favorites.
- Connected home, search, detail, favorites and registration views to shared application state.
- Added French and English localization, SOS filtering and configurable sorting.
- Added unit, widget and integration test suites plus Android CI and demo APK artifact.
- Documented setup, architecture and release checks.

## [1.1.0] - 2026-10-05

- Added reusable garage filtering and sorting logic.
- Improved garage model mapping and image decoding for list thumbnails.
- Added theme and locale state management.

## [1.0.0] - 2026-10-04

- Initial Garage Finder application with garage listing, details and registration form.
- Added GoRouter navigation, shared visual components and dark theme.
