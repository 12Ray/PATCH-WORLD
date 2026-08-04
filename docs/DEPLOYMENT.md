# PATCH//WORLD deployment handoff

The repository is ready for two public web targets. The remaining values come
from the repository and Firebase project owned by the publisher.

## GitHub Pages

1. Create an empty GitHub repository and add it as `origin`.
2. Push `main` and the release tag.
3. In **Settings > Pages**, select **GitHub Actions** as the source.
4. Run `Deploy GitHub Pages`, or push to `main`.
5. Record the resulting public URL in `docs/submission/SUBMISSION.md` and the
   Notion Project HQ.

The workflow builds with the repository name as `--base-href` and derives the
displayed app version from the nearest Git tag.

## Firebase Hosting

For GitHub Actions, add repository variable `FIREBASE_PROJECT_ID` and encrypted
secret `FIREBASE_SERVICE_ACCOUNT`, then manually run `Deploy Firebase Hosting`.
The workflow verifies, builds, and publishes the `live` channel.

For a local deployment, install Firebase CLI and sign in with the publishing
account:

```powershell
$releaseVersion = git describe --tags --always
$releaseSha = git rev-parse --short HEAD
$releaseTime = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
flutter build web --release `
  "--dart-define=APP_VERSION=$releaseVersion" `
  "--dart-define=BUILD_SHA=$releaseSha" `
  "--dart-define=BUILD_TIME=$releaseTime"
firebase deploy --only hosting --project YOUR_FIREBASE_PROJECT_ID
```

`firebase.json` already serves `build/web`, rewrites routes to `index.html`,
and applies explicit cache headers. A `.firebaserc` is optional when `--project`
is supplied.

## Required post-deploy checks

- Open both URLs in a private window without authentication.
- Complete title > first room > patch selection > boss > ending.
- Verify keyboard, left-click pulse, audio unlock, pause, settings, and credits.
- Repeat the full flow in desktop Chrome and Safari.
- Confirm no console errors, asset 404 responses, or stale BuildInfo values.
- Add the production, mirror, source, video, and feedback URLs to the submission
  document and Notion HQ.

## Values still required from the publisher

- GitHub repository URL
- Firebase project ID and an account authorized to deploy
- Public 3-minute video URL
- Public feedback form URL
- Results from five new playtesters, including Safari evidence
