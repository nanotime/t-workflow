# t-workflow — TODO / estado

Lista viva de tareas para el repo del workflow de terminal (zellij + yazi + Mitos).

## ✅ Hecho

- [x] Migrar editor de Helix (`hx`) a **Mitos** (`ms`, fork de Helix).
  - [x] `~/.config/zellij/layouts/code.kdl` — pane "Editor": `command "hx"` comentado → `command "ms"`.
  - [x] `~/.zshrc` — `EDITOR`/`VISUAL='hx'` comentados → `='ms'`.
  - [x] `~/.config/zellij/config.kdl` — `scrollback_editor` → `~/.local/bin/ms`.
  - [x] `~/.config/yazi/yazi.toml` — opener `helix` comentado → copia `mitos`; reglas `[open]` → `use = "mitos"`.
  - [x] Probado: sesión nueva con `zj`, pane "Editor" corre mitos, yazi abre ahí. **Funciona.**
- [x] Crear repo `~/Sandbox/Personal/t-workflow/` con las configs (symlink como enfoque previsto).
  - [x] `zellij/config.kdl`, `zellij/layouts/code.kdl`
  - [x] `yazi/yazi.toml`
  - [x] `helix/config.toml` (opción), `mitos/config.toml` (principal)
  - [x] `shell/workflow.zsh` — bloque `EDITOR/VISUAL` + función `zj`, con marcadores `# >>> t-workflow >>>`.
  - [x] `README.md`, `LICENSE` (GPLv3), `.gitignore`.
- [x] Eliminar el keybind `C-y` (selector Yazi dentro del editor) de `mitos/config.toml` y `helix/config.toml`. Innecesario: yazi ya corre en su propio pane y abre vía opener. Se borró el bloque y sus comentarios; `[keys.normal]` queda solo con `[keys.normal.space]`.
- [x] Eliminar `yazi/open-helix.sh`: opener alternativo muerto (no lo usaba `yazi.toml`), menos portable que el inline (hardcodeaba `/opt/homebrew/bin/zellij` y dependía de `python3`). El one-liner inline de `yazi.toml` cubre el caso. Se limpiaron referencias en `README.md` e `install.sh`.

## 🔲 Pendiente

### Instalador
- [x] Escribir `install.sh` general:
  - [x] Symlinks idempotentes desde `~/.config/*` → archivos del repo.
  - [x] Anexar `shell/workflow.zsh` al `~/.zshrc` entre marcadores, de forma **idempotente** (no duplicar si ya existe el bloque; si cambió, respalda y reemplaza).
  - [x] No pisar configs existentes sin respaldo (backup `.bak.<timestamp>` o aviso si el destino no es symlink).
  - [x] Discovery de prerequisitos (`zellij`, `yazi`, `ms`, `lazygit`, `hx`): reporta ruta/versión; faltantes → prompt y/n (Y instala vía brew o curl pipe-to-shell para `ms`, N skip).
  - [x] `--dry-run` para previsualizar acciones; `--force` para no preguntar al reemplazar (igual respalda).
  - [x] Sin TTY (CI/pipe) asume "no" en acciones destructivas por seguridad.
  - [x] Probado end-to-end en HOME temporal: backup+symlink, anexado de bloque, e idempotencia (doble corrida = no-op, `zj()` una sola vez).

### Git
- [ ] `git init` + primer commit del repo.
- [ ] Crear repositorio remoto y `git push` (¿GitHub? decidir visibilidad).

### Mejoras / limpieza
- [ ] Revisar si `languages.toml` (helix/mitos) debería versionarse también.
- [ ] Mover el `soft-wrap` global a `languages.toml` para que solo aplique a Markdown (nota ya anotada en `*/config.toml`).

## 📝 Notas / contexto

- **Clave del diseño**: lo que decide qué editor abre yazi NO es `$EDITOR` ni `yazi.toml`,
  sino el `command` del pane "Editor" en `code.kdl`. El opener de yazi solo manda
  `:open <archivo>` por teclas a ese pane vía `zellij action --session <nombre>`.
- **No renombrar sesiones a mano**: `zj` crea la sesión con nombre fijo para que el
  nombre que yazi tiene en su entorno siempre coincida; renombrar cuelga el opener.
- **Prueba limpia de zellij**: usar `zellij delete-session <nombre> --force` (no solo
  kill) para evitar que resuciten panes viejos serializados; o usar un nombre nuevo.
- Toda la config vieja de helix quedó **comentada, no borrada**.
- Mitos: binario `ms`, `~/.local/bin/ms` (v0.1.2), config en `~/.config/mitos`,
  `:open` idéntico a helix. Instalación: `curl -fsSL https://mitos.computer/install.sh | sh`.
