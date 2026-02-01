#!/usr/bin/env bash
set -euo pipefail

# Run exactly one Ralph iteration (preferred).
# Assumes ralph.sh supports an iteration count parameter similar to:
#   ./ralph.sh --tool claude 10
# We'll force 1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_SH="${SCRIPT_DIR}/ralph.sh"

if [[ ! -x "${RALPH_SH}" ]]; then
  echo "ERROR: ${RALPH_SH} not found or not executable."
  echo "Run: chmod +x ${RALPH_SH}"
  exit 1
fi

# Pass through any extra args to ralph.sh (e.g., --tool claude)
# but force the iteration count to 1 at the end.
# Example:
#   ./scripts/ralph/ralph_once.sh --tool claude
# becomes:
#   ./scripts/ralph/ralph.sh --tool claude 1
"${RALPH_SH}" "${@}" 1
EOF