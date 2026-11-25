
# ---------------------------------------------------------------------------
# Runtime / version modules -- shown only when the directory (or env) calls for it.
# BASHGITAWARE_RUNTIMES (comma list) picks which ones; default all. Ruby, Deno,
# Bun and Java read version files only and never run the tool (3.1, SPEC S6).
# Result is cached per (PWD, virtualenv, conda env) so the version commands run
# once when you cd into a project, not on every prompt. Sets _bga_rt_str (the
# PS1 text for the classic layout) and _bga_rt_items (raw labels, one per
# runtime, for the Lean right block). It prints nothing: calling it in $(...)
# would lose the cache, which lives in these globals.
# ---------------------------------------------------------------------------
# Reset together: a re-source (bga reload) must not keep a key whose items
# were just cleared, or the cache would "hit" with no runtimes.
_bga_rt_items=() _bga_rt_key='' _bga_rt_str=''

# True if runtime $1 is enabled (BASHGITAWARE_RUNTIMES unset or lists it).
__bga_rt_on() {
    [ -z "${BASHGITAWARE_RUNTIMES:-}" ] && return 0
    case ",$BASHGITAWARE_RUNTIMES," in *",$1,"*) return 0 ;; esac
    return 1
}

# Add runtime $1 (token) with label $2 to the Lean items and classic string.
__bga_rt_add() {
    local REPLY tok="_c_$1"
    _bga_rt_items+=("$1|$2")
    __bga_ps1_lit "$2"; _bga_rt_str+=" ${_c_dim}via ${_R}${!tok}${REPLY}${_R}"
}

# Value of "key=value" line $2 in file $1 (first 50 lines of the first 12 KB;
# one bounded read, NUL-terminated as in __bga_read_line) into REPLY, checked
# like a version file value. Plain reads: the file is never sourced.
__bga_rt_kv() {
    local buf line n=0 v
    REPLY=''
    __bga_link_inside "$1" || return 1
    [ -f "$1" ] && [ -r "$1" ] || return 1
    IFS= read -r -d '' -n 12288 buf < "$1" 2>/dev/null
    while [ -n "$buf" ] && [ "$n" -lt 50 ]; do
        line="${buf%%$'\n'*}"
        if [ "$line" = "$buf" ]; then buf=''; else buf="${buf#*$'\n'}"; fi
        n=$(( n + 1 )); line="${line%$'\r'}"
        case "$line" in
            "$2="*)
                v="${line#"$2="}"
                local LC_ALL=C
                [ -n "$v" ] && [ "${#v}" -le 32 ] || return 1
                case "$v" in *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+@/:-]*) return 1 ;; esac
                REPLY="$v"; return 0 ;;
        esac
    done
    return 1
}

__bga_runtime() {
    if [ "${BASHGITAWARE_RUNTIME:-1}" = 0 ]; then _bga_rt_str=''; _bga_rt_items=(); return; fi
    # promptvars is part of the key: the cached string is escaped for it.
    local pv=0; shopt -q promptvars && pv=1
    local key="$PWD|${VIRTUAL_ENV:-}|${CONDA_DEFAULT_ENV:-}|$pv|${BASHGITAWARE_RUNTIMES:-}"
    [ "$key" = "${_bga_rt_key:-}" ] && return
    _bga_rt_key="$key"; _bga_rt_str=""; _bga_rt_items=()
    local v f s REPLY

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
    if __bga_rt_on py && { [ -n "$pyenv" ] || [ -e "$PWD/pyproject.toml" ] || [ -e "$PWD/setup.py" ] \
       || [ -e "$PWD/setup.cfg" ] || [ -e "$PWD/requirements.txt" ] || [ -e "$PWD/Pipfile" ] \
       || [ -e "$PWD/.python-version" ]; }; then
        v=""
        __bga_read_version "$PWD/.python-version" && v="$REPLY"
        if [ -z "$v" ]; then
            if   command -v python3 >/dev/null 2>&1; then v="$(python3 --version 2>&1)"
            elif command -v python  >/dev/null 2>&1; then v="$(python --version 2>&1)"; fi
            v="${v#Python }"; v="${v%% *}"
        fi
        s="python"; [ -n "$v" ] && s="python $v"; [ -n "$pyenv" ] && s="$s ($pyenv)"
        __bga_rt_add py "$s"
    fi

    # --- Node: a package.json in the current directory ---
    if __bga_rt_on node && [ -e "$PWD/package.json" ]; then
        v=""
        for f in .nvmrc .node-version; do
            __bga_read_version "$PWD/$f" && { v="${REPLY#v}"; break; }
        done
        [ -z "$v" ] && command -v node >/dev/null 2>&1 && { v="$(node --version 2>/dev/null)"; v="${v#v}"; }
        s="node"; [ -n "$v" ] && s="node $v"
        __bga_rt_add node "$s"
    fi

    # --- Rust: a Cargo.toml in the current directory ---
    if __bga_rt_on rust && [ -e "$PWD/Cargo.toml" ]; then
        v=""; command -v rustc >/dev/null 2>&1 && { v="$(rustc --version 2>/dev/null)"; v="${v#rustc }"; v="${v%% *}"; }
        s="rust"; [ -n "$v" ] && s="rust $v"
        __bga_rt_add rust "$s"
    fi

    # --- Go: a go.mod in the current directory ---
    if __bga_rt_on go && [ -e "$PWD/go.mod" ]; then
        v=""; command -v go >/dev/null 2>&1 && { v="$(go env GOVERSION 2>/dev/null)"; v="${v#go}"; }
        s="go"; [ -n "$v" ] && s="go $v"
        __bga_rt_add go "$s"
    fi

    # --- Ruby: .ruby-version or a Gemfile (version file only) ---
    if __bga_rt_on ruby && { [ -e "$PWD/.ruby-version" ] || [ -e "$PWD/Gemfile" ]; }; then
        __bga_read_version "$PWD/.ruby-version"; v="${REPLY#ruby-}"
        s="ruby"; [ -n "$v" ] && s="ruby $v"
        __bga_rt_add ruby "$s"
    fi

    # --- Deno: deno.json(c) (no version file convention) ---
    if __bga_rt_on deno && { [ -e "$PWD/deno.json" ] || [ -e "$PWD/deno.jsonc" ]; }; then
        __bga_rt_add deno deno
    fi

    # --- Bun: a lockfile or bunfig.toml ---
    if __bga_rt_on bun && { [ -e "$PWD/bun.lockb" ] || [ -e "$PWD/bun.lock" ] || [ -e "$PWD/bunfig.toml" ]; }; then
        __bga_rt_add bun bun
    fi

    # --- Java: .java-version (jenv) or java=... in .sdkmanrc ---
    if __bga_rt_on java && { [ -e "$PWD/.java-version" ] || [ -e "$PWD/.sdkmanrc" ]; }; then
        v=''
        if __bga_read_version "$PWD/.java-version"; then v="$REPLY"
        elif __bga_rt_kv "$PWD/.sdkmanrc" java; then v="$REPLY"; fi
        s="java"; [ -n "$v" ] && s="java $v"
        __bga_rt_add java "$s"
    fi
}
