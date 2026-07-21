# Cododel Neovim: подход к разработке

Этот репозиторий — terminal-first Neovim-конфиг. Центральная область — редактор кода, а файловая навигация, AI и shell живут в отдельных persistent-панелях.

## Архитектурные правила

- `lua/cododel/navigation.lua` — единственный router для directional focus `Cmd+H/J/K/L`.
- `lua/cododel/options.lua` — центральные опции (в т.ч. AI agent: `name` / `cmd` / `install`); override в `config/settings.lua` до lazy.
- `lua/cododel/ai_sidebar.lua` владеет drawer-панелями, terminal buffers и PTY lifecycle; CLI берёт из `options.ai`.
- `lua/cododel/file_sidebar.lua` — тонкий adapter над NvimTree и источник cwd для запуска AI из выбранного node.
- `lua/cododel/git_review.lua` — review-mode: LazyGit (+ Delta) в content-колонке editor; chat/bottom не трогает.
- `lua/cododel/deps.lua` — registry внешних CLI (`need` на use-site) + late `run()` после init; OK кешируются в gitignored `state/deps-cache.json`. У `need` поле `install` обязательно (команда установки в missing-report).
- AI sidebar содержит несколько независимых Codex processes; bottom terminal всегда независим от них.
- Для terminal processes используется native `vim.fn.termopen()`.
- Панели можно скрывать без остановки процессов; закрытие процесса удаляет его terminal buffer.
- Process persistence и editor-context bridge пока не входят в текущий scope.

## Изменение поведения

Поведенческие изменения сначала покрываются focused-тестом в `tests/`, затем реализуются в Lua:

1. добавить или изменить assertion;
2. убедиться, что тест падает по ожидаемой причине;
3. внести минимальный patch;
4. повторить тест до состояния green.

Тесты не используют отдельный framework. Они запускаются headless Neovim через:

```sh
sh tests/run.sh
```

В тестах разрешены локальные stubs для `nvim-drawer`, `nvim-tree` и внешних CLI, чтобы проверять маршрутизацию и lifecycle без запуска реального Codex.

## Перед commit

Перед коммитом отдельно проверить, требует ли изменение обновления документации. Если меняются UX-контракт, mappings, команды, архитектура или workflow, сначала обновить README и/или соответствующую документацию, затем запускать проверки и создавать commit.

Запустить:

```sh
sh tests/run.sh
nvim --headless -n -i NONE -u NONE \
  '+luafile lua/cododel/navigation.lua' \
  '+luafile lua/cododel/ai_sidebar.lua' \
  '+luafile lua/cododel/file_sidebar.lua' \
  '+luafile lua/cododel/git_review.lua' \
  '+qa!'
git diff --check
```

Изменения должны оставаться изолированными от LSP, completion, colorscheme, statusline и обычных terminal mappings. Новые зависимости добавляются только при явной необходимости.

## UX-контракт

- `Cmd+H`: влево к Files; из Files скрыть и перейти в editor.
- `Cmd+L`: вправо к AI; из AI скрыть и перейти в editor.
- `Cmd+J`: открыть или сфокусировать bottom terminal, запомнив источник; повторно скрыть и вернуться к источнику.
- `Cmd+K`: из bottom terminal перейти в editor, не скрывая terminal.
- `Shift+H/L` buffer-local и переключают только Codex tabs.
- `Shift+Esc`: maximize текущего pane в float с минимальным отступом; повторно — закрыть float и вернуть фокус в исходный pane.
- Внешние CLI регистрируются через `cododel.deps.need({ bin, install, ... })` в модулях/plugin specs по месту использования (`install` обязателен); после init вызывается `cododel.deps.run()` (missing → summary с install-командами; OK → cache).
- `Ctrl+Shift+G`: toggle git review mode (LazyGit + Delta) в content-колонке editor.
  - Enter: скрыть NvimTree; заменить editor buffer на LazyGit; AI sidebar и bottom terminal не трогать (ни hide, ни focus, ни lifecycle).
  - Exit (`q` в LazyGit или повторный `Ctrl+Shift+G`): восстановить editor buffer+view, если editor был; восстановить NvimTree только если он был открыт; если editor не было — не поднимать file buffer принудительно.
  - Пока review активен, content-колонка остаётся editor-zone для `Cmd+H/J/K/L`.
- При переходе из Files в AI выбранная директория запускает новую Codex-сессию напрямую, а выбранный файл — из parent directory; остальные входы используют git-root fallback.

При изменении этого контракта одновременно обновляются `navigation.lua`, focused-тесты и README.
