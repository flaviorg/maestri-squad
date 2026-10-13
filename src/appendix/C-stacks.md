## Appendix C: Stacks

Use the section that matches the Q1 area and the Q2 stack; when Q2 is "Other", use the Generic section of the area.
In Phase 2, pre-fill `PROJECT_PROFILE.md` from it, then override every value with what the repo shows (file:line
evidence); a value the repo neither confirms nor contradicts stays, marked "assumed" in the Phase 4 summary. In
Phase 3 the fields feed the kit:

- **Gates** → `{{GATES}}`; **E2E** → `{{E2E_TOOL}}` and `{{E2E_RUN}}`; **Generated directories** →
  `{{GENERATED_DIRS}}`; **Fresh setup** → `{{FRESH_SETUP}}` and `RUNBOOK.md`; **Conventions worth a rule** →
  `{{STACK_RULES}}` (`RULES.md` §Stack): this list adapted to the repo, plus the repo's own documented conventions.
- **Dev server and ports**: the default `PORT_BASE` goes to `kit.env`; every floor uses `PORT_BASE+SLOT`, and every
  other port it publishes is its base + SLOT (RULES §Floor).
- **Risk triggers**: a ticket that touches one is never XS and weighs toward a larger size; for auth, secrets,
  payments or data exposure, the Maestro also calls Aegis.

The fresh setup runs at floor creation, before INTAKE (Appendix E). Probe owns the dev server, the device and E2E on
its floor; E2E evidence is the tool's machine-readable report plus artifacts, referenced from the TRACE; a
persisted-data change needs the upgrade-in-place gate (RULES §E2E).

### Expo / React Native

#### Status

battle-tested

Run end to end by a real squad on a production app.

#### Detection hints

- `expo` or `react-native` in `package.json` dependencies; `app.json` or `app.config.(js|ts)` with an `expo` key;
  `eas.json`; `metro.config.js`.
- `ios/` and `android/` listed in `.gitignore` (or absent) means CNG / prebuild. Committed, hand-maintained native
  folders with no prebuild script mean a bare React Native app: keep this section but drop the CNG rules.

#### Gates

- Lint and format check: the repo's scripts (`<pm> lint`, `<pm> format` or `prettier --check .`).
- Typecheck: `npx tsc --noEmit`. It is often not in CI; run it anyway.
- Unit tests: `<pm> test` (Jest). Use the CI's Node version from `.nvmrc`: native addons on a newer Node can abort
  at Jest teardown and look like a test failure.
- Dead-code check (`knip` or similar) when the repo has one.
- Build: usually no separate gate (Probe's dev-client build at ENV and E2E covers it); write `none` unless CI builds.

#### E2E

- Maestro (maestro.dev) flows, committed in the repo's flow folder, run on THIS floor's simulator or emulator:
  `maestro --device <id> test --format junit --output <evidence dir>/report.xml --test-output-dir <evidence dir>/artifacts <flows>`.
  The evidence dir is `$KIT/floor-snapshots/{{KEY}}/e2e/`, outside the repo: Metro watches the repo, and a write there
  reloads the app mid-flow.
- Writing flows: one flow per user-facing AC (or bug), in one subfolder per feature with shared steps in `helpers/`
  and a `config.yaml` for the folder (flow order, tags). Select by stable `testID` (`id:`), never by copy that i18n
  changes. Pass variables with `-e NAME=value` on the command line, at the top level: env declared inside a parent
  flow can be lost in its subflows, so hand it on explicitly through `runFlow`'s `env:`. Add
  `takeScreenshot: <AC-n-step>` at every checkpoint (the files land in `--test-output-dir`).
- Before writing a flow, read the live screen: launch the app in the floor portal
  (`maestri portal launch "Sim-{{KEY}}" <app id>`) and read its accessibility tree (`maestri portal snapshot "Sim-{{KEY}}"`),
  or use Maestro's own inspector or its MCP server (list devices → inspect screen → run inline YAML).
- iOS dev client: open it with an explicit deep link,
  `<scheme>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A<port>`.
- Android: the emulator reaches the host at `10.0.2.2`; run `adb -s <id> reverse tcp:<port> tcp:<port>` when the app
  uses `localhost`. Do not send the dev-client deep link to an app with retained state: expo-dev-launcher can crash at
  boot ("App react context shouldn't be created before"). Enter with `launchApp` plus a wait (the dev launcher reopens
  the last server), or clear the app state first.
- Never run Metro with `CI=1`: it disables Bonjour discovery, the dev-launcher server list stays empty, and flows that
  rely on discovery fail before any app assertion.
- Flows may share simulator state in order: keep a frozen flow order. Evidence = JUnit plus screenshots; compare
  post-change failures against a recorded baseline round (same flows, same order, same device).

#### Dev server and ports

- Metro on PORT_BASE+SLOT, default PORT_BASE 8081: `npx expo start --dev-client --port <PORT_BASE+SLOT>`, in a
  persistent shell terminal (agent background jobs may be capped or killed); only the Maestro or Probe restarts it.
- Several environments (an `APP_ENV`-style variable read by `app.config.*`, per-env schemes and app ids): Phase 2
  asks which one floors use, never guesses. Metro, the native build and the E2E app id then all use it, e.g.
  `APP_ENV=<env> npx expo start --dev-client --port <PORT_BASE+SLOT>`.
- One simulator or emulator per floor (`maestri portal devices`); never share a device across floors.

#### Generated directories

- `ios/` and `android/` (generated by `npx expo prebuild`), `node_modules/`, `.expo/`.
- Codegen outputs the repo's scripts produce (GraphQL types, database schema, assets); read `package.json` scripts.

#### Fresh setup

1. Remove `node_modules/`; (CNG only) also remove `ios/` and `android/`.
2. Install with the repo's package manager and an immutable lockfile (`yarn install --immutable` on Yarn 2+,
   `yarn install --frozen-lockfile` on Yarn 1, `npm ci`, `pnpm install --frozen-lockfile`); `postinstall` applies the
   patch-package patches.
   When CI installs differently (a checksum or lockfile override), use CI's command, then require
   `git status --porcelain <lockfile>` to print nothing.
3. If a `Gemfile` exists: Ruby pinned per `.ruby-version`, then `bundle install`. For Android builds, the JDK pinned per
   `.java-version` (or the Gradle toolchain).
4. (CNG only) `npx expo prebuild --clean` (or the repo's prebuild script), with any E2E build flag the repo uses (for
   example an env var that enables test-only hooks); verify the generated `Info.plist` / `AndroidManifest.xml` carry
   it, and run `pod install` in `ios/` when prebuild did not.

Bare React Native (committed native folders): keep `ios/` and `android/` (they are tracked code, never deleted or
regenerated); run steps 2 and 3, then `cd ios && bundle exec pod install` (plain `pod install` without a `Gemfile`).

#### Risk triggers

- Native module or Expo SDK bumps; config plugins; patched packages; persisted storage, local database, migrations.
- Auth and session; deep links; background tasks and push; navigation library majors (behavior changes such as tab
  pop-to-root).

#### Conventions worth a rule

- Never hand-edit `ios/` or `android/`: native changes go through the app config and config plugins, then
  `npx expo prebuild --clean` regenerates them.
- Libraries in `node_modules/` change only through patch-package patches in `patches/` (applied by `postinstall`);
  re-base the patch on every bump of a patched package.
- Metro runs on PORT_BASE+SLOT in a persistent terminal, never with `CI=1`; only the Maestro or Probe restarts it.
- One simulator or emulator per floor; E2E flows keep a frozen order and are compared against a baseline round.
- Maestro flows select by stable `testID`, one flow per user-facing AC, a screenshot at each checkpoint; the evidence
  stays in `$KIT/floor-snapshots/{{KEY}}/e2e/`, outside the repo.
- Run `npx tsc --noEmit` and the unit tests on the CI's Node version (`.nvmrc`), even when CI skips the typecheck.

### Flutter

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- `pubspec.yaml` with a `flutter:` section or `sdk: flutter` dependency; `lib/main.dart`; `.metadata`.
- Version pins: `.fvmrc` / `.fvm/` (FVM) or the `environment:` block of `pubspec.yaml`.

#### Gates

- Format check: `dart format --output=none --set-exit-if-changed .`
- Analyze: `flutter analyze` (lints from `analysis_options.yaml`).
- Unit and widget tests: `flutter test`.
- Codegen in sync, when `build_runner` is a dev dependency:
  `dart run build_runner build --delete-conflicting-outputs`, then `git diff --exit-code`.

#### E2E

- Maestro (maestro.dev) flows against a debug build on THIS floor's device:
  `maestro --device <id> test --format junit --output <evidence dir>/report.xml --test-output-dir <evidence dir>/artifacts <flows>`; or
- `integration_test`: `flutter test integration_test -d <id> --file-reporter json:<evidence dir>/report.json`.
  Under `flutter test`, `binding.takeScreenshot` writes no image file: the bytes only land in `binding.reportData`.
  For screenshot files, run `flutter drive --driver=test_driver/integration_test.dart
  --target=integration_test/<file>.dart -d <id>` with a driver whose `integrationDriver(onScreenshot: ...)` handler
  writes each image to the evidence dir; on Android call `binding.convertFlutterSurfaceToImage()` before the first
  screenshot.
- Evidence = the report plus screenshots; without the `flutter drive` setup, screenshots come from Maestro's
  `takeScreenshot`.

#### Dev server and ports

- Device builds have no dev-server port: the floor is isolated by its own simulator or emulator, chosen with
  `flutter devices` and passed as `-d <id>`.
- Flutter web: `flutter run -d web-server --web-port <PORT_BASE+SLOT>`, default PORT_BASE 8100.

#### Generated directories

- `build/`, `.dart_tool/`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `ios/Pods/`.
- `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `lib/generated/` (intl), `GeneratedPluginRegistrant.*`.
- `ios/` and `android/` are hand-maintained in Flutter (not generated), except the plugin registrants.

#### Fresh setup

1. Use the pinned Flutter version (`fvm use` when `.fvmrc` exists).
2. Remove `build/` and `.dart_tool/`; `flutter pub get` (respects `pubspec.lock`).
3. `dart run build_runner build --delete-conflicting-outputs` when the repo uses codegen.
4. `cd ios && pod install` for iOS builds.

#### Risk triggers

- Flutter or Dart SDK bumps; plugins with native code; platform channels.
- Edits under `ios/` or `android/` (Info.plist, Gradle, entitlements, manifests).
- Local storage or database schema changes (drift, sqflite, hive) and their migrations.
- Auth and session; deep links and app links; background work and push notifications.

#### Conventions worth a rule

- Never hand-edit generated Dart files (`*.g.dart`, `*.freezed.dart`); change the source and re-run `build_runner`.
- Run every Flutter command through the pinned version (FVM when present).
- One simulator or emulator per floor, passed explicitly with `-d <id>`.

### React / Next.js

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- `next` in `package.json` dependencies; `next.config.(js|mjs|ts)`; `app/` or `pages/` directory.
- Plain React: `react` plus `vite` (`vite.config.*`) or `react-scripts` in `package.json`.

#### Gates

- Lint: the repo's lint script (`<pm> lint`), else `npx eslint .` (Next.js 16 removed `next lint`). Format check:
  `prettier --check .` when the repo has a Prettier config or a format script, otherwise `none`.
- Typecheck: the repo's script, else `npx tsc --noEmit`.
- Unit tests: `<pm> test` (Jest or Vitest).
- Build: `<pm> build` (`next build` catches server/client boundary and prerender errors the other gates miss).
- A gate the repo defines (a script or a config) but CI skips stays a gate, marked `(not in CI)` in Phase 4; a gate
  the repo does not define is `none`. Run every gate on the Node the repo pins (Fresh setup step 1).

#### E2E

- Playwright, with `baseURL` and the `webServer` port set to this floor's port (`PORT=<PORT_BASE+SLOT>`), every
  output in the evidence dir `$KIT/floor-snapshots/{{KEY}}/e2e/` (by default Playwright writes `test-results/` and
  `playwright-report/` inside the repo, where the dev server watches):
  `PLAYWRIGHT_JUNIT_OUTPUT_FILE=<evidence dir>/report.xml PLAYWRIGHT_HTML_OUTPUT_DIR=<evidence dir>/html PLAYWRIGHT_HTML_OPEN=never <pm> exec playwright test --reporter=junit,html --output <evidence dir>/artifacts`.
  These env var names are a recent Playwright's; older versions name the HTML folder `PLAYWRIGHT_HTML_REPORT`. Check
  the installed version (`<pm> exec playwright --version`, `<pm> exec playwright test --help`) in Phase 2.
- Evidence = the JUnit and HTML reports plus screenshots and traces (`trace: 'retain-on-failure'`), referenced from
  the TRACE. Cover every viewport the plan names.

#### Dev server and ports

- The repo's dev script with the port passed through: `npm run dev -- -p <PORT_BASE+SLOT>` (yarn and pnpm:
  `<pm> dev -p <PORT_BASE+SLOT>`), else `npx next dev -p <PORT_BASE+SLOT>`, default PORT_BASE 3000. Vite: `npx vite --port <PORT_BASE+SLOT> --strictPort`.
- Probe opens a browser portal on the floor port only.

#### Generated directories

- `.next/`, `out/`, `dist/`, `node_modules/`, `next-env.d.ts`, `playwright-report/`, `test-results/`.
- Codegen outputs (GraphQL, OpenAPI clients, CMS types); read `package.json` scripts.

#### Fresh setup

1. Use the Node the repo pins: `.nvmrc`, `.node-version` or `engines.node` in `package.json` (through nvm, fnm, volta
   or the version manager the machine has).
2. Remove `node_modules/` and `.next/`.
3. Install with an immutable lockfile (`npm ci`, `yarn install --immutable` on Yarn 2+ or `--frozen-lockfile` on
   Yarn 1, `pnpm install --frozen-lockfile`).
4. `.env.local` from `.env.example` with the floor's port and local or test values only; secrets by file reference.
5. `<pm> exec playwright install` for the browsers the config uses.

#### Risk triggers

- Next.js or React majors; a router change (pages to app).
- Middleware, route handlers and server actions that touch auth, cookies or sessions.
- Caching and revalidation; env vars exposed to the client (`NEXT_PUBLIC_*`); headers and CSP.
- Payments, analytics consent, SEO-critical pages.

#### Conventions worth a rule

- Never put a secret in a `NEXT_PUBLIC_*` variable or in client code.
- Mark client components explicitly (`'use client'`); keep data fetching on the server unless the plan says otherwise.
- Run `next build` before review: it is a gate.

### Node (Nest / Express)

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- `@nestjs/core` (plus `nest-cli.json`) or `express` (also `fastify`, `koa`) in `package.json` dependencies.
- `docker-compose.yml` / `compose.yaml` for the dependencies; `prisma/`, `typeorm` or `knex` for the database.

#### Gates

- Lint: `<pm> lint`. Format check: `prettier --check .`
- Typecheck or build: `npx tsc --noEmit` (Nest: `<pm> build`).
- Unit tests: `<pm> test` (Jest).
- Contract tests: `<pm> test:e2e` (Nest) or the repo's equivalent.

#### E2E

- supertest contract tests with docker-compose deps: the app is booted in the test process and every endpoint the
  ticket touches gets a request/response scenario (status, body shape, error cases, auth).
- Dependencies: `docker compose -p "$FLOOR_PROJECT" up -d` (RULES §Floor), each published host port at its base + SLOT:
  through the compose file's port variables when it has them (`"${DB_PORT:-5432}:5432"`), else a kit-side override
  file `$KIT/compose.floor.yaml` whose ports read the floor's env file (`ports: !override` then
  `- "${DB_PORT}:5432"`; run `docker compose --env-file <floor env file> -f <compose file> -f $KIT/compose.floor.yaml`,
  Docker Compose 2.24.4 or later); never edit the repo's compose file for it. Or testcontainers.
- Evidence = a JUnit report (`jest-junit`) plus the captured responses, referenced from the TRACE.

#### Dev server and ports

- `PORT=<PORT_BASE+SLOT> <pm> run start:dev` (Nest) or `PORT=<PORT_BASE+SLOT> <pm> run dev`, default PORT_BASE 3000.
- The compose project name carries the KEY so two floors never share a database; every published port is offset.

#### Generated directories

- `dist/`, `node_modules/`, `coverage/`.
- Prisma client (`node_modules/.prisma/`), generated GraphQL schema or types, OpenAPI clients.

#### Fresh setup

1. Use the Node the repo pins (`.nvmrc`, `.node-version` or `engines.node`); remove `node_modules/` and `dist/`;
   install with an immutable lockfile.
2. `.env` from `.env.example` with the floor's ports and local values only (never the ground's database); secrets by
   file reference.
3. `docker compose -p "$FLOOR_PROJECT" up -d` (RULES §Floor), then the migrations and seed scripts.
4. Codegen (`npx prisma generate` or the repo's script).

#### Risk triggers

- Auth and authorization (guards, middleware, tokens); input validation and serialization.
- Database migrations; queue and consumer semantics; scheduled jobs.
- Public API contract changes; framework or ORM majors; rate limits and config.

#### Conventions worth a rule

- Every endpoint change ships with a contract test for its success and error responses.
- A migration is never edited after it ran on a shared environment; add a new one.
- Each floor runs its own compose project; no floor touches another floor's database.

### Python (FastAPI / Django)

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- `pyproject.toml` or `requirements*.txt` listing `fastapi` or `django`; `manage.py` (Django).
- Tooling: `uv.lock`, `poetry.lock`, `Pipfile.lock`; `.python-version`.

#### Gates

- Run every gate through the project runner (`uv run`, `poetry run`) with CI's exact arguments and targets; a bare
  `ruff` or `pytest` may pick another environment than the floor's `.venv`.
- Lint and format check: `ruff check` and `ruff format --check` (or `black --check`), on CI's paths.
- Typecheck: `mypy` or `pyright` when configured, on CI's target package.
- Tests: `pytest`.
- Django: `python manage.py check` and `python manage.py makemigrations --check --dry-run`.
- Alembic: `alembic upgrade head`, then `alembic check` (no model change without its migration), against the floor's
  database.

#### E2E

- pytest with httpx (FastAPI `TestClient` / `httpx.AsyncClient`) or the Django test client (pytest-django), hitting
  every endpoint the ticket touches against a real test database (the floor's).
- DB-backed tests are told apart from unit tests the way the repo does it: a folder (`tests/e2e/`,
  `tests/integration/`) or a marker (`-m e2e`, `-m integration`); Phase 2 detects which, or asks. A fixture writes
  each captured response to the evidence dir.
- Upgrade in place (RULES §E2E): unpack the base outside the repo
  (`git archive origin/<base> | tar -x -C <scratch dir>`), migrate the floor's database to its head and seed it, then
  run the branch's migrations on that data and the tests.
- Dependencies: `docker compose -p "$FLOOR_PROJECT" up -d` (RULES §Floor), each published host port at its base + SLOT:
  through the compose file's port variables when it has them, else the kit-side override file `$KIT/compose.floor.yaml`
  (Node section); never edit the repo's compose file for it. Or testcontainers.
- Evidence = `pytest --junitxml=<evidence dir>/report.xml` plus the captured responses.

#### Dev server and ports

- FastAPI: `<runner> uvicorn <module>:app --reload --port <PORT_BASE+SLOT>` (`uv run`, `poetry run`), default
  PORT_BASE 8000.
- Django: `<runner> python manage.py runserver 127.0.0.1:<PORT_BASE+SLOT>`.

#### Generated directories

- `.venv/`, `__pycache__/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `staticfiles/`.
- Django migrations are generated by `makemigrations` but committed and reviewed: never edit an applied one.

#### Fresh setup

1. Python pinned per `.python-version` (with uv, `uv python install` provisions it); a fresh `.venv` per floor.
2. Install from the lockfile without rewriting it: `uv sync --locked`, `poetry sync` (Poetry 2;
   `poetry install --sync` on 1.x), or `pip install -r requirements.txt`. When CI installs differently, use CI's
   command, then require `git status --porcelain <lockfile>` to print nothing.
3. The floor's `.env` overrides every connection URL and port with the floor's values: settings that default to
   `localhost:<ground port>` would silently use the ground's data. Start from the example file; without one, derive
   the keys from the settings class and ask. Secrets by file reference.
4. Dependencies up, then migrations (`alembic upgrade head` or `python manage.py migrate`).

#### Risk triggers

- Migrations; ORM query changes (N+1, raw SQL); transactions.
- Auth, permissions and sessions; settings and middleware.
- Schema and serialization changes (Pydantic, DRF serializers); async/sync boundaries; background tasks (Celery).

#### Conventions worth a rule

- Every model change ships with its migration, and the migration check is a gate (Django `makemigrations --check`,
  Alembic `alembic check` on the floor's database).
- Every endpoint change ships with a test for its success and error responses.
- Never commit `.venv/`; dependency changes go through the lockfile.

### Go

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- `go.mod` at the root; `cmd/` and `internal/`; `.golangci.yml`.
- `Makefile` targets for lint, test and generate.

#### Gates

- Format: `gofmt -l .` prints nothing. Vet: `go vet ./...`.
- Lint: `golangci-lint run` when configured.
- Tests: `go test -race ./...`. Build: `go build ./...`.
- Modules tidy: `go mod tidy`, then `git diff --exit-code go.mod go.sum`.

#### E2E

- `go test` with httptest and testcontainers: `net/http/httptest` servers for the handlers the ticket touches,
  testcontainers-go for the real dependencies.
- Evidence = `go test -json` output (or `gotestsum --junitfile <evidence dir>/report.xml`) plus captured responses.

#### Dev server and ports

- `PORT=<PORT_BASE+SLOT> go run ./cmd/<service>` (or the flag the service reads), default PORT_BASE 8080.

#### Generated directories

- Files headed `// Code generated ... DO NOT EDIT.` (`*.pb.go`, `*_gen.go`, mocks); `vendor/` when vendored; `bin/`.

#### Fresh setup

1. Go version from `go.mod` (`toolchain` line when present); `go mod download`.
2. `go generate ./...` when the repo relies on it.
3. Dependencies up: `docker compose -p "$FLOOR_PROJECT" up -d` (RULES §Floor), each published host port at its
   base + SLOT (the compose file's port variables, or `$KIT/compose.floor.yaml` as in the Node section;
   never edit the repo's compose file for it); the floor's env points at those ports; then migrations.

#### Risk triggers

- Concurrency (goroutines, channels, locks); context cancellation and timeouts.
- Database migrations; public API or protobuf changes (wire compatibility).
- Auth; Go version or module major bumps.

#### Conventions worth a rule

- Never hand-edit a file marked `DO NOT EDIT`; change the source and regenerate.
- `go test -race` is a gate; every new goroutine has an owner and a stop path.
- Propagate `context.Context` through every call that does I/O.

### Generic Front

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- Q1 = Front and no other section matches: a web framework in the manifest (Vue, Angular, Svelte, Astro, ...).
- The gate commands come from the CI workflows and the manifest scripts.

#### Gates

- The repo's lint, format check, typecheck, unit tests and production build, exactly as CI runs them; a gate the
  repo defines but CI skips stays a gate, marked `(not in CI)`.

#### E2E

- Playwright, unless the repo already uses another browser tool (Cypress, WebdriverIO): use that one.
- Evidence = the tool's JUnit or JSON report plus screenshots, referenced from the TRACE.

#### Dev server and ports

- The repo's dev script with its port flag set to PORT_BASE+SLOT, default PORT_BASE 3000.

#### Generated directories

- Build output (`dist/`, `build/`, framework caches), `node_modules/`, codegen outputs; check `.gitignore`.

#### Fresh setup

1. Toolchain pinned per `.nvmrc` / `.tool-versions`; remove dependencies and build output.
2. Install with an immutable lockfile; env file from the example; browsers for the E2E tool.

#### Risk triggers

- Framework majors; auth, cookies and sessions; client-exposed config; payments; accessibility-critical flows.

#### Conventions worth a rule

- The production build is a gate.
- Never put a secret in client-side code or client-exposed config.

### Generic Mobile

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- Q1 = Mobile and no other section matches: native iOS (`*.xcodeproj`, `Package.swift`, `Podfile`), native Android
  (`build.gradle(.kts)`, `settings.gradle(.kts)`), Kotlin Multiplatform, Ionic or Capacitor.

#### Gates

- The repo's lint, format check, unit tests and build per platform, exactly as CI runs them (for example
  `xcodebuild test`, `./gradlew lint test assembleDebug`).

#### E2E

- Maestro (maestro.dev), unless the repo already uses XCUITest, Espresso or Detox: use that one.
- Evidence = JUnit plus screenshots, compared against a baseline round on the same device.

#### Dev server and ports

- A bundler or live-reload server (when there is one) on PORT_BASE+SLOT, default PORT_BASE 8081.
- One simulator or emulator per floor.

#### Generated directories

- Build output (`build/`, `DerivedData/`, `.gradle/`), `Pods/`, codegen outputs; check `.gitignore`.

#### Fresh setup

1. Toolchain pinned per the repo (Xcode version, JDK, `.ruby-version` for CocoaPods or Fastlane).
2. Clean build output; resolve dependencies (`pod install`, Gradle sync, Swift packages).

#### Risk triggers

- OS or SDK target bumps; permissions and entitlements; persisted storage; auth; deep links; background work; push.

#### Conventions worth a rule

- One simulator or emulator per floor, passed explicitly to every build and E2E command.
- Persisted-data changes go through the upgrade-in-place gate.

### Generic Backend

#### Status

starter

Written from the stack's standard tooling; not yet run end to end by a squad — verify every command in Phase 2.

#### Detection hints

- Q1 = Backend and no other section matches: JVM (`pom.xml`, `build.gradle`), .NET (`*.csproj`), Ruby
  (`Gemfile` with `rails`), PHP (`composer.json`), Rust (`Cargo.toml`), Elixir (`mix.exs`).

#### Gates

- The repo's lint, format check, typecheck or compile, and tests, exactly as CI runs them.

#### E2E

- HTTP contract tests in the repo's own test runner, against real dependencies (docker compose or testcontainers).
- Evidence = the runner's JUnit or JSON report plus captured responses.

#### Dev server and ports

- The service on PORT_BASE+SLOT, default PORT_BASE 8080; dependencies via `docker compose -p "$FLOOR_PROJECT"`
  (RULES §Floor), each published port at its base + SLOT.

#### Generated directories

- Build output (`target/`, `bin/`, `obj/`, `_build/`), vendored dependencies, generated clients and stubs.

#### Fresh setup

1. Toolchain pinned per the repo (`.tool-versions`, wrapper scripts such as `./gradlew`).
2. Resolve dependencies from the lockfile; env file from the example; dependencies up; migrations.

#### Risk triggers

- Auth and authorization; migrations; public API contracts; concurrency; framework majors; secrets and config.

#### Conventions worth a rule

- Every endpoint change ships with a contract test for its success and error responses.
- Each floor runs its own dependencies; no floor touches another floor's data.
