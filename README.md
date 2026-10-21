# Kamcheh

Two separate frontends share one Supabase backend: desktop website in `site/`, Flutter app in `lib/cloud/`.

Current architecture and activation status: [docs/SHARED_BACKEND.md](docs/SHARED_BACKEND.md).
Historical demo instructions: [docs/DEMO_HISTORY.md](docs/DEMO_HISTORY.md).

Generate public frontend configuration:

```sh
node scripts/configure-backend.cjs
flutter build web --dart-define-from-file=config/public_backend.json --base-href /kamcheh/app/ --no-web-resources-cdn
```

The Kamcheh database exists with RLS enabled. This public build is still a **preview**: the Flutter app opens the former fully interactive local demo by default, with sample accounts and saved device data. Use the top **حالت آنلاین** switch (or append `?live=1` to the app URL) to test the shared Supabase backend; the two modes have separate data and never silently mix records. SMS login and cross-device end-to-end verification remain pending. When ready for a live-first release, build with `--dart-define=KAMCHEH_PREVIEW=false`.
