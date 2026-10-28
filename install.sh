#!/usr/bin/env bash
# ===========================================================================
# t-workflow — instalador
#
# Enlaza las configs de este repo en ~/.config/* mediante symlinks idempotentes
# y anexa el bloque de shell (shell/workflow.zsh) al ~/.zshrc entre marcadores.
#
# Diseñado para entornos NO limpios: antes de tocar nada hace discovery de
#   1) dependencias ya instaladas (reporta; ofrece instalar las faltantes y/n), y
#   2) estado de cada archivo destino (symlink al repo / symlink ajeno / archivo
#      real), respaldando cualquier config real antes de reemplazarla.
#
# Uso:
#   ./install.sh [--dry-run] [--force] [-h|--help]
#
#   --dry-run   Muestra lo que haría sin modificar nada.
#   --force     No pide confirmación al reemplazar configs reales (igual respalda).
#   -h, --help  Esta ayuda.
# ===========================================================================
set -euo pipefail

# --- Resolución portable de la raíz del repo (dir de este script) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$SCRIPT_DIR"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ZSHRC="$HOME/.zshrc"
STAMP="$(date +%Y%m%d-%H%M%S)"

MARK_BEGIN="# >>> t-workflow >>>"
MARK_END="# <<< t-workflow <<<"

DRY_RUN=0
FORCE=0

# --- Colores (solo si es TTY) ----------------------------------------------
if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[34m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""
fi

info()  { printf '%s\n' "$*"; }
ok()    { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
warn()  { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$*"; }
err()   { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
step()  { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
run()   { # ejecuta o muestra según --dry-run
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    else
        eval "$@"
    fi
}

usage() {
    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# prompt y/n: devuelve 0 si "sí". Con --force o sin TTY, asume "no" para
# acciones destructivas y "sí" solo donde se indique explícitamente.
ask_yn() { # ask_yn "pregunta" default(Y|N)
    local q="$1" def="${2:-N}" ans
    if [ ! -t 0 ]; then
        [ "$def" = "Y" ] && return 0 || return 1
    fi
    local hint="[y/N]"; [ "$def" = "Y" ] && hint="[Y/n]"
    printf '%s %s ' "$q" "$hint"
    read -r ans || ans=""
    ans="${ans:-$def}"
    case "$ans" in [Yy]*) return 0;; *) return 1;; esac
}

# --- Parseo de flags -------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        -h|--help) usage 0 ;;
        *) err "Opción desconocida: $1"; usage 1 ;;
    esac
    shift
done

# ===========================================================================
# FASE 0 — Preflight
# ===========================================================================
step "Fase 0 · Preflight"
case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      OS="unknown" ;;
esac
info "Repo:   $REPO"
info "OS:     $OS"
info "Config: $CONFIG_HOME"
[ "$DRY_RUN" -eq 1 ] && warn "Modo --dry-run: no se modificará nada."

HAS_BREW=0
command -v brew >/dev/null 2>&1 && HAS_BREW=1

# ===========================================================================
# FASE 1 — Discovery de dependencias
# ===========================================================================
# Cada entrada: "cmd|descripción|método|receta"
#   método: brew | curl
#   receta: fórmula de brew, o comando curl completo
DEPS=(
    "zellij|Multiplexor de terminal|brew|zellij"
    "yazi|Explorador de archivos|brew|yazi"
    "ms|Editor Mitos (fork de Helix)|curl|curl -fsSL https://mitos.computer/install.sh | sh"
    "lazygit|Git TUI (pane)|brew|lazygit"
    "hx|Helix (editor alternativo, opcional)|brew|helix"
)

step "Fase 1 · Dependencias"
MISSING=()
for entry in "${DEPS[@]}"; do
    IFS='|' read -r cmd desc method recipe <<< "$entry"
    if command -v "$cmd" >/dev/null 2>&1; then
        path="$(command -v "$cmd")"
        ver="$("$cmd" --version 2>/dev/null | head -1 || true)"
        ok "$(printf '%-8s %s' "$cmd" "$C_DIM$path${ver:+ · $ver}$C_RESET")"
    else
        warn "$(printf '%-8s FALTA · %s' "$cmd" "$desc")"
        MISSING+=("$entry")
    fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    step "Instalación de faltantes"
    for entry in "${MISSING[@]}"; do
        IFS='|' read -r cmd desc method recipe <<< "$entry"
        if [ "$method" = "brew" ] && [ "$HAS_BREW" -eq 0 ]; then
            err "$cmd requiere Homebrew y brew no está instalado. Instálalo: https://brew.sh — se omite."
            continue
        fi
        local_recipe="$recipe"
        [ "$method" = "brew" ] && local_recipe="brew install $recipe"
        if ask_yn "¿Instalar ${C_BOLD}$cmd${C_RESET}? ($local_recipe)" N; then
            run "$local_recipe"
            command -v "$cmd" >/dev/null 2>&1 && ok "$cmd instalado." || warn "$cmd: verifica la instalación manualmente."
        else
            warn "$cmd: omitido por el usuario."
        fi
    done
fi

# ===========================================================================
# FASE 2 + 3 — Symlinks de config (discovery de estado + aplicar)
# ===========================================================================
# Cada entrada: "origen-relativo-al-repo|destino-absoluto"
LINKS=(
    "zellij/config.kdl|$CONFIG_HOME/zellij/config.kdl"
    "zellij/layouts/code.kdl|$CONFIG_HOME/zellij/layouts/code.kdl"
    "yazi/yazi.toml|$CONFIG_HOME/yazi/yazi.toml"
    "mitos/config.toml|$CONFIG_HOME/mitos/config.toml"
    "helix/config.toml|$CONFIG_HOME/helix/config.toml"
)

link_one() { # link_one <src-abs> <dst-abs>
    local src="$1" dst="$2" dstdir
    dstdir="$(dirname "$dst")"
    [ -d "$dstdir" ] || run "mkdir -p '$dstdir'"

    if [ -L "$dst" ]; then
        local cur; cur="$(readlink "$dst")"
        if [ "$cur" = "$src" ]; then
            ok "$(printf '%-40s ya enlazado' "${dst/#$HOME/~}")"
            return
        fi
        warn "$(printf '%-40s symlink ajeno → %s' "${dst/#$HOME/~}" "$cur")"
        if [ "$FORCE" -eq 1 ] || ask_yn "  ¿Reemplazar symlink?" N; then
            run "ln -sfn '$src' '$dst'"
            ok "  reemplazado."
        else
            warn "  omitido."
        fi
        return
    fi

    if [ -e "$dst" ]; then
        # Archivo o dir REAL: respaldar antes de tocar.
        warn "$(printf '%-40s config real existente' "${dst/#$HOME/~}")"
        if [ "$FORCE" -eq 1 ] || ask_yn "  ¿Respaldar y enlazar?" N; then
            run "mv '$dst' '$dst.bak.$STAMP'"
            run "ln -sfn '$src' '$dst'"
            ok "  respaldo en ${dst/#$HOME/~}.bak.$STAMP y enlazado."
        else
            warn "  omitido (tu config queda intacta)."
        fi
        return
    fi

    # No existe: enlace limpio.
    run "ln -sfn '$src' '$dst'"
    ok "$(printf '%-40s enlazado' "${dst/#$HOME/~}")"
}

step "Fase 2-3 · Symlinks de configuración"
for entry in "${LINKS[@]}"; do
    IFS='|' read -r rel dst <<< "$entry"
    src="$REPO/$rel"
    if [ ! -e "$src" ]; then
        err "No existe en el repo: $rel — se omite."
        continue
    fi
    link_one "$src" "$dst"
done

# ===========================================================================
# FASE 3b — Bloque del .zshrc (idempotente)
# ===========================================================================
step "Fase 3 · Bloque de shell en .zshrc"
BLOCK_SRC="$REPO/shell/workflow.zsh"
if [ ! -f "$BLOCK_SRC" ]; then
    err "No existe shell/workflow.zsh — se omite el bloque de shell."
elif [ -f "$ZSHRC" ] && grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
    # Ya existe el bloque: comprobar si cambió.
    if [ -f "$ZSHRC" ] && \
       awk "/^${MARK_BEGIN//\//\\/}$/{f=1} f{print} /^${MARK_END//\//\\/}$/{f=0}" "$ZSHRC" \
         | diff -q - "$BLOCK_SRC" >/dev/null 2>&1; then
        ok "Bloque t-workflow ya presente y actualizado en .zshrc."
    else
        warn "Bloque t-workflow presente pero DIFERENTE del repo."
        if [ "$FORCE" -eq 1 ] || ask_yn "  ¿Actualizar el bloque en .zshrc?" N; then
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '%s[dry-run]%s reemplazaría el bloque entre marcadores en %s\n' "$C_DIM" "$C_RESET" "$ZSHRC"
            else
                cp "$ZSHRC" "$ZSHRC.bak.$STAMP"
                # Borra el bloque viejo (inclusive marcadores) y anexa el nuevo.
                awk "/^${MARK_BEGIN//\//\\/}$/{s=1} !s{print} /^${MARK_END//\//\\/}$/{s=0}" \
                    "$ZSHRC.bak.$STAMP" > "$ZSHRC"
                printf '\n' >> "$ZSHRC"
                cat "$BLOCK_SRC" >> "$ZSHRC"
                ok "  bloque actualizado (respaldo en $ZSHRC.bak.$STAMP)."
            fi
        else
            warn "  omitido."
        fi
    fi
else
    # No existe el bloque: anexar.
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s anexaría shell/workflow.zsh a %s\n' "$C_DIM" "$C_RESET" "$ZSHRC"
    else
        [ -f "$ZSHRC" ] || : > "$ZSHRC"
        printf '\n' >> "$ZSHRC"
        cat "$BLOCK_SRC" >> "$ZSHRC"
        ok "Bloque t-workflow anexado a .zshrc."
    fi
fi

# ===========================================================================
# FASE 4 — Resumen
# ===========================================================================
step "Listo"
if [ "${#MISSING[@]}" -gt 0 ]; then
    warn "Revisa arriba las dependencias faltantes/omitidas."
fi
info "Siguiente paso:"
info "  ${C_DIM}source ~/.zshrc${C_RESET}   # recargar el shell (o abre una terminal nueva)"
info "  ${C_DIM}zj dev${C_RESET}           # sesión 'dev' con el layout 'code'"
