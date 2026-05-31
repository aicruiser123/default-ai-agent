# claude-env

Саморазворачивающееся окружение Claude Code: трёхслойная память + петля самообучения через хуки. Одна команда — и любая папка готова к разработке.

## Установка

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash
```

В конкретную папку:

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash -s -- ~/projects/new-thing
```

Если репозиторий приватный — поставь `gh` (`brew install gh && gh auth login`), скрипт сам переключится на него.

Переменные:
- `CC_ENV_REPO=owner/repo` — переопределить источник
- `CC_ENV_BRANCH=main` — ветка
- `CC_ENV_FORCE=1` — перезаписать существующие файлы

> Замени `USER/REPO` на свои координаты GitHub в этом README и в `install.sh` (переменная `REPO`).

## Что разворачивается

```
CLAUDE.md                     правила проекта (слой поверх глобального)
.claude/settings.json         хуки + permissions
memory/MEMORY.md              индекс долгой типизированной памяти
core/
  USER.md                     кто владелец
  rules.md                    инварианты проекта
  hot/handoff.md              «где остановились» (перезаписывается)
  hot/recent.md               хвост активности (пишет хук)
  warm/decisions.md           лог решений (ADR-lite)
  learnings/lessons.md        курированные уроки (инжектятся в сессию)
  learnings/episodes.jsonl    сырые коррекции (пишет хук)
hooks/
  session-bootstrap.sh        SessionStart -> инжектит handoff+recent+lessons
  auto-capture.sh             Stop -> дописывает recent
  correction-detector.sh      UserPromptSubmit -> ловит поправки в episodes
```

## Как замыкается петля самообучения

Поправка владельца → `correction-detector.sh` пишет в `episodes.jsonl` → я курирую класс ошибки в `lessons.md` → `session-bootstrap.sh` инжектит уроки в каждую новую сессию. Память переживает рестарты, а не держится «на памяти модели».

## После установки
1. Заполни `core/USER.md` и `core/rules.md`.
2. `claude` — хуки активируются со старта сессии.
