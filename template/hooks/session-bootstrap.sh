#!/usr/bin/env bash
# SessionStart: печатает в stdout handoff + хвост recent + уроки.
# Claude Code инжектит stdout SessionStart-хука как доп-контекст сессии.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SELF_DIR}/_lib.sh"

ROOT="$(cc_root)"
HANDOFF="${ROOT}/core/hot/handoff.md"
RECENT="${ROOT}/core/hot/recent.md"
LESSONS="${ROOT}/core/learnings/lessons.md"

{
  if [[ -s "$HANDOFF" ]]; then
    echo "## Handoff (где остановились)"; echo
    cat "$HANDOFF"; echo
  fi
  if [[ -s "$RECENT" ]]; then
    echo "## Недавняя активность (хвост)"; echo
    # tail по СТРОКАМ, не байтам: байтовая обрезка режет UTF-8 кириллицу.
    tail -n 30 "$RECENT"; echo
  fi
  if [[ -s "$LESSONS" ]]; then
    echo "## Уроки (не повторять)"; echo
    tail -n 40 "$LESSONS"; echo
  fi
} | head -c 12000

exit 0
