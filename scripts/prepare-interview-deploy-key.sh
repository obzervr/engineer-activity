#!/usr/bin/env bash
#
# Prepares a per-candidate GitHub deploy key on an interview laptop (macOS/Linux).
# The macOS twin of Prepare-InterviewDeployKey.ps1; same three modes, same
# guarantees. See interview-access-runbook.md section B2.
#
#   ./prepare-interview-deploy-key.sh setup  smith obzervr/tech-interview.int-eng-smith \
#                                     "Jane Smith" jane@example.com
#   ./prepare-interview-deploy-key.sh verify smith obzervr/tech-interview.int-eng-smith [--clone]
#   ./prepare-interview-deploy-key.sh revoke smith
#
set -euo pipefail

# GitHub's published host key fingerprints, verified against
# docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# on 3 September 2026. GitHub rotates these (RSA was rotated in March 2023), so
# re-check them against that page each interview cycle.
EXPECTED_ED25519_FP='SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'

SSH_DIR="$HOME/.ssh"
CONFIG="$SSH_DIR/config"
KNOWN_HOSTS="$SSH_DIR/known_hosts"
BEGIN_MARKER='# BEGIN obzervr-interview (managed, safe to delete)'
END_MARKER='# END obzervr-interview'

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m    ok  %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    !!  %s\033[0m\n' "$1"; }
fail() { printf '\033[31m    XX  %s\033[0m\n' "$1" >&2; exit 1; }

usage() {
  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
}

require_tools() {
  for t in ssh-keygen ssh-keyscan ssh git; do
    command -v "$t" >/dev/null 2>&1 || fail "$t not found on PATH."
  done
}

validate_surname() {
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9-]{0,38}$ ]] || fail "Invalid surname '$1'. Letters, digits and hyphens only."
}

validate_repo() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || fail "Invalid repo '$1'. Expected owner/name."
}

key_path() { printf '%s/id_ed25519_interview_%s' "$SSH_DIR" "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }

strip_managed_block() {
  # Remove the managed block from $CONFIG, in place, if present.
  [[ -f "$CONFIG" ]] || return 0
  grep -qF "$BEGIN_MARKER" "$CONFIG" || return 1
  local tmp; tmp="$(mktemp)"
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
    index($0, b) { skip = 1; next }
    index($0, e) { skip = 0; next }
    !skip
  ' "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
  chmod 600 "$CONFIG"
  return 0
}

do_setup() {
  local surname="$1" repo="$2" cand_name="${3:-}" cand_email="${4:-}"
  validate_surname "$surname"; validate_repo "$repo"
  require_tools

  local key; key="$(key_path "$surname")"
  local comment="interview-$(printf '%s' "$surname" | tr '[:upper:]' '[:lower:]')-$(date +%Y%m)"

  step "Preparing $SSH_DIR"
  mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"
  ok "$SSH_DIR"

  step "Generating the deploy keypair"
  if [[ -e "$key" ]]; then
    fail "$key already exists. Run 'revoke $surname' first, or use a different surname. Refusing to overwrite a key that may already be registered on a repository."
  fi
  ssh-keygen -t ed25519 -C "$comment" -f "$key" -N '' >/dev/null
  chmod 600 "$key"; chmod 644 "$key.pub"
  ok "$key (comment: $comment)"

  step "Pinning github.com host key"
  # ssh-keyscan on its own is trust-on-first-use. Comparing the fingerprint
  # against a published value is what turns it into an actual check.
  local scanned tmp actual
  scanned="$(ssh-keyscan -t ssh-ed25519 github.com 2>/dev/null | grep -v '^#' || true)"
  [[ -n "$scanned" ]] || fail "ssh-keyscan returned nothing. Check outbound access to github.com on port 22."
  tmp="$(mktemp)"; printf '%s\n' "$scanned" > "$tmp"
  actual="$(ssh-keygen -lf "$tmp" | head -1 | awk '{print $2}')"
  rm -f "$tmp"
  if [[ "$actual" != "$EXPECTED_ED25519_FP" ]]; then
    fail "Host key fingerprint mismatch for github.com.
        expected $EXPECTED_ED25519_FP
        got      $actual
        Do NOT continue. Either GitHub rotated its key (check its published
        fingerprints page and update this script) or the connection is being
        intercepted."
  fi
  ok "fingerprint matches the published ed25519 key ($actual)"
  touch "$KNOWN_HOSTS"; chmod 600 "$KNOWN_HOSTS"
  ssh-keygen -R github.com >/dev/null 2>&1 || true
  printf '%s\n' "$scanned" >> "$KNOWN_HOSTS"
  ok "$KNOWN_HOSTS pinned (no first-connect prompt)"

  step "Writing the SSH config block"
  # Overriding Host github.com rather than using an alias means ordinary
  # git@github.com URLs work - which matters because the candidate's AI agent
  # will generate ordinary URLs. Safe only on a dedicated interview account.
  touch "$CONFIG"; chmod 600 "$CONFIG"
  if strip_managed_block; then
    warn "replaced an existing managed block"
  elif grep -qiE '^[[:space:]]*Host[[:space:]]+github\.com[[:space:]]*$' "$CONFIG"; then
    fail "$CONFIG already has an unmanaged 'Host github.com' block. Refusing to touch it. Remove it by hand, or run this on a clean interview account."
  fi
  cat >> "$CONFIG" <<EOF
$BEGIN_MARKER
Host github.com
  HostName github.com
  User git
  IdentityFile $key
  IdentitiesOnly yes
$END_MARKER
EOF
  chmod 600 "$CONFIG"
  ok "$CONFIG"

  if [[ -n "$cand_name" && -n "$cand_email" ]]; then
    step "Setting git commit identity"
    # A deploy key carries no GitHub account, so commits are attributed solely
    # by these values. Without them the history is anonymous.
    git config --global user.name  "$cand_name"
    git config --global user.email "$cand_email"
    ok "$cand_name <$cand_email>"
  else
    warn "No candidate name/email given. A deploy key carries no GitHub identity, so commits will use whatever git already has. Set them before the candidate commits."
  fi

  cat <<EOF

-------------------------------------------------------------------
 NEXT: add this public key as a deploy key WITH WRITE ACCESS
 https://github.com/$repo/settings/keys/new
-------------------------------------------------------------------

$(cat "$key.pub")

 Title it: $comment
 Tick 'Allow write access' or the candidate cannot push.

 Then run:
   $0 verify $surname $repo --clone

EOF
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$key.pub"; ok "public key copied to the clipboard"
  fi
}

do_verify() {
  local surname="$1" repo="$2" clone="${3:-}"
  validate_surname "$surname"; validate_repo "$repo"
  require_tools

  step "Testing the connection to github.com"
  # ssh -T against GitHub always exits non-zero (it never grants a shell), so
  # the exit code is not the signal - the greeting is.
  local out
  out="$(ssh -T -o StrictHostKeyChecking=yes -o BatchMode=yes git@github.com 2>&1 || true)"
  printf '    %s\n' "$out"

  if grep -q 'successfully authenticated' <<<"$out"; then
    if grep -qF "$repo" <<<"$out"; then
      ok "authenticated as the deploy key for $repo"
    else
      local who; who="$(sed -n 's/^Hi \([^!]*\)!.*/\1/p' <<<"$out")"
      if [[ "$who" == */* ]]; then
        fail "This key is a deploy key for '$who', not '$repo'. Wrong repository."
      fi
      warn "Authenticated as the user account '$who', not as a deploy key. A personal credential is in play - check that the intended deploy key is the one being offered."
    fi
  elif grep -q 'Permission denied' <<<"$out"; then
    fail "Permission denied. The public key is probably not registered on $repo yet, or was added without write access. Add it at https://github.com/$repo/settings/keys/new"
  elif grep -q 'Host key verification failed' <<<"$out"; then
    fail "Host key verification failed. Re-run setup to re-pin the host key."
  else
    fail "Unrecognised response. Investigate before the interview."
  fi

  if [[ "$clone" == "--clone" ]]; then
    local target="${repo#*/}"
    step "Cloning $repo"
    [[ -e "$target" ]] && fail "$target already exists in $PWD. Move it aside first."
    git clone "git@github.com:$repo.git"
    ok "cloned into $target"
    cat <<EOF

    Confirm the starting position:
      cd $target && git log --oneline && npm install && npm test
    Expect ONE commit. For the expected test result, see the runbook - it is
    deliberately not printed here, because this file sits on the same machine
    the candidate uses.
EOF
  fi
}

do_revoke() {
  local surname="$1"
  validate_surname "$surname"
  local key; key="$(key_path "$surname")"

  step "Removing local credentials for $surname"
  for p in "$key" "$key.pub"; do
    if [[ -e "$p" ]]; then rm -f "$p"; ok "deleted $p"; else warn "not present: $p"; fi
  done

  if strip_managed_block; then ok "removed the managed block from $CONFIG"
  else warn "no managed block in $CONFIG"; fi

  if [[ -f "$KNOWN_HOSTS" ]]; then
    ssh-keygen -R github.com >/dev/null 2>&1 || true
    ok "unpinned github.com from $KNOWN_HOSTS"
  fi

  cat <<'EOF'

EOF
  warn "Local files only. This does NOT revoke access."
  cat <<'EOF'
    Still to do, in this order:
      1. Delete the deploy key on GitHub  (repo > Settings > Deploy keys)
      2. Archive or delete the candidate repository
      3. Check for any stored HTTPS credential:
         macOS  - Keychain Access, search github
         Linux  - ~/.git-credentials and any credential helper cache
      4. Restore the laptop snapshot - see the runbook

EOF
}

[[ $# -ge 1 ]] || usage
case "$1" in
  setup)  [[ $# -ge 3 ]] || usage; do_setup  "$2" "$3" "${4:-}" "${5:-}" ;;
  verify) [[ $# -ge 3 ]] || usage; do_verify "$2" "$3" "${4:-}" ;;
  revoke) [[ $# -ge 2 ]] || usage; do_revoke "$2" ;;
  -h|--help|help) usage ;;
  *) fail "Unknown mode '$1'. Expected setup, verify or revoke." ;;
esac
