#!/usr/bin/env bash
# UserPromptSubmit: ловит поправки владельца, пишет сырьё в episodes.jsonl.
# Курирование episodes -> lessons.md делаю осознанно. Хук НИКОГДА не блокирует.
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SELF_DIR}/_lib.sh"

ROOT="$(cc_root)"
EP="${ROOT}/core/learnings/episodes.jsonl"
mkdir -p "$(dirname "$EP")"

PROMPT="$(cc_json_field prompt || true)"
[[ -z "$PROMPT" ]] && exit 0

shopt -s nocasematch
if [[ "$PROMPT" =~ (нет,|не\ так|я\ же\ говорил|перестань|не\ надо|ошибся|это\ неправильно|stop\ doing|should\ be|that.?s\ wrong|don.?t\ ) ]]; then
  TS="$(cc_iso)"
  EXCERPT="${PROMPT:0:280}"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, sys
print(json.dumps({'ts': sys.argv[1], 'prompt_excerpt': sys.argv[2]}, ensure_ascii=False))
" "$TS" "$EXCERPT" >> "$EP"
  else
    # Нет python3: надёжное экранирование JSON в чистом shell — рабиновая нора
    # (BSD vs GNU). episodes.jsonl — lossy-лог для курирования, точность не нужна:
    # выбрасываем \ и " и схлопываем управляющие символы в пробел. Валидный JSON
    # гарантирован, смысл поправки сохраняется.
    ESC="$(printf '%s' "$EXCERPT" | tr -d '\\"' | tr '\n\r\t' '   ')"
    printf '{"ts":"%s","prompt_excerpt":"%s"}\n' "$TS" "$ESC" >> "$EP"
  fi
fi

exit 0
