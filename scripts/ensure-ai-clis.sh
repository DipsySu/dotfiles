#!/bin/bash
# This file is included by run_after_ensure-ai-clis.sh.tmpl.  Keep it bash-only.

set -u

AI_CLI_LOCAL_BIN="$HOME/.local/bin"
AI_CLI_GROK_BIN="$HOME/.grok/bin"
AI_CLI_TMP=""
AI_CLI_SNAPSHOT_ACTIVE=0
AI_CLI_KEEP_TMP=0
AI_CLI_SNAPSHOT_SEQ=0

ai_cli_cleanup() {
    local status=$?
    if [ -n "${AI_CLI_TMP:-}" ] && { [ "$AI_CLI_SNAPSHOT_ACTIVE" -ne 0 ] || [ "$AI_CLI_KEEP_TMP" -ne 0 ]; }; then
        printf 'Preserving AI CLI recovery snapshot at %s\n' "$AI_CLI_TMP" >&2
    elif [ -n "${AI_CLI_TMP:-}" ]; then
        rm -rf "$AI_CLI_TMP"
    fi
    return "$status"
}

ai_cli_interrupted() {
    AI_CLI_KEEP_TMP=1
    trap - INT TERM
    exit "$1"
}

ai_cli_prepare_tmp() {
    umask 077
    AI_CLI_TMP=$(mktemp -d "${TMPDIR:-/tmp}/ensure-ai-clis.XXXXXX") || return 1
    trap ai_cli_cleanup EXIT
    trap 'ai_cli_interrupted 130' INT
    trap 'ai_cli_interrupted 143' TERM
}

ai_cli_is_entry() {
    [ -x "$1" ]
}

ai_cli_require_entry() {
    local label="$1" path="$2"
    if ! ai_cli_is_entry "$path"; then
        printf '%s CLI installer finished without a usable entry at %s.\n' "$label" "$path" >&2
        return 1
    fi
}

ai_cli_download() {
    local url="$1" destination="$2"
    curl -fsSL --proto '=https' --connect-timeout 10 --max-time 60 -o "$destination" "$url"
}

# Save shell start-up files because vendor installers sometimes edit them even
# in non-interactive mode.  The manifest also records files which were absent.
ai_cli_save_profiles() {
    local profile name target referent
    AI_CLI_SNAPSHOT_SEQ=$((AI_CLI_SNAPSHOT_SEQ + 1))
    AI_CLI_PROFILE_DIR="$AI_CLI_TMP/profiles.$AI_CLI_SNAPSHOT_SEQ"
    mkdir -p "$AI_CLI_PROFILE_DIR" || return 1
    : > "$AI_CLI_PROFILE_DIR/manifest"
    for profile in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
        name=${profile##*/}
        if [ -L "$profile" ]; then
            target=$(readlink "$profile") || return 1
            printf '%s\n' "$target" > "$AI_CLI_PROFILE_DIR/$name.link" || return 1
            if [ -e "$profile" ]; then
                [ -f "$profile" ] || { printf 'Refusing to snapshot non-file profile link %s\n' "$profile" >&2; return 1; }
                if [[ "$target" = /* ]]; then referent="$target"; else referent="$(cd -P "${profile%/*}" && pwd)/$target"; fi
                printf '%s\n' "$referent" > "$AI_CLI_PROFILE_DIR/$name.referent-path" || return 1
                cp -p "$profile" "$AI_CLI_PROFILE_DIR/$name.referent" || return 1
                printf '%s symlink-file\n' "$name" >> "$AI_CLI_PROFILE_DIR/manifest"
            else
                printf '%s symlink-broken\n' "$name" >> "$AI_CLI_PROFILE_DIR/manifest"
            fi
        elif [ -e "$profile" ]; then
            [ -f "$profile" ] || { printf 'Refusing to snapshot non-file profile %s\n' "$profile" >&2; return 1; }
            cp -p "$profile" "$AI_CLI_PROFILE_DIR/$name" || return 1
            printf '%s regular\n' "$name" >> "$AI_CLI_PROFILE_DIR/manifest"
        else
            printf '%s absent\n' "$name" >> "$AI_CLI_PROFILE_DIR/manifest"
        fi
    done
}

ai_cli_restore_profiles() {
    local name state profile target referent
    [ -f "$AI_CLI_PROFILE_DIR/manifest" ] || return 0
    while read -r name state; do
        profile="$HOME/$name"
        case "$state" in
            regular)
                [ ! -d "$profile" ] || { printf 'Refusing to replace directory %s during restore\n' "$profile" >&2; return 1; }
                rm -f "$profile" || return 1
                cp -p "$AI_CLI_PROFILE_DIR/$name" "$profile" || return 1
                ;;
            symlink-file|symlink-broken)
                [ ! -d "$profile" ] || { printf 'Refusing to replace directory %s during restore\n' "$profile" >&2; return 1; }
                target=$(cat "$AI_CLI_PROFILE_DIR/$name.link") || return 1
                rm -f "$profile" || return 1
                ln -s "$target" "$profile" || return 1
                if [ "$state" = symlink-file ]; then
                    referent=$(cat "$AI_CLI_PROFILE_DIR/$name.referent-path") || return 1
                    [ ! -d "$referent" ] || { printf 'Refusing to replace directory %s during restore\n' "$referent" >&2; return 1; }
                    cp -p "$AI_CLI_PROFILE_DIR/$name.referent" "$referent" || return 1
                fi
                ;;
            absent) [ ! -d "$profile" ] || { printf 'Refusing to remove directory %s during restore\n' "$profile" >&2; return 1; }; rm -f "$profile" || return 1 ;;
            *) printf 'Unknown profile snapshot state %s\n' "$state" >&2; return 1 ;;
        esac
    done < "$AI_CLI_PROFILE_DIR/manifest"
}

ai_cli_run_with_profiles() {
    ai_cli_save_profiles || return 1
    AI_CLI_SNAPSHOT_ACTIVE=1
    "$@"
    local status=$?
    if ! ai_cli_restore_profiles; then
        AI_CLI_KEEP_TMP=1
        return 1
    fi
    [ "$AI_CLI_KEEP_TMP" -ne 0 ] || AI_CLI_SNAPSHOT_ACTIVE=0
    return "$status"
}

ai_cli_run_claude() {
    local installer="$1" settings="$HOME/.claude/settings.json" settings_dir="$AI_CLI_TMP/claude-settings" status
    mkdir -p "$settings_dir" || return 1
    if [ -e "$settings" ]; then
        cp -p "$settings" "$settings_dir/settings.json" || return 1
        AI_CLI_CLAUDE_SETTINGS_WAS_PRESENT=1
    else
        AI_CLI_CLAUDE_SETTINGS_WAS_PRESENT=0
    fi
    ai_cli_save_profiles || return 1
    AI_CLI_SNAPSHOT_ACTIVE=1
    /bin/bash "$installer" latest
    status=$?
    if ! ai_cli_restore_profiles; then
        AI_CLI_KEEP_TMP=1
        return 1
    fi
    if [ "$AI_CLI_CLAUDE_SETTINGS_WAS_PRESENT" = 1 ]; then
        mkdir -p "${settings%/*}" || return 1
        if ! cp -p "$settings_dir/settings.json" "$settings"; then
            AI_CLI_KEEP_TMP=1
            return 1
        fi
    fi
    [ "$AI_CLI_KEEP_TMP" -ne 0 ] || AI_CLI_SNAPSHOT_ACTIVE=0
    return "$status"
}

ai_cli_install_codex() {
    local installer="$AI_CLI_TMP/codex-install.sh"
    printf '%s\n' 'Installing Codex CLI...'
    ai_cli_download 'https://chatgpt.com/codex/install.sh' "$installer" || return 1
    chmod 700 "$installer" || return 1
    ai_cli_run_with_profiles env CODEX_NON_INTERACTIVE=1 /bin/sh "$installer"
}

ai_cli_install_claude() {
    local installer="$AI_CLI_TMP/claude-install.sh"
    printf '%s\n' 'Installing Claude CLI...'
    ai_cli_download 'https://claude.ai/install.sh' "$installer" || return 1
    chmod 700 "$installer" || return 1
    ai_cli_run_claude "$installer"
}

ai_cli_install_agy() {
    local downloaded="$AI_CLI_TMP/agy-download.sh" installer="$AI_CLI_TMP/agy-install.sh"
    local custom_dir="$AI_CLI_LOCAL_BIN"
    printf '%s\n' 'Installing Antigravity CLI...'
    ai_cli_download 'https://antigravity.google/cli/install.sh' "$downloaded" || return 1
    # Only alter the two native-setup handoffs reviewed for this installer.
    # A changed upstream layout fails closed instead of running profile edits.
    LC_ALL=C awk '
        /^[[:space:]]*"\$BINARY_PATH" install --dir "\$CUSTOM_DIR" \|\| true[[:space:]]*$/ {
            sub(/\|\| true[[:space:]]*$/, "--skip-path --skip-aliases || true"); custom++; print; next
        }
        /^[[:space:]]*"\$BINARY_PATH" install \|\| true[[:space:]]*$/ {
            sub(/\|\| true[[:space:]]*$/, "--skip-path --skip-aliases || true"); standard++; print; next
        }
        { print }
        END { if (custom != 1 || standard != 1) exit 42 }
    ' "$downloaded" > "$installer" || { printf '%s\n' 'Antigravity installer layout changed; refusing to run it.' >&2; return 1; }
    /bin/bash -n "$installer" || return 1
    chmod 700 "$installer" || return 1
    ai_cli_run_with_profiles /bin/bash "$installer" --dir "$custom_dir"
}

ai_cli_install_grok() {
    local installer="$AI_CLI_TMP/grok-install.sh"
    printf '%s\n' 'Installing Grok CLI...'
    ai_cli_download 'https://x.ai/cli/install.sh' "$installer" || return 1
    chmod 700 "$installer" || return 1
    env PATH="$AI_CLI_GROK_BIN:$PATH" SHELL= GROK_DEPLOYMENT_KEY= GROK_PROXY_URL= GROK_CHANNEL=stable GROK_BIN_DIR="$AI_CLI_GROK_BIN" /bin/bash "$installer" ''
}

ai_cli_add_grok_links() {
    local name
    ai_cli_is_entry "$AI_CLI_GROK_BIN/grok" || return 0
    mkdir -p "$AI_CLI_LOCAL_BIN" || return 1
    for name in agent; do
        if [ ! -e "$AI_CLI_GROK_BIN/$name" ] && [ ! -L "$AI_CLI_GROK_BIN/$name" ]; then
            ln -s grok "$AI_CLI_GROK_BIN/$name" || return 1
        fi
    done
    for name in grok agent; do
        if [ ! -e "$AI_CLI_LOCAL_BIN/$name" ] && [ ! -L "$AI_CLI_LOCAL_BIN/$name" ]; then
            ln -s "$AI_CLI_GROK_BIN/$name" "$AI_CLI_LOCAL_BIN/$name" || return 1
        fi
    done
}

ai_cli_main() {
    local platform failures=0
    platform=$(uname -s)
    case "$platform" in
        Darwin|Linux) ;;
        *) printf 'Skipping AI CLI setup: unsupported platform %s (macOS/Linux only).\n' "$platform" >&2; return 0 ;;
    esac
    mkdir -p "$AI_CLI_LOCAL_BIN" "$AI_CLI_GROK_BIN" || return 1
    export PATH="$AI_CLI_LOCAL_BIN:$PATH"
    ai_cli_prepare_tmp || { printf '%s\n' 'Unable to create temporary directory for AI CLI setup.' >&2; return 1; }

    if ai_cli_is_entry "$AI_CLI_LOCAL_BIN/codex"; then printf '%s\n' 'Codex CLI: already installed.'; else ai_cli_install_codex || failures=1; fi
    ai_cli_require_entry Codex "$AI_CLI_LOCAL_BIN/codex" || failures=1
    if ai_cli_is_entry "$AI_CLI_LOCAL_BIN/claude"; then printf '%s\n' 'Claude CLI: already installed.'; else ai_cli_install_claude || failures=1; fi
    ai_cli_require_entry Claude "$AI_CLI_LOCAL_BIN/claude" || failures=1
    if ai_cli_is_entry "$AI_CLI_LOCAL_BIN/agy"; then printf '%s\n' 'Antigravity CLI: already installed.'; else ai_cli_install_agy || failures=1; fi
    ai_cli_require_entry Antigravity "$AI_CLI_LOCAL_BIN/agy" || failures=1
    if ai_cli_is_entry "$AI_CLI_GROK_BIN/grok"; then printf '%s\n' 'Grok CLI: already installed.'; else ai_cli_install_grok || failures=1; fi
    ai_cli_add_grok_links || failures=1
    ai_cli_require_entry Grok "$AI_CLI_GROK_BIN/grok" || failures=1
    ai_cli_require_entry 'Grok agent' "$AI_CLI_GROK_BIN/agent" || failures=1
    ai_cli_require_entry 'Grok shell link' "$AI_CLI_LOCAL_BIN/grok" || failures=1
    ai_cli_require_entry 'Grok agent shell link' "$AI_CLI_LOCAL_BIN/agent" || failures=1
    return "$failures"
}

ai_cli_main "$@"
