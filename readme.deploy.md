# Deploy guide

Two GitHub Actions pipelines do everything. The **git tag** — not [pubspec.yaml](pubspec.yaml) — is the version source of truth.

## Daily flow

**Web-only change** (deploys to GitHub Pages, ~2 min):

```
git push
```

**New Android release** (cuts a versioned APK + GitHub Release, ~5 min):

```
git tag v1.0.3        # next semver
git push origin v1.0.3
```

Tag a commit only after it's already on `main`.

## Links

- Live web app: https://squirion.github.io/swrpg-quickypedia/
- Latest APK (stable URL): https://github.com/squirion/swrpg-quickypedia/releases/latest/download/swrpg-quickypedia.apk
- All releases: https://github.com/squirion/swrpg-quickypedia/releases
- Workflow runs: https://github.com/squirion/swrpg-quickypedia/actions

## Workflow files

- [.github/workflows/deploy-pages.yml](.github/workflows/deploy-pages.yml) — fires on push to `main`, builds web, deploys to Pages.
- [.github/workflows/release-apk.yml](.github/workflows/release-apk.yml) — fires on `v*` tag push, builds signed APK, publishes Release. `versionName` is derived from the tag (strip `v`); `versionCode` is `github.run_number`.

## GitHub repo secrets

Stored at https://github.com/squirion/swrpg-quickypedia/settings/secrets/actions.

- `DOTENV` — full contents of local [.env](.env) (OAuth + GitHub PAT). Workflows recreate `.env` from this before building.
- `KEYSTORE_BASE64` — base64 of the release `.jks`. To regenerate from the local keystore (PowerShell):
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\keys\swrpg-quickypedia-release.jks")) | Set-Clipboard
  ```
- `KEYSTORE_PASSWORD` — keystore + key password (same value).

## Local artifacts that are NOT in git

- `C:\Users\polyr\keys\swrpg-quickypedia-release.jks` — the Android signing key. **If you lose this you can never ship an update to existing users without forcing an uninstall.** Back it up to a second location.
- [android/key.properties](android/key.properties) — local-build mirror of the keystore secrets. Gitignored.
- [.env](.env) — local OAuth + PAT. Gitignored. Bundled into builds at build time.

## When to revisit

- **PAT expiry** — fine-grained GitHub PAT in `.env` has a hard expiration. Generate a new one scoped to `squirion/swrpg-quickypedia-data` only, update local `.env` *and* the `DOTENV` repo secret, then revoke the old token.
- **Failing CI** — open the red run at the Actions URL above. Top suspects: typo in a secret name, `.env` line endings mangled when pasting, tag pushed before its commit was on `main`.
