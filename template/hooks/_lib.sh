#!/usr/bin/env bash
# Общие helper'ы для хуков окружения Claude Code.
set -euo pipefail

# Корень проекта: git toplevel, иначе CLAUDE_PROJECT_DIR, иначе cwd.
cc_root() {
  local root
  if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
  else
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
  fi
}

cc_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Достаёт строковое поле верхнего уровня из JSON на stdin. Arg1 = ключ.
cc_json_field() {
  local key="$1" data
  data="$(cat)"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$data" | python3 -c "
import sys, json
key = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = d.get(key, '')
print(v if isinstance(v, str) else '')
" "$key" 2>/dev/null
  else
    printf '%s' "$data" \
      | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
  fi
}
