# Shared backend — current status

Organization: توموتو (`yfzznucofinhtauicawi`).
Kamcheh project: `iaopdcnnblrrxqkrosrd`, Frankfurt, created 2026-10-19.
The unrelated Menosaz project was not modified.

## Architecture
The desktop website (`site/`) and Flutter frontend (`lib/cloud/`) use one Supabase Auth, PostgreSQL database and Storage. Public configuration is generated from `config/public_backend.json` by `node scripts/configure-backend.cjs`; Flutter uses `--dart-define-from-file=config/public_backend.json`. Only a publishable key is included. Server secrets must never be committed.

The published PREVIEW intentionally opens the existing local demo first, preserving sample accounts, listings, requests, bids, chat, contracts and accounting. The top switch opens real Supabase mode. Demo data remain on this device and never migrate to the shared database; real mode never substitutes demo content on empty or failed queries. For a production-first build use `--dart-define=KAMCHEH_PREVIEW=false`. Offline caching is read-only public directory/listing data; private messages, identity attachments, contracts and accounting are not cached by this layer.

## Applied remotely
Migration `kamcheh_shared_backend` created 15 public tables with RLS, authenticated state-transition RPCs and private attachment buckets. The security advisor returned no findings immediately after applying the schema. Contracts preserve signed revisions; coordination is distinct from starting/finishing work.

## Remaining activation work
- Configure an appropriate phone/SMS provider; real OTP login is not yet verified.
- Build and publish updated frontends. Existing GitHub Pages deployment has not been updated by this change.
- Run end-to-end verification with two actual accounts after SMS configuration.
- Complete production parity for crew links, galleries, ratings and profile-view statistics; the historical demo has features not yet migrated to server-backed screens.
- Fresh user authorization received: all 53 Flutter tests, 27 PostgreSQL policy checks and website UI-model checks passed. GitHub Actions build and deploy run 39306026220 succeeded. SMS-dependent two-user end-to-end behavior remains unverified.

27 in-memory PostgreSQL policy checks passed during implementation before the test deferral rejection. They do not prove real Auth/SMS/Storage HTTP behavior. The updated bid-transition migration parses and applies in the policy suite.

## Other products
AR, طوطیوار and ویتاورس are requested independent projects, not tables within Kamcheh. Creation of AR was refused because the account already has two active Free projects. No paid upgrade was performed; the other two projects were not created. Obtain an explicit paid cost decision before proceeding.
