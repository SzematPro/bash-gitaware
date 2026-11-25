#!/bin/sh
# tests/policy-fixtures.sh -- root-owned policy files for tests/policy.sh.
#
# Run as root before the suite (CI does it before switching to the test
# user). Without these fixtures the policy tests are skipped, not failed.
# POSIX sh: the bash:* images run it before bash is the login shell.
set -eu
[ "$(id -u)" = 0 ] || { echo "policy-fixtures: must run as root" >&2; exit 1; }

# Under /etc: hosted runners grant their user ACL write access on /opt, which
# would (correctly) make every fixture untrusted. On macOS /etc is a
# root-owned symlink to /private/etc, which the trust check must accept.
b=/etc/bga-policy-test
rm -rf "$b"
mkdir -p "$b"
chmod 755 "$b"

mk() {  # mk <dir> <mode> <content>
    mkdir -p "$b/$1"; chmod 755 "$b/$1"
    printf '%s' "$3" > "$b/$1/policy"; chmod "$2" "$b/$1/policy"
}

mk ok 644 'theme = contrast
glyphs = ascii
'
mk badlines 644 '# comment
theme = contrast
bogus = 1
glyphs = sparkly
no equals here
'
mk gw 664 'theme = contrast
'
# Root-only readable (a umask 077 mistake): refused, not half applied.
mk unreadable 600 'theme = contrast
'
# A directory others can write: anyone could swap the file.
mk dirw 644 'theme = contrast
'
chmod 777 "$b/dirw"
# The policy itself a symlink (to a good file): refused.
mkdir -p "$b/link"; chmod 755 "$b/link"
ln -s "$b/ok/policy" "$b/link/policy"
# A root-owned symlinked directory on the path (like macOS /etc): accepted.
ln -s "$b/ok" "$b/alias"
# A FIFO: must be refused without blocking.
mkdir -p "$b/fifo"; chmod 755 "$b/fifo"
mkfifo "$b/fifo/policy"; chmod 644 "$b/fifo/policy"

chown -R 0:0 "$b"

# An ACL entry granting write to another user: refused. Only where ACLs can
# be set (setfacl on Linux, chmod +a on macOS); tests skip it otherwise.
mk acl 644 'theme = contrast
'
chown 0:0 "$b/acl" "$b/acl/policy"
if command -v setfacl >/dev/null 2>&1 && setfacl -m u:nobody:rw "$b/acl/policy" 2>/dev/null; then :
elif [ "$(uname -s)" = Darwin ] && chmod +a "everyone allow write" "$b/acl/policy" 2>/dev/null; then :
else rm -rf "$b/acl"
fi
echo "policy-fixtures: created under $b"
