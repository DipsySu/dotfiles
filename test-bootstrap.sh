#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
chezmoi_bin="$(command -v chezmoi)"
tmpdir="$(mktemp -d /tmp/dotfiles-bootstrap-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT
fakebin="$tmpdir/bin"
logdir="$tmpdir/log"
mkdir -p "$fakebin" "$logdir"

render_bootstrap() {
    local bootstrap=$1 android=$2 output=$3
    local config="$tmpdir/config-$bootstrap-$android.yaml"
    cp "$source_dir/.chezmoi.yaml.example" "$config"
    cat >>"$config" <<EOF
  bootstrap_packages: $bootstrap
  enable_android: $android
EOF
    "$chezmoi_bin" --source "$source_dir" --config "$config" execute-template --file \
        "$source_dir/run_once_install-packages.sh.tmpl" >"$output"
    bash -n "$output"
}

cat >"$fakebin/curl" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-s" ]; then exit 0; fi
printf '%s\n' '#!/bin/bash'
EOF
cat >"$fakebin/git" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$fakebin/brew" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG/brew.args"
for arg in "$@"; do case "$arg" in --file=*) cp "${arg#--file=}" "$TEST_LOG/Brewfile.used";; esac; done
if [ "${FAKE_BREW_FAIL:-0}" = 1 ] && [ "${1:-}" = bundle ]; then exit 7; fi
exit 0
EOF
cat >"$fakebin/mise" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG/mise.args"
[ "${FAKE_MISE_FAIL:-0}" = 1 ] && [ "${1:-}" = install ] && exit 8
exit 0
EOF
cat >"$fakebin/git-lfs" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fakebin/curl" "$fakebin/git" "$fakebin/brew" "$fakebin/mise" "$fakebin/git-lfs"

render_bootstrap false false "$tmpdir/bootstrap-false.sh"
mkdir -p "$tmpdir/home-false"
TEST_LOG="$logdir" HOME="$tmpdir/home-false" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh \
    bash "$tmpdir/bootstrap-false.sh" >"$logdir/false.out"
[ ! -e "$logdir/brew.args" ] && [ ! -e "$logdir/mise.args" ]

render_bootstrap true false "$tmpdir/bootstrap-true.sh"
mkdir -p "$tmpdir/home-true"
if TEST_LOG="$logdir" HOME="$tmpdir/home-true" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh FAKE_BREW_FAIL=1 \
    bash "$tmpdir/bootstrap-true.sh" >"$logdir/brew-failure.out" 2>&1; then
    echo "expected failed Brew bootstrap to return non-zero" >&2; exit 1
fi
grep -q -- '--no-upgrade' "$logdir/brew.args"
! grep -q 'android-commandlinetools' "$logdir/Brewfile.used" || exit 1

rm -f "$logdir/brew.args" "$logdir/mise.args"
if TEST_LOG="$logdir" HOME="$tmpdir/home-true" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh FAKE_MISE_FAIL=1 \
    bash "$tmpdir/bootstrap-true.sh" >"$logdir/mise-failure.out" 2>&1; then
    echo "expected failed Mise bootstrap to return non-zero" >&2; exit 1
fi
grep -qx 'install' "$logdir/mise.args"

# A real chezmoi apply in an isolated source/destination must back up the
# pre-existing file before it is replaced, and the run-once script must not
# create another backup on a second apply.
backup_source="$tmpdir/backup-source"
backup_home="$tmpdir/backup-home"
backup_state="$tmpdir/backup-state"
backup_config_home="$tmpdir/backup-xdg-config"
backup_cache_home="$tmpdir/backup-xdg-cache"
backup_persistent_state="$tmpdir/backup-persistent-state.db"
backup_config="$tmpdir/backup-config.yaml"
mkdir -p "$backup_source" "$backup_home" "$backup_state" "$backup_config_home" "$backup_cache_home"
cp "$source_dir/run_once_before_00-backup-config.sh.tmpl" "$backup_source/"
printf '%s\n' 'managed configuration' >"$backup_source/dot_zshrc"
printf '%s\n' 'original configuration' >"$backup_home/.zshrc"
: >"$backup_config"
HOME="$backup_home" XDG_CONFIG_HOME="$backup_config_home" XDG_CACHE_HOME="$backup_cache_home" XDG_STATE_HOME="$backup_state" \
    "$chezmoi_bin" --source "$backup_source" --destination "$backup_home" --config "$backup_config" --persistent-state "$backup_persistent_state" apply
[ "$(cat "$backup_home/.zshrc")" = 'managed configuration' ]
backup_dir="$(find "$backup_state/chezmoi-backups/pre-apply" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[ -n "$backup_dir" ]
[ "$(cat "$backup_dir/.zshrc")" = 'original configuration' ]
python3 - "$backup_dir" <<'PY'
import os
import stat
import sys
assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o700
PY
backup_count="$(find "$backup_state/chezmoi-backups/pre-apply" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
HOME="$backup_home" XDG_CONFIG_HOME="$backup_config_home" XDG_CACHE_HOME="$backup_cache_home" XDG_STATE_HOME="$backup_state" \
    "$chezmoi_bin" --source "$backup_source" --destination "$backup_home" --config "$backup_config" --persistent-state "$backup_persistent_state" apply
[ "$(find "$backup_state/chezmoi-backups/pre-apply" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "$backup_count" ]

# If a timestamp collides, an existing backup is retained and the new one gets
# a suffix instead of overwriting it.
collision_name='20000101T000000Z'
collision_dir="$backup_state/chezmoi-backups/pre-apply/$collision_name"
mkdir -p -m 700 "$collision_dir"
printf '%s\n' 'keep this backup' >"$collision_dir/sentinel"
cat >"$fakebin/date" <<'EOF'
#!/bin/bash
printf '%s\n' 20000101T000000Z
EOF
chmod +x "$fakebin/date"
HOME="$backup_home" XDG_STATE_HOME="$backup_state" PATH="$fakebin:/usr/bin:/bin" bash "$source_dir/run_once_before_00-backup-config.sh.tmpl" >"$logdir/backup-collision.out"
[ "$(cat "$collision_dir/sentinel")" = 'keep this backup' ]
[ -d "$collision_dir-1" ]
rm -f "$fakebin/date"

# A failed copy must stop the apply before an existing file can be replaced.
failed_home="$tmpdir/failed-home"
failed_state="$tmpdir/failed-state"
failed_config_home="$tmpdir/failed-xdg-config"
failed_cache_home="$tmpdir/failed-xdg-cache"
failed_persistent_state="$tmpdir/failed-persistent-state.db"
mkdir -p "$failed_home" "$failed_state" "$failed_config_home" "$failed_cache_home"
printf '%s\n' 'original must survive' >"$failed_home/.zshrc"
cat >"$fakebin/cp" <<'EOF'
#!/bin/bash
exit 29
EOF
chmod +x "$fakebin/cp"
if HOME="$failed_home" XDG_CONFIG_HOME="$failed_config_home" XDG_CACHE_HOME="$failed_cache_home" XDG_STATE_HOME="$failed_state" PATH="$fakebin:/usr/bin:/bin" \
    "$chezmoi_bin" --source "$backup_source" --destination "$failed_home" --config "$backup_config" --persistent-state "$failed_persistent_state" apply >"$logdir/backup-failure.out" 2>&1; then
    echo "expected failed pre-apply backup to stop chezmoi apply" >&2; exit 1
fi
[ "$(cat "$failed_home/.zshrc")" = 'original must survive' ]
rm -f "$fakebin/cp"

# A failed curl must make quick-install fail and must never print its success
# message. The mock also ensures this test has no network side effect.
cat >"$fakebin/uname" <<'EOF'
#!/bin/bash
printf '%s\n' Linux
EOF
cat >"$fakebin/curl" <<'EOF'
#!/bin/bash
exit 22
EOF
chmod +x "$fakebin/uname" "$fakebin/curl"
quick_home="$tmpdir/quick-home"
mkdir -p "$quick_home"
if HOME="$quick_home" PATH="$fakebin:/usr/bin:/bin" bash "$source_dir/quick-install.sh" >"$logdir/quick-failure.out" 2>&1; then
    echo "expected quick-install to fail when curl fails" >&2; exit 1
fi
! grep -q '安装完成' "$logdir/quick-failure.out" || exit 1

echo "bootstrap and installer checks passed"
