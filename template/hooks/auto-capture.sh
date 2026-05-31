#!/usr/bin/env bash
# Stop: дописывает строку о завершённой сессии в recent.md, ротация при >200 строк.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SELF_DIR}/_lib.sh"

ROOT="$(cc_root)"
RECENT="${ROOT}/core/hot/recent.md"
ARCHIVE_DIR="${ROOT}/core/hot/archive"
TS="$(cc_iso)"

mkdir -p "$(dirname "$RECENT")" "$ARCHIVE_DIR"
printf -- '- %s — сессия завершена\n' "$TS" >> "$RECENT"

if [[ "$(wc -l < "$RECENT")" -gt 200 ]]; then
  mv "$RECENT" "${ARCHIVE_DIR}/recent-${TS//:/-}.md"
  printf '# Recent\n' > "$RECENT"
fi

exit 0
