# RUNBOOK: my-expo-app

Kit v1.0.0. `$KIT` = `<KIT_PATH>`. `{{FLOOR_PATH}}`, `{{KEY}}` and `{{SLOT}}` come from the floor card;
`PORT_BASE` (8081) comes from `$KIT/kit.env`. Evidence for each command: `PROJECT_PROFILE.md`.

## 1. Fresh setup (every new floor, before INTAKE)

Run from `{{FLOOR_PATH}}`, logging to `$KIT/floor-snapshots/{{KEY}}/fresh-setup.log`. A failing step stops the floor; show
the log tail to the human.

```bash
cd "{{FLOOR_PATH}}"
LOG="$KIT/floor-snapshots/{{KEY}}/fresh-setup.log"; mkdir -p "$(dirname "$LOG")"
{
  set -e
  # 1. Node from .node-version; npm ci installs from the lockfile and replaces node_modules/.
  test "$(node --version)" = "v$(cat .node-version)"
  npm ci
  # 2. Regenerate ios/ and android/ from app.config.ts (Expo CNG; prebuild runs pod install).
  npx expo prebuild --clean
  test -d ios && test -d android
  echo "FRESH_SETUP ok $(git rev-parse --short HEAD) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$LOG" 2>&1
tail -n 1 "$LOG"
```

The last line, `FRESH_SETUP ok <sha> <UTC>`, becomes the first TRACE row.

## 2. Ports and dev server per slot

Every host port a floor publishes is its base + `{{SLOT}}` (RULES §Floor). This app publishes one:

- metro: 8081 + `{{SLOT}}` (`PORT_BASE`).

No container dependency and no local service: the app has no compose file and no env file (`PROJECT_PROFILE.md`,
"Ports"), so a floor cannot reach the ground's data.

Probe (or the Maestro) runs Metro in a persistent shell terminal on the floor. Never run it as an agent background job,
and never with `CI=1`:

```bash
cd "{{FLOOR_PATH}}"
npx expo start --dev-client --port $((8081 + {{SLOT}}))
```

Only the Maestro or Probe restarts Metro.

## 3. Build to this floor's device

- Pick a FREE simulator or emulator with `maestri portal devices`, then open the floor portal:
  `maestri portal create --simulator <id> "Sim-{{KEY}}"`.
- iOS: `npx expo run:ios --device <id> --port $((8081 + {{SLOT}}))`.
- Android: `npx expo run:android --device <id> --port $((8081 + {{SLOT}}))`. If the app uses `localhost`, run
  `adb -s <id> reverse tcp:<port> tcp:<port>`.
- App id `com.example.myexpoapp` on both platforms.

## 4. E2E run (Maestro)

```bash
cd "{{FLOOR_PATH}}"
EVID="$KIT/floor-snapshots/{{KEY}}/e2e"; mkdir -p "$EVID"
maestro --device <id> test --format junit --output "$EVID/report.xml" --test-output-dir "$EVID/artifacts" \
  .maestro/<feature>/
```

- One flow per user-facing AC or bug, in `.maestro/<feature>/` with a `config.yaml` (flow order, tags); shared steps
  live in `.maestro/helpers/`. Select by `testID` (`id:`). Pass variables with `-e NAME=value` on the command line
  (env declared inside a parent flow can be lost in its subflows; hand it on through `runFlow`'s `env:`).
- Add `takeScreenshot: <AC-n-step>` at each checkpoint; the files land in `$EVID/artifacts`.
- Before writing a flow, read the live screen: `maestri portal launch "Sim-{{KEY}}" com.example.myexpoapp`, then
  `maestri portal snapshot "Sim-{{KEY}}"`.
- Evidence = the JUnit report plus screenshots, referenced from the TRACE. Keep a frozen flow order and compare against
  a baseline round (same flows, same order, same device).
- Signed-in flows read the test account from the file named by `E2E_ACCOUNT_FILE` (chmod 600). Never echo it.

## 5. Device notes

- iOS dev client: open it with an explicit deep link:
  `myexpoapp://expo-development-client/?url=http%3A%2F%2Flocalhost%3A<port>`.
- The Android emulator reaches the host at `10.0.2.2`.
- On Android, do not send the dev-client deep link to an app that kept its state: expo-dev-launcher can crash at boot
  ("App react context shouldn't be created before"). Enter with `launchApp` plus a wait, or clear the app state first.
- Never run Metro with `CI=1`: Bonjour discovery is turned off and the dev-launcher server list stays empty.
- One simulator or emulator per floor; never share a device across floors.

## 6. Signing (Dock only)

Commits are GPG-signed (`commit.gpgsign=true`, set in the repo) with the key `PROJECT_PROFILE.md` "Policies" names.
The passphrase lives in the env var `GPG_PASSPHRASE` and is never printed. The Phase 3 extraction loop wrote the loopback
wrapper `<KIT_PATH>/gpg-loopback.sh` (Appendix D, `<ENV_VAR>` → `GPG_PASSPHRASE`, chmod 700); Dock signs through it:

```bash
git -c gpg.program="<KIT_PATH>/gpg-loopback.sh" commit -S -m "<message>"
git log -1 --format=%G?   # expect G
```
