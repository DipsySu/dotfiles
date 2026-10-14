#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
helper="$script_dir/scripts/ensure-ai-clis.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/test-ai-clis.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [ -e "$1" ] || [ -L "$1" ] || fail "missing $1"; }
assert_same() { cmp -s "$1" "$2" || fail "changed $1"; }

make_fake_curl() {
    mkdir -p "$1/bin"
    cat > "$1/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
out= url=
while [ "$#" -gt 0 ]; do
  case "$1" in -o) out=$2; shift 2;; http*) url=$1; shift;; *) shift;; esac
done
printf '%s\n' "$url" >> "$FIXTURE_LOG"
[ "${FAIL_DOWNLOAD:-}" = "$url" ] && exit 22
case "$url" in
  *chatgpt.com*) vendor=codex;; *claude.ai*) vendor=claude;; *antigravity.google*) vendor=agy;; *x.ai*) vendor=grok;; *) exit 23;;
esac
if [ "$vendor" = agy ] && [ "${BAD_AGY:-}" = 1 ]; then
  printf '%s\n' '#!/bin/bash' 'echo unexpected > "$HOME/agy-ran"' > "$out"
  exit 0
fi
if [ "$vendor" = agy ]; then
  cat > "$out" <<'EOF2'
#!/bin/bash
BINARY_PATH="$HOME/.local/bin/agy"
CUSTOM_DIR=""
if [ "${1:-}" = --dir ]; then CUSTOM_DIR="$2"; fi
mkdir -p "$HOME/.local/bin"
cat > "$BINARY_PATH" <<'AGYBIN'
#!/bin/bash
printf 'agy args=%s\n' "$*" >> "$FIXTURE_LOG"
AGYBIN
chmod +x "$BINARY_PATH"
if [ -n "$CUSTOM_DIR" ]; then
    "$BINARY_PATH" install --dir "$CUSTOM_DIR" || true
else
    "$BINARY_PATH" install || true
fi
EOF2
  exit 0
fi
cat > "$out" <<EOF2
#!/bin/bash
mkdir -p "\$HOME/.local/bin" "\$HOME/.grok/bin"
printf 'vendor=$vendor codex=%s grok-shell=%s grok-channel=%s grok-dir=%s grok-path=%s\n' "\${CODEX_NON_INTERACTIVE:-}" "\${SHELL-}" "\${GROK_CHANNEL:-}" "\${GROK_BIN_DIR:-}" "\${PATH:-}" >> "\$FIXTURE_LOG"
[ "\${NO_ENTRY:-}" = "$vendor" ] && exit 0
case "$vendor" in
  codex) printf vendor-%s > "\$HOME/.zshrc"; printf '#!/bin/bash\nexit 0\n' > "\$HOME/.local/bin/codex"; chmod +x "\$HOME/.local/bin/codex" ;;
  claude) mkdir -p "\$HOME/.claude"; printf '{"model":"opus[1m]"}' > "\$HOME/.claude/settings.json"; [ "\${FAIL_INSTALL:-}" = claude ] && exit 9; printf '#!/bin/bash\nexit 0\n' > "\$HOME/.local/bin/claude"; chmod +x "\$HOME/.local/bin/claude" ;;
  agy) printf '#!/bin/bash\nexit 0\n' > "\$HOME/.local/bin/agy"; chmod +x "\$HOME/.local/bin/agy" ;;
  grok) printf '#!/bin/bash\nexit 0\n' > "\$HOME/.grok/bin/grok"; chmod +x "\$HOME/.grok/bin/grok"; ln -sf grok "\$HOME/.grok/bin/agent" ;;
esac
EOF2
EOF
    chmod +x "$1/bin/curl"
}

run_helper() { HOME="$1/home" FIXTURE_LOG="$1/curl.log" PATH="$1/bin:$PATH" /bin/bash "$helper"; }

# Existing native entries win over a stale mise shim; only missing shell links repair.
case1="$fixture_root/existing"; mkdir -p "$case1/home/.local/bin" "$case1/home/.grok/bin" "$case1/mise"
make_fake_curl "$case1"
for x in codex claude agy; do printf '#!/bin/bash\n' > "$case1/home/.local/bin/$x"; chmod +x "$case1/home/.local/bin/$x"; done
printf '#!/bin/bash\n' > "$case1/home/.grok/bin/grok"; chmod +x "$case1/home/.grok/bin/grok"
printf '#!/bin/bash\n' > "$case1/mise/codex"; chmod +x "$case1/mise/codex"
PATH="$case1/mise:$PATH" run_helper "$case1"
[ ! -s "$case1/curl.log" ] || fail 'existing entries downloaded an installer'
assert_file "$case1/home/.grok/bin/agent"; assert_file "$case1/home/.local/bin/grok"; assert_file "$case1/home/.local/bin/agent"

# Broken Grok links are repaired without downloading, while usable user-owned
# entries (including a non-Grok symlink) remain untouched across repeat runs.
case1b="$fixture_root/grok-links"; mkdir -p "$case1b/home/.local/bin" "$case1b/home/.grok/bin"
make_fake_curl "$case1b"
for x in codex claude agy; do printf '#!/bin/bash\n' > "$case1b/home/.local/bin/$x"; chmod +x "$case1b/home/.local/bin/$x"; done
printf '#!/bin/bash\nexit 0\n' > "$case1b/home/.grok/bin/grok"; chmod +x "$case1b/home/.grok/bin/grok"
ln -s nowhere "$case1b/home/.grok/bin/agent"
ln -s nowhere "$case1b/home/.local/bin/grok"
ln -s nowhere "$case1b/home/.local/bin/agent"
run_helper "$case1b"
[ "$(readlink "$case1b/home/.grok/bin/agent")" = grok ] || fail 'broken Grok agent link was not repaired'
[ "$(readlink "$case1b/home/.local/bin/grok")" = "$case1b/home/.grok/bin/grok" ] || fail 'broken Grok shell link was not repaired'
[ "$(readlink "$case1b/home/.local/bin/agent")" = "$case1b/home/.grok/bin/agent" ] || fail 'broken Grok agent shell link was not repaired'
run_helper "$case1b"
[ ! -s "$case1b/curl.log" ] || fail 'Grok link repair downloaded an installer'

case1c="$fixture_root/grok-user-entries"; mkdir -p "$case1c/home/.local/bin" "$case1c/home/.grok/bin"
make_fake_curl "$case1c"
for x in codex claude agy; do printf '#!/bin/bash\n' > "$case1c/home/.local/bin/$x"; chmod +x "$case1c/home/.local/bin/$x"; done
printf '#!/bin/bash\nexit 0\n' > "$case1c/home/.grok/bin/grok"; chmod +x "$case1c/home/.grok/bin/grok"
printf '#!/bin/bash\nexit 0\n' > "$case1c/home/custom-agent"; chmod +x "$case1c/home/custom-agent"
ln -s "$case1c/home/custom-agent" "$case1c/home/.grok/bin/agent"
ln -s "$case1c/home/custom-agent" "$case1c/home/.local/bin/grok"
ln -s "$case1c/home/custom-agent" "$case1c/home/.local/bin/agent"
run_helper "$case1c"
for link in "$case1c/home/.grok/bin/agent" "$case1c/home/.local/bin/grok" "$case1c/home/.local/bin/agent"; do
    [ "$(readlink "$link")" = "$case1c/home/custom-agent" ] || fail "overwrote usable user entry $link"
done
[ ! -s "$case1c/curl.log" ] || fail 'usable user entries downloaded an installer'

# Missing tools use only the documented URLs, protect profiles/settings, and create entries.
case2="$fixture_root/missing"; mkdir -p "$case2/home/.claude"
make_fake_curl "$case2"
for p in .zprofile .zshrc .bash_profile .bashrc .profile; do printf 'original-%s\n' "$p" > "$case2/home/$p"; cp "$case2/home/$p" "$case2/$p.before"; done
printf 'linked-profile\n' > "$case2/home/zshrc-target"
rm -f "$case2/home/.zshrc"
ln -s zshrc-target "$case2/home/.zshrc"
cp "$case2/home/zshrc-target" "$case2/.zshrc.before"
printf '{"model":"opus"}' > "$case2/home/.claude/settings.json"; cp "$case2/home/.claude/settings.json" "$case2/settings.before"
run_helper "$case2"
for x in codex claude agy; do assert_file "$case2/home/.local/bin/$x"; done
assert_file "$case2/home/.grok/bin/grok"; assert_file "$case2/home/.grok/bin/agent"
for p in .zprofile .zshrc .bash_profile .bashrc .profile; do assert_same "$case2/home/$p" "$case2/$p.before"; done
[ -L "$case2/home/.zshrc" ] || fail 'profile symlink identity was not restored'
[ "$(readlink "$case2/home/.zshrc")" = zshrc-target ] || fail 'profile symlink target changed'
assert_same "$case2/home/.claude/settings.json" "$case2/settings.before"
grep -qx 'https://chatgpt.com/codex/install.sh' "$case2/curl.log" || fail 'missing Codex URL'
grep -qx 'https://claude.ai/install.sh' "$case2/curl.log" || fail 'missing Claude URL'
grep -qx 'https://antigravity.google/cli/install.sh' "$case2/curl.log" || fail 'missing AGY URL'
grep -qx 'https://x.ai/cli/install.sh' "$case2/curl.log" || fail 'missing Grok URL'
grep -q '^vendor=codex codex=1 ' "$case2/curl.log" || fail 'missing Codex non-interactive env'
grep -qx "agy args=install --dir $case2/home/.local/bin --skip-path --skip-aliases" "$case2/curl.log" || fail 'missing AGY setup flags'
grep -q "^vendor=grok codex= grok-shell= grok-channel=stable grok-dir=$case2/home/.grok/bin grok-path=$case2/home/.grok/bin:" "$case2/curl.log" || fail 'missing Grok isolated env'

# A failed vendor leaves protected files intact and causes a non-zero result.
case3="$fixture_root/failure"; mkdir -p "$case3/home/.claude"; make_fake_curl "$case3"
printf 'keep\n' > "$case3/home/.zshrc"; cp "$case3/home/.zshrc" "$case3/zshrc.before"
printf '{"model":"opus"}' > "$case3/home/.claude/settings.json"; cp "$case3/home/.claude/settings.json" "$case3/settings.before"
if FAIL_INSTALL=claude run_helper "$case3"; then fail 'installer failure returned success'; fi
assert_same "$case3/home/.zshrc" "$case3/zshrc.before"; assert_same "$case3/home/.claude/settings.json" "$case3/settings.before"

# Changed AGY handoff layout must not execute the downloaded script.
case4="$fixture_root/bad-agy"; mkdir -p "$case4/home/.local/bin" "$case4/home/.grok/bin"; make_fake_curl "$case4"
for x in codex claude; do printf '#!/bin/bash\n' > "$case4/home/.local/bin/$x"; chmod +x "$case4/home/.local/bin/$x"; done
printf '#!/bin/bash\n' > "$case4/home/.grok/bin/grok"; chmod +x "$case4/home/.grok/bin/grok"
if BAD_AGY=1 run_helper "$case4"; then fail 'unknown AGY layout returned success'; fi
[ ! -e "$case4/home/agy-ran" ] || fail 'unknown AGY installer executed'

# A zero-exit installer is insufficient unless it produced the required entry.
case5="$fixture_root/no-entry"; mkdir -p "$case5/home/.local/bin" "$case5/home/.grok/bin"; make_fake_curl "$case5"
for x in claude agy; do printf '#!/bin/bash\n' > "$case5/home/.local/bin/$x"; chmod +x "$case5/home/.local/bin/$x"; done
printf '#!/bin/bash\n' > "$case5/home/.grok/bin/grok"; chmod +x "$case5/home/.grok/bin/grok"
if NO_ENTRY=codex run_helper "$case5"; then fail 'zero-exit installer without entry returned success'; fi

# A restore error retains the recovery snapshot instead of deleting the only copy.
case6="$fixture_root/restore-failure"; mkdir -p "$case6/home/.local/bin" "$case6/home/.grok/bin" "$case6/tmp"; make_fake_curl "$case6"
cat > "$case6/bin/cp" <<'EOF'
#!/bin/bash
src=${@: -2:1}; dest=${@: -1}
if [ "${FAIL_RESTORE:-}" = 1 ] && [[ "$src" == */profiles.*/* ]] && [ "$dest" = "$HOME/.zshrc" ]; then exit 1; fi
exec /bin/cp "$@"
EOF
chmod +x "$case6/bin/cp"
printf 'keep\n' > "$case6/home/.zshrc"
for x in claude agy; do printf '#!/bin/bash\n' > "$case6/home/.local/bin/$x"; chmod +x "$case6/home/.local/bin/$x"; done
printf '#!/bin/bash\n' > "$case6/home/.grok/bin/grok"; chmod +x "$case6/home/.grok/bin/grok"
if FAIL_RESTORE=1 TMPDIR="$case6/tmp" run_helper "$case6" > "$case6/output" 2>&1; then fail 'restore failure returned success'; fi
snapshot=$(sed -n 's/^Preserving AI CLI recovery snapshot at //p' "$case6/output" | tail -1)
[ -n "$snapshot" ] && [ -d "$snapshot" ] || fail 'restore failure did not retain snapshot'

printf '%s\n' 'PASS: AI CLI helper fixtures'
