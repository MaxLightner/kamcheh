# Website and app data boundary

Website and Flutter app have independent interfaces but use the same Supabase project, Auth identities, database and Storage. Public configuration comes from config/public_backend.json.

Production has no automatic demo-data fallback. Private actions require authentication, and database RLS enforces ownership or participation. Contact decisions and shared contract state transitions use authorized RPCs.

Only anonymous public directory/listing data is cached for read-only offline use. Private identity documents, conversations, contracts and accounting are excluded from this cache.

See SHARED_BACKEND.md for current deployment limits.
