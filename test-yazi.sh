#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
installer="$script_dir/run_after_install-yazi-plugins.sh.tmpl"
source_manifest="$script_dir/dot_config/yazi/package.toml"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/test-yazi.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
plugin_names() {
    awk -F'"' '
        /^\[\[plugin\.deps\]\]/{inside=1;next}
        /^\[/{inside=0}
        inside && /^[[:space:]]*use[[:space:]]*=/ {print $2}
    ' "$1" | while IFS= read -r use; do
        name="${use##*:}"; [ "$name" = "$use" ] && name="${use##*/}"
        printf '%s.yazi\n' "${name%.yazi}"
    done
}

home_dir="$fixture_root/home"
config_dir="$home_dir/.config"
state_dir="$home_dir/.local/state"
log_dir="$fixture_root/log"
fake_bin="$fixture_root/bin"
mkdir -p "$config_dir/yazi" "$state_dir" "$log_dir" "$fake_bin"
cp "$source_manifest" "$config_dir/yazi/package.toml"

run_yazi() {
    env HOME="$home_dir" XDG_CONFIG_HOME="$config_dir" XDG_STATE_HOME="$state_dir" TEST_LOG="$log_dir" PATH="$fake_bin:/usr/bin:/bin" \
        bash "$installer" "$@"
}

# Without ya this is intentionally deferred and must not create a completion stamp.
PATH="/usr/bin:/bin" HOME="$home_dir" XDG_CONFIG_HOME="$config_dir" XDG_STATE_HOME="$state_dir" bash "$installer" >"$log_dir/absent.out"
[ ! -e "$state_dir/chezmoi/yazi-plugins.sha256" ] || fail 'unavailable Yazi wrote a completion stamp'

cat > "$fake_bin/ya" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TEST_LOG/ya.calls"
[ "${FAKE_YA_FAIL:-0}" != 1 ] || exit 9
manifest="${XDG_CONFIG_HOME:-$HOME/.config}/yazi/package.toml"
root="${XDG_CONFIG_HOME:-$HOME/.config}/yazi/plugins"
awk -F'"' '/^\[\[plugin\.deps\]\]/{inside=1;next} /^\[/{inside=0} inside && /^[[:space:]]*use[[:space:]]*=/ {print $2}' "$manifest" |
while IFS= read -r use; do
    name="${use##*:}"; [ "$name" = "$use" ] && name="${use##*/}"; name="${name%.yazi}"
    mkdir -p "$root/$name.yazi"
    if [ "${FAKE_YA_EMPTY:-0}" = 1 ]; then
        continue
    elif [ "${FAKE_YA_EMPTY_FILE:-0}" = 1 ]; then
        : > "$root/$name.yazi/main.lua"
    else
        printf '%s\n' '-- test plugin' > "$root/$name.yazi/main.lua"
    fi
done
EOF
chmod +x "$fake_bin/ya"

run_yazi >"$log_dir/first.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 1 ] || fail 'initial install did not run once'
stamp="$state_dir/chezmoi/yazi-plugins.sha256"
[ -f "$stamp" ] || fail 'complete installation did not write a stamp'
while IFS= read -r plugin; do [ -f "$config_dir/yazi/plugins/$plugin/main.lua" ] || fail "missing main.lua for $plugin"; done < <(plugin_names "$config_dir/yazi/package.toml")

run_yazi >"$log_dir/second.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 1 ] || fail 'complete unchanged plugins reinstalled'

# An empty directory is incomplete despite matching the manifest hash.
# Keep consuming the producer: with pipefail, head would make the producer's
# final write report SIGPIPE on manifests containing more than one plugin.
first_plugin=$(plugin_names "$config_dir/yazi/package.toml" | tail -n +1 | sed -n '1p')
rm -f "$config_dir/yazi/plugins/$first_plugin/main.lua"
run_yazi >"$log_dir/repair-missing-entry.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 2 ] || fail 'missing main.lua was not repaired'

# A zero-byte entrypoint is also incomplete and must leave the old stamp.
stamp_before_zero=$(cat "$stamp")
rm -f "$config_dir/yazi/plugins/$first_plugin/main.lua"
if FAKE_YA_EMPTY_FILE=1 run_yazi >"$log_dir/zero-byte.out" 2>&1; then fail 'zero-byte plugin entrypoint returned success'; fi
[ "$(cat "$stamp")" = "$stamp_before_zero" ] || fail 'zero-byte plugin entrypoint changed the stamp'

# A manifest change installs the new plugin, refreshes the stamp, and then
# becomes idempotent after every entrypoint exists.
cat >> "$config_dir/yazi/package.toml" <<'EOF'

[[plugin.deps]]
use = "example/repo:extra.yazi"
EOF
run_yazi >"$log_dir/manifest-change.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 4 ] || fail 'manifest change did not install once'
[ -s "$config_dir/yazi/plugins/extra.yazi/main.lua" ] || fail 'manifest change did not install the new entrypoint'
stamp_after_manifest=$(cat "$stamp")
[ "$stamp_after_manifest" != "$stamp_before_zero" ] || fail 'manifest change did not refresh the stamp'
run_yazi >"$log_dir/manifest-steady.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 4 ] || fail 'complete changed manifest reinstalled'

# A failed repair leaves the current stamp; the next apply retries and only
# stamps after every plugin has a non-empty entrypoint.
stamp_before=$(cat "$stamp")
rm -f "$config_dir/yazi/plugins/$first_plugin/main.lua"
if FAKE_YA_FAIL=1 run_yazi >"$log_dir/failure.out" 2>&1; then fail 'failed plugin install returned success'; fi
[ "$(cat "$stamp")" = "$stamp_before" ] || fail 'failed plugin install changed the stamp'
if FAKE_YA_EMPTY=1 run_yazi >"$log_dir/empty.out" 2>&1; then fail 'empty plugin directories returned success'; fi
[ "$(cat "$stamp")" = "$stamp_before" ] || fail 'empty plugin directories changed the stamp'
run_yazi >"$log_dir/retry.out"
[ "$(wc -l < "$log_dir/ya.calls" | tr -d ' ')" = 7 ] || fail 'failed plugin repair was not retried'

printf '%s\n' 'PASS: Yazi plugin installer fixtures'
