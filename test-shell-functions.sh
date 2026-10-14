#!/usr/bin/env bash
# Isolated regression checks for dot_zsh_functions.tmpl. No real external actions.
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")" && pwd)
chezmoi_bin=${CHEZMOI_BIN:-$(command -v chezmoi)}
[ -n "$chezmoi_bin" ] || { echo 'chezmoi is required for this test' >&2; exit 1; }
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/source" "$tmp_dir/bin"
python_bin=$(command -v python3)
[ -n "$python_bin" ] || { echo 'python3 is required for this test' >&2; exit 1; }
ln -s "$python_bin" "$tmp_dir/bin/python3"
printf '%s\n' '{"data":{"aws":{"profiles":[{"name":"audit_profile","region":"us-east-1","sso":false,"codeartifact":false}]},"home":{"tailscale_path":"","ssh_host":"example.invalid","pc_ip":"192.0.2.1"}}}' >"$tmp_dir/config.json"
"$chezmoi_bin" --source "$tmp_dir/source" --config "$tmp_dir/config.json" execute-template <"$repo_dir/dot_zsh_functions.tmpl" >"$tmp_dir/functions.zsh"
/bin/zsh -n "$tmp_dir/functions.zsh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# A malicious-looking name is data; a .git file identifies a worktree.
mkdir -p "$tmp_dir/repos/repo\$(touch PWNED)" "$tmp_dir/repos/worktree"
: >"$tmp_dir/repos/repo\$(touch PWNED)/.git"
: >"$tmp_dir/repos/worktree/.git"
cat >"$tmp_dir/bin/git" <<'EOF'
#!/bin/sh
case "$*" in *rev-parse*) exit 0;; *pull*) printf 'mock pull\n'; exit 7;; esac
EOF
chmod 700 "$tmp_dir/bin/git"
set +e
( cd "$tmp_dir/repos"; PATH="$tmp_dir/bin:/usr/bin:/bin" /bin/zsh -f -c "source '$tmp_dir/functions.zsh'; gpullall" ) >"$tmp_dir/gpull.out" 2>&1
pull_status=$?
set -e
[ ! -e "$tmp_dir/repos/PWNED" ] || fail 'gpullall executed a directory name'
[ "$pull_status" -ne 0 ] || fail 'gpullall hid a failed pull'
grep -F 'repo$(touch PWNED)' "$tmp_dir/gpull.out" >/dev/null || fail 'gpullall skipped a valid repository'
grep -F 'worktree' "$tmp_dir/gpull.out" >/dev/null || fail 'gpullall did not support a .git file'

# A failed credential export leaves the original session untouched.
cat >"$tmp_dir/aws-failure.zsh" <<EOF
source '$tmp_dir/functions.zsh'
aws() { return 42; }
export AWS_PROFILE=old AWS_REGION=old-region AWS_DEFAULT_REGION=old-region
export AWS_ACCESS_KEY_ID=OLD AWS_SECRET_ACCESS_KEY=OLD_SECRET AWS_SESSION_TOKEN=OLD_TOKEN
audit_profile >/dev/null 2>&1
[[ \$? -ne 0 && \$AWS_PROFILE == old && \$AWS_REGION == old-region && \$AWS_ACCESS_KEY_ID == OLD && \$AWS_SECRET_ACCESS_KEY == OLD_SECRET && \$AWS_SESSION_TOKEN == OLD_TOKEN ]]
EOF
/bin/zsh -f "$tmp_dir/aws-failure.zsh" || fail 'failed AWS switch changed the previous session'

# process-format JSON is parsed as data, including success and malformed/error
# cases. CodeArtifact and directory preparation must also finish before commit.
render_profile() {
  printf '%s\n' "$1" >"$tmp_dir/profile.json"
  "$chezmoi_bin" --source "$tmp_dir/source" --config "$tmp_dir/profile.json" execute-template <"$repo_dir/dot_zsh_functions.tmpl" >"$tmp_dir/profile.zsh"
}
plain_profile='{"data":{"aws":{"profiles":[{"name":"audit_profile","region":"us-east-1"}]},"home":{"tailscale_path":"","ssh_host":"x","pc_ip":"x"}}}'
render_profile "$plain_profile"
cat >"$tmp_dir/aws-json.zsh" <<EOF
set -e
source '$tmp_dir/profile.zsh'
aws() { print '{"Version":1,"AccessKeyId":"NEW","SecretAccessKey":"NEW_SECRET","Expiration":"2030-01-01T00:00:00Z"}'; }
export AWS_SESSION_TOKEN=OLD_TOKEN AWS_CREDENTIAL_EXPIRATION=old
audit_profile >/dev/null
[[ \$AWS_ACCESS_KEY_ID == NEW && \$AWS_SECRET_ACCESS_KEY == NEW_SECRET && -z \${AWS_SESSION_TOKEN-} && \$AWS_CREDENTIAL_EXPIRATION == 2030-01-01T00:00:00Z && \$AWS_PROFILE == audit_profile ]]
EOF
/bin/zsh -f "$tmp_dir/aws-json.zsh" || fail 'successful AWS JSON switch was incorrect'
cat >"$tmp_dir/aws-malformed.zsh" <<EOF
source '$tmp_dir/profile.zsh'
aws() { print '{"AccessKeyId":"NEW"}'; }
export AWS_ACCESS_KEY_ID=OLD AWS_SECRET_ACCESS_KEY=OLD_SECRET AWS_PROFILE=old
audit_profile >/dev/null 2>&1
[[ \$? -ne 0 && \$AWS_ACCESS_KEY_ID == OLD && \$AWS_SECRET_ACCESS_KEY == OLD_SECRET && \$AWS_PROFILE == old ]]
EOF
/bin/zsh -f "$tmp_dir/aws-malformed.zsh" || fail 'malformed AWS JSON changed the previous session'
cat >"$tmp_dir/aws-nonzero.zsh" <<EOF
source '$tmp_dir/profile.zsh'
aws() { print '{"Version":1,"AccessKeyId":"NEW","SecretAccessKey":"NEW_SECRET"}'; return 42; }
export AWS_ACCESS_KEY_ID=OLD AWS_SECRET_ACCESS_KEY=OLD_SECRET AWS_PROFILE=old
audit_profile >/dev/null 2>&1
[[ \$? -ne 0 && \$AWS_ACCESS_KEY_ID == OLD && \$AWS_SECRET_ACCESS_KEY == OLD_SECRET && \$AWS_PROFILE == old ]]
EOF
/bin/zsh -f "$tmp_dir/aws-nonzero.zsh" || fail 'nonzero AWS export changed the previous session'
unsafe_profile='{"data":{"aws":{"profiles":[{"name":"bad profile","region":"us-east-1"}]},"home":{"tailscale_path":"","ssh_host":"x","pc_ip":"x"}}}'
if render_profile "$unsafe_profile" >/dev/null 2>&1; then fail 'unsafe AWS function name rendered'; fi
code_profile='{"data":{"aws":{"codeartifact_domain":"example","profiles":[{"name":"audit_code","region":"us-east-1","codeartifact":true}]},"home":{"tailscale_path":"","ssh_host":"x","pc_ip":"x"}}}'
render_profile "$code_profile"
cat >"$tmp_dir/aws-code-failure.zsh" <<EOF
source '$tmp_dir/profile.zsh'
aws() { [[ \$* == *codeartifact* ]] && return 42; print '{"Version":1,"AccessKeyId":"NEW","SecretAccessKey":"NEW_SECRET"}'; }
export AWS_ACCESS_KEY_ID=OLD AWS_SECRET_ACCESS_KEY=OLD_SECRET AWS_PROFILE=old
audit_code >/dev/null 2>&1
[[ \$? -ne 0 && \$AWS_ACCESS_KEY_ID == OLD && \$AWS_SECRET_ACCESS_KEY == OLD_SECRET && \$AWS_PROFILE == old ]]
EOF
/bin/zsh -f "$tmp_dir/aws-code-failure.zsh" || fail 'CodeArtifact failure changed the previous session'
mkdir -p "$tmp_dir/not-a-home"; : >"$tmp_dir/not-a-home-file"
cat >"$tmp_dir/aws-mkdir-failure.zsh" <<EOF
source '$tmp_dir/profile.zsh'
aws() { [[ \$* == *codeartifact* ]] && { print token; return 0; }; print '{"Version":1,"AccessKeyId":"NEW","SecretAccessKey":"NEW_SECRET"}'; }
export AWS_ACCESS_KEY_ID=OLD AWS_SECRET_ACCESS_KEY=OLD_SECRET AWS_PROFILE=old HOME='$tmp_dir/not-a-home-file'
audit_code >/dev/null 2>&1
[[ \$? -ne 0 && \$AWS_ACCESS_KEY_ID == OLD && \$AWS_SECRET_ACCESS_KEY == OLD_SECRET && \$AWS_PROFILE == old ]]
EOF
/bin/zsh -f "$tmp_dir/aws-mkdir-failure.zsh" || fail 'CodeArtifact mkdir failure changed the previous session'

# Only JSON BackendState=Running is accepted. Starting must refresh.
cat >"$tmp_dir/bin/tailscale" <<'EOF'
#!/bin/sh
state_file=${TAILSCALE_TEST_STATE:?}; count=$(cat "$state_file" 2>/dev/null || printf 0)
count=$((count + 1)); printf '%s' "$count" >"$state_file"
case "${TAILSCALE_TEST_MODE:?}" in
  loggedout) exit 1;;
  needslogin) printf '%s\n' '{"BackendState":"NeedsLogin"}';;
  malformed) printf '%s\n' '{not json';;
  starting) printf '%s\n' '{"BackendState":"Starting"}';;
  starting_then_running) [ "$count" -eq 1 ] && printf '%s\n' '{"BackendState":"Starting"}' || printf '%s\n' '{"BackendState":"Running"}';;
esac
EOF
chmod 700 "$tmp_dir/bin/tailscale"
for mode in loggedout needslogin malformed starting; do
  : >"$tmp_dir/state"
  if TAILSCALE_TEST_MODE="$mode" TAILSCALE_TEST_STATE="$tmp_dir/state" PATH="$tmp_dir/bin:/usr/bin:/bin" /bin/zsh -f -c "source '$tmp_dir/functions.zsh'; TAILSCALE_EXE='$tmp_dir/bin/tailscale'; _ensure_tailscale" >/dev/null 2>&1; then fail "tailscale $mode was accepted"; fi
done
: >"$tmp_dir/state"
TAILSCALE_TEST_MODE=starting_then_running TAILSCALE_TEST_STATE="$tmp_dir/state" PATH="$tmp_dir/bin:/usr/bin:/bin" /bin/zsh -f -c "source '$tmp_dir/functions.zsh'; TAILSCALE_EXE='$tmp_dir/bin/tailscale'; sleep() { :; }; _ensure_tailscale" >/dev/null || fail 'tailscale did not refresh Starting state'

# mac_clean remains read-only; mocks record any accidental destructive call.
for command_name in rm sudo tmutil docker; do
  printf '%s\n' '#!/bin/sh' 'printf "%s %s\\n" "$(basename "$0")" "$*" >>"$SHELL_SAFETY_LOG"' 'exit 0' >"$tmp_dir/bin/$command_name"
  chmod 700 "$tmp_dir/bin/$command_name"
done
export SHELL_SAFETY_LOG="$tmp_dir/commands.log"
PATH="$tmp_dir/bin:/usr/bin:/bin" HOME="$tmp_dir" /bin/zsh -f -c "source '$tmp_dir/functions.zsh'; mac_clean" >/dev/null
! grep -E '^(rm|sudo) ' "$tmp_dir/commands.log" >/dev/null 2>&1 || fail 'mac_clean invoked a destructive command'
! grep -E 'tmutil .*delete|docker .*prune' "$tmp_dir/commands.log" >/dev/null 2>&1 || fail 'mac_clean attempted data deletion'

# Both page sizes yield 4 GiB used from the same vm_stat counters.
check_page_size() {
  local page_size=$1 pages=$2
  cat >"$tmp_dir/mac-check.zsh" <<EOF
source '$tmp_dir/functions.zsh'
system_profiler() { print 'Model Name: Test\nChip: Test\nMemory: 8 GB'; }; uptime() { print 'up 1 day, 1 user, load averages: 0.00 0.00 0.00'; }; diskutil() { print 'Disk Size: 8 GB'; }
vm_stat() { print 'Mach Virtual Memory Statistics: (page size of $page_size bytes)'; print 'Pages free: $pages.'; print 'Pages active: $pages.'; print 'Pages inactive: $pages.'; print 'Pages wired down: $pages.'; print 'Pages occupied by compressor: $pages.'; print 'Pages swapped out: 0.'; }
sysctl() { print 8589934592; }; memory_pressure() { print 'System-wide memory free percentage: 50%'; }; ps() { print 'USER PID %CPU %MEM COMMAND'; }
mac_check
EOF
  /bin/zsh -f "$tmp_dir/mac-check.zsh" | grep -F '已用: 4.0 GB' >/dev/null || fail "vm_stat page size $page_size was calculated incorrectly"
}
check_page_size 4096 262144
check_page_size 16384 65536
printf 'PASS: shell function safety regressions\n'
