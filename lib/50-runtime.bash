
# ---------------------------------------------------------------------------
# Runtime / version modules -- shown only when the directory (or env) calls for it.
# Result is cached per (PWD, virtualenv, conda env) so the version commands run
# once when you cd into a project, not on every prompt.
# ---------------------------------------------------------------------------
__bga_runtime() {
    [ "${BASHGITAWARE_RUNTIME:-1}" = 0 ] && return
    local key="$PWD|${VIRTUAL_ENV:-}|${CONDA_DEFAULT_ENV:-}"
    if [ "$key" = "${_bga_rt_key:-}" ]; then printf '%s' "${_bga_rt_str:-}"; return; fi
    _bga_rt_key="$key"; _bga_rt_str=""
    local out="" v f s

    # --- Python: an active virtualenv / conda env, or a Python project marker ---
    local pyenv=""
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        pyenv="${VIRTUAL_ENV##*/}"
        case "$pyenv" in
            .venv | venv | env | .env | virtualenv | .virtualenv)
                local _vp="${VIRTUAL_ENV%/*}"; pyenv="${_vp##*/}" ;;
        esac
    elif [ -n "${CONDA_DEFAULT_ENV:-}" ] && [ "${CONDA_DEFAULT_ENV}" != base ]; then
        pyenv="conda:${CONDA_DEFAULT_ENV}"
    fi
    if [ -n "$pyenv" ] || [ -e "$PWD/pyproject.toml" ] || [ -e "$PWD/setup.py" ] \
       || [ -e "$PWD/setup.cfg" ] || [ -e "$PWD/requirements.txt" ] || [ -e "$PWD/Pipfile" ] \
       || [ -e "$PWD/.python-version" ]; then
        v=""
        [ -r "$PWD/.python-version" ] && IFS= read -r v < "$PWD/.python-version" 2>/dev/null
        if [ -z "$v" ]; then
            if   command -v python3 >/dev/null 2>&1; then v="$(python3 --version 2>&1)"
            elif command -v python  >/dev/null 2>&1; then v="$(python --version 2>&1)"; fi
            v="${v#Python }"; v="${v%% *}"
        fi
        s="python"; [ -n "$v" ] && s="python $v"; [ -n "$pyenv" ] && s="$s ($pyenv)"
        out="$out ${_c_dim}via ${_R}${_c_py}${s}${_R}"
    fi

    # --- Node: a package.json in the current directory ---
    if [ -e "$PWD/package.json" ]; then
        v=""
        for f in .nvmrc .node-version; do
            [ -r "$PWD/$f" ] && { IFS= read -r v < "$PWD/$f" 2>/dev/null; v="${v#v}"; break; }
        done
        [ -z "$v" ] && command -v node >/dev/null 2>&1 && { v="$(node --version 2>/dev/null)"; v="${v#v}"; }
        s="node"; [ -n "$v" ] && s="node $v"
        out="$out ${_c_dim}via ${_R}${_c_node}${s}${_R}"
    fi

    # --- Rust: a Cargo.toml in the current directory ---
    if [ -e "$PWD/Cargo.toml" ]; then
        v=""; command -v rustc >/dev/null 2>&1 && { v="$(rustc --version 2>/dev/null)"; v="${v#rustc }"; v="${v%% *}"; }
        s="rust"; [ -n "$v" ] && s="rust $v"
        out="$out ${_c_dim}via ${_R}${_c_rust}${s}${_R}"
    fi

    # --- Go: a go.mod in the current directory ---
    if [ -e "$PWD/go.mod" ]; then
        v=""; command -v go >/dev/null 2>&1 && { v="$(go env GOVERSION 2>/dev/null)"; v="${v#go}"; }
        s="go"; [ -n "$v" ] && s="go $v"
        out="$out ${_c_dim}via ${_R}${_c_go}${s}${_R}"
    fi

    _bga_rt_str="$out"
    printf '%s' "$out"
}
