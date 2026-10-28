# t-workflow

Mi workflow de terminal: un entorno de desarrollo basado en **zellij** (multiplexor),
**yazi** (explorador de archivos) y **Mitos** (editor, fork de Helix), integrados para
que al elegir un archivo en yazi se abra en el editor que corre en un pane fijo de la
misma sesión de zellij.

> El editor principal es **Mitos**. **Helix** se mantiene como opción (ver más abajo).

## Cómo funciona

Una sesión de zellij se abre con la función `zj`, que crea la sesión con un **nombre
fijo** y el layout `code`. Ese layout levanta tres panes:

```
┌───────────────────────────┬──────────────────┐
│                           │ Explorer (yazi)  │
│   Editor  (ms / mitos)    ├──────────────────┤
│                           │ Lazygit          │
└───────────────────────────┴──────────────────┘
```

Cuando abres un archivo en yazi, su `opener` manda `:open <archivo>` por teclas, vía
`zellij action --session <nombre>`, al pane llamado **"Editor"** (donde corre Mitos).
Por eso la sesión **no debe renombrarse a mano**: `zj` la crea ya con su nombre
definitivo para que el nombre que yazi tiene en su entorno siempre coincida.

## Prerequisitos

Instala estas herramientas antes de usar el workflow:

| Herramienta | Para qué | Instalación (macOS) |
|-------------|----------|---------------------|
| [zellij](https://zellij.dev/)   | Multiplexor de terminal      | `brew install zellij` |
| [yazi](https://yazi-rs.github.io/) | Explorador de archivos    | `brew install yazi` |
| [Mitos](https://mitos.computer/) | Editor (fork de Helix), binario `ms` | `curl -fsSL https://mitos.computer/install.sh \| sh` |
| [lazygit](https://github.com/jesseduffield/lazygit) | Git TUI (pane) | `brew install lazygit` |
| [Helix](https://helix-editor.com/) *(opcional)* | Editor alternativo, binario `hx` | `brew install helix` |

El instalador de Mitos deja `ms` en `~/.local/bin/ms`. Asegúrate de que `~/.local/bin`
esté en tu `PATH`. Verifica con `ms --version` y `ms --health`.

## Estructura del repo

```
t-workflow/
├── README.md
├── TODO.md                   # estado vivo del proyecto / pendientes
├── LICENSE                   # GPLv3
├── .gitignore
├── install.sh                # instalador: discovery + symlinks + bloque .zshrc
├── zellij/
│   ├── config.kdl            # -> ~/.config/zellij/config.kdl
│   └── layouts/
│       └── code.kdl          # -> ~/.config/zellij/layouts/code.kdl
├── yazi/
│   └── yazi.toml             # -> ~/.config/yazi/yazi.toml
├── helix/
│   └── config.toml           # -> ~/.config/helix/config.toml   (opcional)
├── mitos/
│   └── config.toml           # -> ~/.config/mitos/config.toml
└── shell/
    └── workflow.zsh          # bloque anexado al ~/.zshrc (EDITOR/VISUAL + función zj)
```

## Instalación

Clona el repo y ejecuta el instalador:

```sh
git clone <url-del-repo> ~/Sandbox/Personal/t-workflow
cd ~/Sandbox/Personal/t-workflow
./install.sh
```

El instalador está pensado para entornos **no limpios** (donde ya tienes
herramientas o configs). Trabaja en fases:

1. **Preflight**: detecta OS y resuelve la raíz del repo desde la ruta del propio
   script (portable, sin rutas absolutas hardcodeadas).
2. **Discovery de dependencias**: comprueba `zellij`, `yazi`, `ms`, `lazygit` y `hx`
   (opcional), mostrando ruta y versión de las presentes. Por cada una faltante
   pregunta `y/n`: **Y** la instala (vía `brew`, o el `curl … | sh` oficial para
   Mitos), **N** la omite.
3. **Symlinks idempotentes**: enlaza `~/.config/*` → archivos del repo. Si el destino
   ya es un symlink a este repo, no hace nada. Si es una **config real tuya**, la
   respalda como `<archivo>.bak.<timestamp>` antes de enlazar (nunca la pisa a ciegas).
4. **Bloque `.zshrc`**: anexa `shell/workflow.zsh` entre los marcadores
   `# >>> t-workflow >>>` y `# <<< t-workflow <<<`, de forma **idempotente** (no
   duplica; si el bloque cambió, respalda el `.zshrc` y lo reemplaza).

Flags:

| Flag | Efecto |
|------|--------|
| `--dry-run` | Muestra todo lo que haría sin modificar nada. |
| `--force`   | No pregunta al reemplazar configs reales (igual las respalda). |
| `-h`, `--help` | Ayuda. |

> Sin TTY (p. ej. en un pipe o CI) el instalador asume **"no"** en las acciones
> destructivas por seguridad, en vez de proceder sin confirmación.

Previsualiza siempre antes de aplicar:

```sh
./install.sh --dry-run
```

### Enlace manual (alternativa)

Si prefieres no usar el instalador, puedes enlazar a mano:

```sh
REPO="$HOME/Sandbox/Personal/t-workflow"   # ajusta a dónde clonaste el repo

ln -sfn "$REPO/zellij/config.kdl"         ~/.config/zellij/config.kdl
ln -sfn "$REPO/zellij/layouts/code.kdl"   ~/.config/zellij/layouts/code.kdl
ln -sfn "$REPO/yazi/yazi.toml"            ~/.config/yazi/yazi.toml
ln -sfn "$REPO/mitos/config.toml"         ~/.config/mitos/config.toml
ln -sfn "$REPO/helix/config.toml"         ~/.config/helix/config.toml   # opcional

# Anexar el bloque de shell al .zshrc (hazlo una sola vez):
cat "$REPO/shell/workflow.zsh" >> ~/.zshrc
```

Luego abre una terminal nueva (o `source ~/.zshrc`) y arranca con:

```sh
zj dev        # sesión "dev" con el layout "code"
```

## Helix como opción

El workflow usa Mitos por defecto, pero puedes volver a Helix (que es compatible porque
Mitos es su fork):

1. **Editor del pane**: en `zellij/layouts/code.kdl`, cambia `command "ms"` por
   `command "hx"`.
2. **EDITOR/VISUAL**: en `shell/workflow.zsh`, cambia `ms` por `hx`.
3. **scrollback de zellij**: en `zellij/config.kdl`, ajusta `scrollback_editor`.
4. **Opener de yazi**: en `yazi/yazi.toml` las reglas usan el opener `mitos`; hay un
   opener `helix` comentado como referencia (el comando interno es idéntico porque
   `:open` funciona igual en ambos editores).

## Notas

- El `yazi.toml` activo manda `:open` al pane "Editor" con un one-liner inline
  (resuelve el pane por título con `zellij action list-panes`). No depende de scripts
  externos ni de rutas absolutas.
- Los archivos `*.bak` de zellij se ignoran vía `.gitignore` (son autogenerados).

## Licencia

[GPLv3](LICENSE).
