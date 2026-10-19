# Kamcheh

Two separate frontends share one Supabase backend: desktop website in `site/`, Flutter app in `lib/cloud/`.

Current architecture and activation status: [docs/SHARED_BACKEND.md](docs/SHARED_BACKEND.md).
Historical demo instructions: [docs/DEMO_HISTORY.md](docs/DEMO_HISTORY.md).

Generate public frontend configuration:

```sh
node scripts/configure-backend.cjs
flutter build web --dart-define-from-file=config/public_backend.json --base-href /kamcheh/app/ --no-web-resources-cdn
```

The Kamcheh database exists with RLS enabled. SMS setup, final verification and updated deployment remain pending. Production does not silently substitute sample accounts or local-only data.
