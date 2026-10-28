# >>> t-workflow >>>
# ---------------------------------------------------------------------------
# Bloque de shell del workflow terminal (zellij + yazi + mitos/helix).
# El instalador (install.sh) ANEXA este bloque al ~/.zshrc entre los marcadores
# `# >>> t-workflow >>>` y `# <<< t-workflow <<<` de forma idempotente.
# No edites el .zshrc a mano dentro de estos marcadores: edita este archivo.
# ---------------------------------------------------------------------------

# Editor por defecto: Mitos (fork de Helix). Binario `ms`.
# Para volver a Helix, cambia a 'hx' (ver README, sección "Helix como opción").
export EDITOR='ms'
export VISUAL='ms'

# ---------------------------------------------------------------------------
# zj — abre (o re-attachea) una sesión de zellij con NOMBRE y LAYOUT fijos.
#
# Por qué: el opener de Yazi (yazi.toml) manda `:open` al pane "Editor" usando
# `zellij action --session <nombre>`. Si renombras una sesión a mano, el proceso
# Yazi conserva el nombre viejo en su entorno y el opener se cuelga. La solución
# es NO renombrar: crear la sesión ya con su nombre definitivo desde el inicio.
#
# Uso:
#   zj bf          -> sesión llamada "bf" con el layout "code" (por defecto)
#   zj e4 code     -> sesión "e4" con el layout "code"
#   zj docs notes  -> sesión "docs" con el layout "notes"
#
# Portable: no usa rutas absolutas. Zellij resuelve el layout por nombre desde
# ~/.config/zellij/layouts/ (o la ruta de layouts del entorno donde corra).
# ---------------------------------------------------------------------------
zj() {
    local name="${1:?uso: zj <nombre-sesion> [layout]}"
    local layout="${2:-code}"
    zellij attach --create "$name" options --default-layout "$layout"
}
# <<< t-workflow <<<
