#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d /tmp/dotfiles-platform-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT
cp "$source_dir/.chezmoi.yaml.example" "$tmpdir/config.yaml"
# Keep platform fixtures independent of the host's installed mise release.
mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/mise" <<'EOF'
#!/bin/sh
[ "$#" = 1 ] && [ "$1" = --version ] || exit 1
printf '%s\n' '2026.9.1 fixture'
EOF
chmod +x "$tmpdir/bin/mise"
export PATH="$tmpdir/bin:$PATH"

for platform in mac-arm mac-intel linux wsl; do
    case "$platform" in
        mac-arm) os=darwin; arch=arm64; kernel=25.0.0;;
        mac-intel) os=darwin; arch=amd64; kernel=25.0.0;;
        linux) os=linux; arch=amd64; kernel=6.6.0;;
        wsl) os=linux; arch=amd64; kernel=6.6-microsoft-standard-WSL2;;
    esac
    override="{\"chezmoi\":{\"os\":\"$os\",\"arch\":\"$arch\",\"kernel\":{\"osrelease\":\"$kernel\"}}}"
    render() {
        chezmoi --source "$source_dir" --config "$tmpdir/config.yaml" --override-data "$override" \
            execute-template --file "$source_dir/$1"
    }
    actual=$(chezmoi --source "$source_dir" --config "$tmpdir/config.yaml" --override-data "$override" \
        execute-template '{{ .chezmoi.os }}/{{ .chezmoi.arch }}/{{ .chezmoi.kernel.osrelease }}')
    [ "$actual" = "$os/$arch/$kernel" ]
    for f in dot_zshrc.tmpl dot_zsh_functions.tmpl dot_zsh_aliases.tmpl "$source_dir"/dot_zsh/*.tmpl; do
        f=${f#"$source_dir/"}
        render "$f" > "$tmpdir/rendered.zsh"
        zsh -n "$tmpdir/rendered.zsh"
    done
    for f in "$source_dir"/run*.tmpl; do
        render "${f#"$source_dir/"}" > "$tmpdir/rendered.sh"
        bash -n "$tmpdir/rendered.sh"
    done
    render dot_gitconfig.tmpl > "$tmpdir/gitconfig"
    git config --file "$tmpdir/gitconfig" --list >/dev/null
    ! git config --file "$tmpdir/gitconfig" --get core.hooksPath || exit 1
    ! git config --file "$tmpdir/gitconfig" --get http.proxy || exit 1
    render dot_config/mise/config.toml.tmpl > "$tmpdir/mise.toml"
    python3 - "$tmpdir/mise.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    cfg = tomllib.load(f)
assert cfg['settings']['upgrade']['auto_prune'] is False
assert cfg['tools']['flutter'] == '3.35.3'
PY
    render dot_zshrc.tmpl > "$tmpdir/zshrc"
    if [ "$os" = darwin ]; then
        grep -q '/opt/homebrew/bin/brew /usr/local/bin/brew' "$tmpdir/zshrc"
    else
        grep -q '/home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew' "$tmpdir/zshrc"
    fi
    render dot_zsh/wsl.zsh.tmpl > "$tmpdir/wsl.zsh"
    if [ "$platform" = wsl ]; then
        env http_proxy=existing-http https_proxy=existing-https all_proxy=existing-all \
            zsh -f -c '
                set -e
                source "$1"
                [[ $http_proxy == existing-http && $https_proxy == existing-https && $all_proxy == existing-all ]]
                WSL_PROXY_PORT=7890 proxy_on --quiet
                [[ $http_proxy == http://127.0.0.1:7890 && $all_proxy == socks5://127.0.0.1:7890 ]]
                WSL_PROXY_PORT=70000 proxy_on --quiet && exit 1
                [[ $http_proxy == http://127.0.0.1:7890 ]]
            ' _ "$tmpdir/wsl.zsh"
    else
        ! grep -q '[^[:space:]]' "$tmpdir/wsl.zsh" || exit 1
    fi
    echo "PASS: $platform templates"
done

# The Docker shortcut only inspects usage, even if a user retains its old name.
render dot_zsh_aliases.tmpl > "$tmpdir/aliases.zsh"
zsh -f -c 'source "$1"; [[ $aliases[dprune] == "docker system df -v" ]]' _ "$tmpdir/aliases.zsh"
python3 - "$source_dir/local.toml.example" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    cfg = tomllib.load(f)
assert cfg['versions']['rust'] == '1.85.0'
assert cfg['aws']['profiles'] == []
assert cfg['disabled_mise_tools'] == []
PY
echo 'PASS: platform and safe default checks'
