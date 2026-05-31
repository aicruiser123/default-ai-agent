#!/usr/bin/env bash
# Claude Code env bootstrap — разворачивает память + петлю самообучения в папку.
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash -s -- /путь/к/папке
#
# Переменные:
#   CC_ENV_REPO=owner/repo   — откуда тянуть (по умолчанию вшито ниже)
#   CC_ENV_BRANCH=main       — ветка
#   CC_ENV_FORCE=1           — перезаписывать существующие файлы

set -euo pipefail

REPO="${CC_ENV_REPO:-USER/REPO}"      # <-- ЗАМЕНИ на свой owner/repo (или передай CC_ENV_REPO=)
BRANCH="${CC_ENV_BRANCH:-main}"
TARGET="${1:-$PWD}"

say(){ printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
err(){ printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || err "нужен curl"
command -v tar  >/dev/null || err "нужен tar"

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
say "Цель: $TARGET"

if [[ -f "$TARGET/CLAUDE.md" && "${CC_ENV_FORCE:-0}" != "1" ]]; then
  err "В $TARGET уже есть CLAUDE.md. Перебить: CC_ENV_FORCE=1 перед командой."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SRC=""
URL="${CC_ENV_URL:-https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}}"
say "Качаю ${REPO}@${BRANCH}"
if curl -fsSL "$URL" | tar -xz -C "$TMP" 2>/dev/null; then
  SRC="$(echo "$TMP"/*/template)"
elif command -v gh >/dev/null; then
  say "Публичный доступ не сработал — пробую gh (приватный репозиторий)"
  gh repo clone "$REPO" "$TMP/clone" -- --depth 1 --branch "$BRANCH" >/dev/null 2>&1 \
    || err "Не скачать $REPO даже через gh"
  SRC="$TMP/clone/template"
else
  err "Не скачать $REPO. Приватный? Поставь gh (brew install gh) и авторизуйся: gh auth login"
fi

[[ -d "$SRC" ]] || err "В репозитории нет папки template/"

say "Разворачиваю файлы"
( cd "$SRC" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
  rel="${f#./}"
  dest="$TARGET/$rel"
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
echo "  claude        # хуки активируются со старта сессии"
