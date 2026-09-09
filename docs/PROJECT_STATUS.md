# Project Status

Updated: 2026-09-09

## Current checkpoint

The first usable version of Codex Quota Badge is implemented on the `feat/codex-quota-badge` branch.

Implemented:

- compact, aligned two-line menu-bar display (`5H` and `7D`);
- detail panel with reset times and last-update time;
- `立即刷新`, `隐藏详情`, and `完全退出` actions on one row;
- draggable borderless detail panel;
- calm `未检测到配额` state when Codex data is absent;
- local-only parsing of Codex session logs;
- startup discovery of the newest valid quota snapshot;
- cached path, modification time, and in-memory snapshot;
- one-minute status checks that avoid reopening unchanged logs;
- rediscovery after deletion or new-session filesystem events;
- parser, formatting, and refresh-decision test coverage;
- preview and local-run scripts;
- Chinese-first open-source README emphasizing the privacy and performance boundaries.
- MIT License;
- first README detail-panel screenshot generated from fixed preview data;
- README reordered around product understanding, trust, setup, and troubleshooting.
- reproducible local preview `.app` and `.dmg` scripts with ad-hoc signing;
- package verifier checks bundle metadata, executable, signature, and DMG integrity.

## Product boundaries

- No network requests.
- No account login, cookies, credentials, API keys, or token access.
- No writes to Codex files.
- No telemetry or quota-history database.
- No notifications, account switching, credit management, or automatic updates in V1.
- Quota values come from local Codex logs and may lag the web UI until Codex writes a new snapshot.

## Next priorities

Before a public GitHub release:

1. Add focused menu-bar and unavailable-state screenshots after the distributable app workflow is stable.
2. Obtain a Developer ID Application certificate and notarization credentials, then replace the temporary signing workflow with a signed and Apple-notarized `.app`/`.dmg`.
3. Publish the notarized artifact through GitHub Releases with a direct download path.
4. Verify and document tested macOS versions and CPU architectures; do not claim untested compatibility.
5. Measure idle memory, CPU, and disk behavior on a release build and publish the methodology and results.
6. Add CI only after the release build and test commands are stable.

Later improvements may include an English README, Homebrew Cask distribution, release notes, and a small set of GitHub repository topics.

## Resume checklist

1. Work from the `feat/codex-quota-badge` worktree.
2. Read `README.md`, this file, and the design document before changing behavior.
3. Run `swift build` and `swift run CodexQuotaBadgeTestRunner` before and after implementation work.
4. Preserve the local-only, no-credentials, no-recurring-write security boundary.
5. Update this file when a public-release prerequisite is completed.
