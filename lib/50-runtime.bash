
# ---------------------------------------------------------------------------
# Runtime / version modules -- shown only when the directory (or env) calls for it.
# Result is cached per (PWD, virtualenv, conda env) so the version commands run
# once when you cd into a project, not on every prompt. Sets _bga_rt_str (the
# PS1 text for the classic layout) and _bga_rt_items (raw labels, one per
# runtime, for the Lean right block). It prints nothing: calling it in $(...)
# would lose the cache, which lives in these globals.
# ---------------------------------------------------------------------------
# Reset together: a re-source (bga reload) must not keep a key whose items
# were just cleared, or the cache would "hit" with no runtimes.
_bga_rt_items=() _bga_rt_key='' _bga_rt_str=''
__bga_runtime() {
    if [ "${BASHGITAWARE_RUNTIME:-1}" = 0 ]; then _bga_rt_str=''; _bga_rt_items=(); return; fi
    # promptvars is part of the key: the cached string is escaped for it.
    local pv=0; shopt -q promptvars && pv=1
    local key="$PWD|${VIRTUAL_ENV:-}|${CONDA_DEFAULT_ENV:-}|$pv"
    [ "$key" = "${_bga_rt_key:-}" ] && return
    _bga_rt_key="$key"; _bga_rt_str=""; _bga_rt_items=()
    local out="" v f s REPLY

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
        __bga_read_line "$PWD/.python-version" && v="$REPLY"
        if [ -z "$v" ]; then
            if   command -v python3 >/dev/null 2>&1; then v="$(python3 --version 2>&1)"
            elif command -v python  >/dev/null 2>&1; then v="$(python --version 2>&1)"; fi
            v="${v#Python }"; v="${v%% *}"
        fi
        s="python"; [ -n "$v" ] && s="python $v"; [ -n "$pyenv" ] && s="$s ($pyenv)"
        _bga_rt_items+=("py|$s")
        __bga_ps1_lit "$s"; out="$out ${_c_dim}via ${_R}${_c_py}${REPLY}${_R}"
    fi

    # --- Node: a package.json in the current directory ---
    if [ -e "$PWD/package.json" ]; then
        v=""
        for f in .nvmrc .node-version; do
            __bga_read_line "$PWD/$f" && { v="${REPLY#v}"; break; }
        done
        [ -z "$v" ] && command -v node >/dev/null 2>&1 && { v="$(node --version 2>/dev/null)"; v="${v#v}"; }
        s="node"; [ -n "$v" ] && s="node $v"
        _bga_rt_items+=("node|$s")
        __bga_ps1_lit "$s"; out="$out ${_c_dim}via ${_R}${_c_node}${REPLY}${_R}"
    fi

    # --- Rust: a Cargo.toml in the current directory ---
    if [ -e "$PWD/Cargo.toml" ]; then
        v=""; command -v rustc >/dev/null 2>&1 && { v="$(rustc --version 2>/dev/null)"; v="${v#rustc }"; v="${v%% *}"; }
        s="rust"; [ -n "$v" ] && s="rust $v"
        _bga_rt_items+=("rust|$s")
        __bga_ps1_lit "$s"; out="$out ${_c_dim}via ${_R}${_c_rust}${REPLY}${_R}"
    fi

    # --- Go: a go.mod in the current directory ---
    if [ -e "$PWD/go.mod" ]; then
        v=""; command -v go >/dev/null 2>&1 && { v="$(go env GOVERSION 2>/dev/null)"; v="${v#go}"; }
        s="go"; [ -n "$v" ] && s="go $v"
        _bga_rt_items+=("go|$s")
        __bga_ps1_lit "$s"; out="$out ${_c_dim}via ${_R}${_c_go}${REPLY}${_R}"
    fi

    _bga_rt_str="$out"
}
