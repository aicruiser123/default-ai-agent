#!/usr/bin/env bash
# Claude Code env bootstrap — разворачивает память + петлю самообучения в папку.
#
# Установка:
#   curl -fsSL https://raw.githubusercontent.com/aicruiser123/default-ai-agent/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- /путь/к/папке
#
# Обновление уже установленного окружения (безопасно: память и правки не трогает):
#   curl -fsSL .../install.sh | bash -s -- --update
#   curl -fsSL .../install.sh | bash -s -- --update /путь/к/папке
#
# Переменные:
#   CC_ENV_REPO=owner/repo   — откуда тянуть
#   CC_ENV_BRANCH=main       — ветка
#   CC_ENV_FORCE=1           — (только установка) перезаписать существующие файлы

set -euo pipefail

REPO="${CC_ENV_REPO:-aicruiser123/default-ai-agent}"      # переопределить: CC_ENV_REPO=owner/repo
BRANCH="${CC_ENV_BRANCH:-main}"

MODE=install
if [[ "${1:-}" == "--update" || "${CC_ENV_UPDATE:-0}" == "1" ]]; then
  MODE=update
  [[ "${1:-}" == "--update" ]] && shift
fi
TARGET="${1:-$PWD}"

# Защита от непонятного флага в позиции пути (напр. CDN отдал старый install.sh
# без поддержки --update): иначе получим криптическое `mkdir: illegal option`.
case "$TARGET" in
  -*) printf '✗ Неизвестный аргумент: %s. Поддерживается только --update.\n   Если только что обновлял репозиторий — кэш CDN мог отдать старый скрипт, повтори через минуту.\n' "$TARGET" >&2; exit 1 ;;
esac

say(){ printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
err(){ printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || err "нужен curl"
command -v tar  >/dev/null || err "нужен tar"

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
say "Режим: $MODE | Цель: $TARGET"

if [[ "$MODE" == install && -f "$TARGET/CLAUDE.md" && "${CC_ENV_FORCE:-0}" != "1" ]]; then
  err "В $TARGET уже есть окружение. Обновить: добавь --update. Переустановить с нуля: CC_ENV_FORCE=1."
fi
if [[ "$MODE" == update && ! -f "$TARGET/CLAUDE.md" ]]; then
  err "В $TARGET нет установленного окружения (нет CLAUDE.md). Сначала установи без --update."
fi

# ---- скачать template/ во временную папку ----
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC=""
URL="${CC_ENV_URL:-https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}}"
say "Качаю ${REPO}@${BRANCH}"
if curl -fsSL "$URL" | tar -xz -C "$TMP" 2>/dev/null; then
  SRC="$(find "$TMP" -maxdepth 2 -type d -name template -print -quit)"
elif command -v gh >/dev/null; then
  say "Публичный доступ не сработал — пробую gh (приватный репозиторий)"
  gh repo clone "$REPO" "$TMP/clone" -- --depth 1 --branch "$BRANCH" >/dev/null 2>&1 \
    || err "Не скачать $REPO даже через gh"
  SRC="$TMP/clone/template"
else
  err "Не скачать $REPO. Приватный? Поставь gh (brew install gh) и авторизуйся: gh auth login"
fi
[[ -d "$SRC" ]] || err "В репозитории нет папки template/"

if [[ "$MODE" == install ]]; then
  # ---- свежая установка: копируем всё, существующее не трогаем без FORCE ----
  say "Разворачиваю файлы"
  ( cd "$SRC" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
    rel="${f#./}"; dest="$TARGET/$rel"
    if [[ -e "$dest" && "${CC_ENV_FORCE:-0}" != "1" ]]; then
      printf '  skip (есть): %s\n' "$rel"; continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$SRC/$rel" "$dest"
    printf '  + %s\n' "$rel"
  done
  chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true
  say "Готово."
  echo
  echo "Дальше:"
  echo "  cd \"$TARGET\""
  echo "  заполни core/USER.md (кто ты) и CLAUDE.md (правила проекта)"
  echo "  claude        # хуки + dev-скиллы (.claude/skills/) активны со старта"
  exit 0
fi

# ============================ РЕЖИМ ОБНОВЛЕНИЯ ============================
# Принцип безопасности:
#   - МЕХАНИКА (hooks/, .claude/skills/, SOURCES.md) — перезаписывается из репо;
#   - ТВОИ ФАЙЛЫ (CLAUDE.md, settings.json, USER.md, rules.md) — НЕ трогаем,
#     новую версию кладём рядом как <файл>.new для ручного сравнения;
#   - ПАМЯТЬ (core/hot, core/warm, core/learnings, memory/) — не трогаем вообще.

say "Обновляю механику (память и твои правки не трогаю)"

# 1) Хуки — перезаписываем целиком.
if [[ -d "$SRC/hooks" ]]; then
  for f in "$SRC"/hooks/*; do
    cp "$f" "$TARGET/hooks/$(basename "$f")"
  done
  chmod +x "$TARGET"/hooks/*.sh 2>/dev/null || true
  echo "  обновлено: hooks/"
fi

# 2) Скиллы — перезаписываем каждый скилл из репо (твои добавленные скиллы,
#    которых нет в репо, остаются нетронутыми).
if [[ -d "$SRC/.claude/skills" ]]; then
  mkdir -p "$TARGET/.claude/skills"
  for d in "$SRC"/.claude/skills/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    rm -rf "${TARGET:?}/.claude/skills/$name"
    cp -R "$d" "$TARGET/.claude/skills/$name"
  done
  [[ -f "$SRC/.claude/skills/SOURCES.md" ]] && cp "$SRC/.claude/skills/SOURCES.md" "$TARGET/.claude/skills/SOURCES.md"
  echo "  обновлено: .claude/skills/"
fi

# 3) Потенциально кастомизированные файлы — НЕ перезаписываем, кладём .new.
NEW_COUNT=0
for rel in .claude/settings.json CLAUDE.md core/USER.md core/rules.md; do
  src="$SRC/$rel"; dst="$TARGET/$rel"
  [[ -f "$src" ]] || continue
  if [[ ! -f "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; echo "  добавлено: $rel"
  elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
    cp "$src" "$dst.new"; warn "изменилось в репо: $rel  →  новая версия в $rel.new (сравни: diff \"$rel\" \"$rel.new\")"
    NEW_COUNT=$((NEW_COUNT+1))
  fi
done

echo "  не тронуто (твоя память/состояние): core/hot, core/warm, core/learnings, memory/"
say "Обновление завершено."
if [[ "$NEW_COUNT" -gt 0 ]]; then
  echo
  echo "Есть $NEW_COUNT файл(ов) с обновлениями в репозитории — они НЕ применены автоматически,"
  echo "чтобы не затереть твои правки. Сравни *.new и перенеси нужное вручную, потом удали *.new."
fi
