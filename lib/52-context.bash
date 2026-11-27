
# ---------------------------------------------------------------------------
# Context segments (3.2, SPEC X1; ADR-0014), opt-in with contexts =
# kube,aws,tf. Sets _bga_ctx_items ("token|label", like _bga_rt_items) and
# _bga_ctx_str (the classic-layout text). No program runs: kubectl, aws and
# terraform are never called.
#   kube  current-context of the first file in $KUBECONFIG (or
#         ~/.kube/config); reread only when the file is newer than a marker
#         in the state directory.
#   aws   $AWS_PROFILE, else $AWS_VAULT.
#   tf    the workspace in ./.terraform/environment. It comes from the
#         repository, so it is read with the version-file rules (no symlink
#         out of the repository, NUL-safe, version-like value).
# ---------------------------------------------------------------------------
_bga_ctx_items=() _bga_ctx_str='' _bga_kube_file='' _bga_kube_ctx=''

# True if context $1 is listed in BASHGITAWARE_CONTEXTS.
__bga_ctx_on() {
    case ",${BASHGITAWARE_CONTEXTS:-}," in *",$1,"*) return 0 ;; esac
    return 1
}

# Shorten label text $1 to at most 40 characters (keeping the end, which is
# the distinctive part of names such as EKS ARNs) into REPLY.
__bga_ctx_short() {
    REPLY="$1"
    [ "${#REPLY}" -le 40 ] || REPLY="…${REPLY: -39}"
}

# current-context from kubeconfig file $1 into _bga_kube_ctx. One bounded
# read (64 KB, NUL-terminated); the file is parsed as data.
__bga_kube_read() {
    local buf line v
    _bga_kube_ctx=''
    [ -f "$1" ] && [ -r "$1" ] || return 0
    IFS= read -r -d '' -n 65536 buf < "$1" 2>/dev/null
    while [ -n "$buf" ]; do
        line="${buf%%$'\n'*}"
        if [ "$line" = "$buf" ]; then buf=''; else buf="${buf#*$'\n'}"; fi
        case "$line" in
            current-context:*)
                v="${line#current-context:}"; v="${v%$'\r'}"
                v="${v#"${v%%[![:blank:]]*}"}"; v="${v%"${v##*[![:blank:]]}"}"
                case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; \'*\') v="${v#\'}"; v="${v%\'}" ;; esac
                _bga_kube_ctx="$v"; return 0 ;;
        esac
    done
}

__bga_context() {
    _bga_ctx_items=() _bga_ctx_str=''
    [ -n "${BASHGITAWARE_CONTEXTS:-}" ] || return 0
    local REPLY v f
    if __bga_ctx_on kube; then
        f="${KUBECONFIG:-$HOME/.kube/config}"; f="${f%%:*}"
        local mark="${_bga_state_dir:+$_bga_state_dir/kube.mark}"
        if [ "$f" != "$_bga_kube_file" ] || [ -z "$mark" ] || [ ! -e "$mark" ] || [ "$f" -nt "$mark" ]; then
            __bga_kube_read "$f"
            _bga_kube_file="$f"
            # `: >` sets the marker's mtime to now without a fork.
            [ -n "$mark" ] && : > "$mark" 2>/dev/null
        fi
        if [ -n "$_bga_kube_ctx" ]; then __bga_ctx_short "$_bga_kube_ctx"; __bga_ctx_add kube "k8s $REPLY"; fi
    fi
    if __bga_ctx_on aws; then
        v="${AWS_PROFILE:-${AWS_VAULT:-}}"
        if [ -n "$v" ]; then __bga_ctx_short "$v"; __bga_ctx_add aws "aws $REPLY"; fi
    fi
    if __bga_ctx_on tf && __bga_read_version "$PWD/.terraform/environment"; then
        __bga_ctx_add tf "tf $REPLY"
    fi
    return 0
}

# Add context $1 (token) with label $2 to the Lean items and classic string.
__bga_ctx_add() {
    local REPLY tok="_c_$1"
    _bga_ctx_items+=("$1|$2")
    __bga_ps1_lit "$2"; _bga_ctx_str+=" ${_c_dim}[${_R}${!tok}${REPLY}${_c_dim}]${_R}"
}
