#!/usr/bin/env bash
# Общие helper'ы для хуков окружения Claude Code.
set -euo pipefail

# Корень проекта. Приоритет: CLAUDE_PROJECT_DIR (его выставляет Claude Code для
# хуков и он авторитетен), иначе git toplevel, иначе cwd. ВАЖНО: git нельзя
# ставить первым — если проект развёрнут ВНУТРИ родительского git-репо, toplevel
# укажет на родителя и память проекта уйдёт не туда.
cc_root() {
  local root
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '%s\n' "$CLAUDE_PROJECT_DIR"
  elif root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
  else
    printf '%s\n' "$PWD"
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
