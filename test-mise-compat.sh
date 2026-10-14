#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
chezmoi_bin="$(command -v chezmoi)"
python_bin="${PYTHON_BIN:-python3}"
"$python_bin" -c 'import tomllib' >/dev/null 2>&1 || {
    echo "Python 3.11+ with tomllib is required" >&2
    exit 1
}

tmpdir="$(mktemp -d /tmp/dotfiles-mise-compat-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT
fakebin="$tmpdir/bin"
mkdir -p "$fakebin"
config="$tmpdir/config.yaml"
cp "$source_dir/.chezmoi.yaml.example" "$config"

cat >"$fakebin/mise" <<'EOF'
#!/bin/sh
printf 'args=%s no_config=%s offline=%s\n' "$*" "${MISE_NO_CONFIG:-}" "${MISE_OFFLINE:-}" >>"$MISE_MOCK_LOG"
[ "${1:-}" = "--version" ] && [ "$#" -eq 1 ] || exit 99
printf 'mise %s mock\n' "$MISE_MOCK_VERSION"
EOF
chmod +x "$fakebin/mise"

render_with_mise() {
    local version=$1 output=$2 log=$3
    MISE_MOCK_VERSION="$version" MISE_MOCK_LOG="$log" PATH="$fakebin:/usr/bin:/bin" \
        "$chezmoi_bin" --source "$source_dir" --config "$config" \
        execute-template --file "$source_dir/dot_config/mise/config.toml.tmpl" >"$output"
}

assert_toml() {
    "$python_bin" - "$1" "$2" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    config = tomllib.load(f)
if sys.argv[2] == 'absent':
    assert 'upgrade' not in config['settings']
else:
    assert config['settings']['upgrade']['auto_prune'] is False
PY
}

assert_version_call() {
    [ "$(wc -l <"$1" | tr -d ' ')" = 1 ]
    grep -Fqx 'args=--version no_config=1 offline=1' "$1"
}

for version in 2026.4.18 2026.8.3; do
    output="$tmpdir/$version.toml"
    log="$tmpdir/$version.log"
    render_with_mise "$version" "$output" "$log"
    assert_toml "$output" absent
    assert_version_call "$log"
    if grep -Fxq 'upgrade.auto_prune = false' "$output"; then
        echo "old mise $version rendered an unsupported setting" >&2
        exit 1
    fi
    grep -Fq "mise $version 不识别 upgrade.auto_prune" "$output"
done

for version in 2026.8.4 2026.9.1; do
    output="$tmpdir/$version.toml"
    log="$tmpdir/$version.log"
    render_with_mise "$version" "$output" "$log"
    assert_toml "$output" false
    assert_version_call "$log"
    grep -Fqx 'upgrade.auto_prune = false' "$output"
done

unknown_log="$tmpdir/unknown.log"
if MISE_MOCK_VERSION='unknown build' MISE_MOCK_LOG="$unknown_log" PATH="$fakebin:/usr/bin:/bin" \
    "$chezmoi_bin" --source "$source_dir" --config "$config" \
    execute-template --file "$source_dir/dot_config/mise/config.toml.tmpl" >"$tmpdir/unknown.toml" 2>"$tmpdir/unknown.err"; then
    echo "unknown mise version must fail rendering" >&2
    exit 1
fi
assert_version_call "$unknown_log"
grep -Fq 'cannot parse mise version' "$tmpdir/unknown.err"

no_mise_output="$tmpdir/no-mise.toml"
mkdir -p "$tmpdir/no-tools"
PATH="$tmpdir/no-tools" "$chezmoi_bin" --source "$source_dir" --config "$config" \
    execute-template --file "$source_dir/dot_config/mise/config.toml.tmpl" >"$no_mise_output"
assert_toml "$no_mise_output" false
grep -Fqx 'upgrade.auto_prune = false' "$no_mise_output"

echo "mise compatibility checks passed"
