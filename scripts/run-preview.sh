#!/usr/bin/env bash
set -euo pipefail

swift build
CODEX_QUOTA_PREVIEW=1 exec .build/debug/CodexQuotaBadge
