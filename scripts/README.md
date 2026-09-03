# Interview laptop scripts

Helpers for preparing a company-provided laptop so a candidate can clone and
push to a single private repository during a technical interview, and so the
credential can be removed cleanly afterwards.

Published here for convenience: the laptop can fetch these without being signed
in to anything first.

## Prepare-InterviewDeployKey.ps1 (Windows) / prepare-interview-deploy-key.sh (macOS)

Both do the same job in three modes.

| Mode | What it does |
|---|---|
| `setup` | Generates a dedicated ed25519 keypair, pins GitHub's host key, writes a marked block into the SSH config, sets the git commit identity, prints the public key to register |
| `verify` | Confirms GitHub answers as the deploy key for the expected repository; optionally clones |
| `revoke` | Removes the key, the config block and the pinned host key from the device |

```powershell
# Windows
.\Prepare-InterviewDeployKey.ps1 -Setup -Surname smith `
    -Repo <owner>/<repo> -CandidateName "Jane Smith" -CandidateEmail jane@example.com
.\Prepare-InterviewDeployKey.ps1 -Verify -Repo <owner>/<repo> -Clone
.\Prepare-InterviewDeployKey.ps1 -Revoke -Surname smith
```

```bash
# macOS
./prepare-interview-deploy-key.sh setup  smith <owner>/<repo> "Jane Smith" jane@example.com
./prepare-interview-deploy-key.sh verify smith <owner>/<repo> --clone
./prepare-interview-deploy-key.sh revoke smith
```

## Why a deploy key

A deploy key is scoped to exactly one repository, and GitHub enforces that a key
attached to one repository cannot be attached to another. That is a stronger
guarantee than a token scope: it is structural, not a setting someone can widen.

## Behaviour worth knowing

- **Refuses to overwrite an existing key.** That key may already be registered
  on a repository; replacing it silently breaks access you believe you have.
- **Verifies GitHub's host key fingerprint against the published value before
  pinning it.** `ssh-keyscan` on its own is trust-on-first-use; the comparison is
  what makes it a check. A mismatch aborts rather than warns. Update the expected
  fingerprint in both scripts when GitHub rotates its host keys.
- **Writes a marked, managed block** into `~/.ssh/config`, so `revoke` removes
  exactly what `setup` added. It refuses to touch a pre-existing
  `Host github.com` block rather than clobbering it.
- **Overrides `Host github.com` rather than using an alias**, so ordinary
  `git@github.com:owner/repo.git` URLs work. Only appropriate on a dedicated
  machine or account.
- **Sets `user.name` and `user.email`.** A deploy key carries no GitHub account,
  so commits are attributed solely by these values and appear as an unlinked
  author. Without them the history is anonymous.

## Two things `revoke` does not do

1. **It does not revoke access.** Deleting the deploy key on GitHub
   (repository → Settings → Deploy keys) is what removes access. `revoke` only
   clears the device.
2. **It does not touch other credential stores.** An HTTPS credential lands in
   Windows Credential Manager (`cmdkey /list`) or `%USERPROFILE%\.gcm\dpapi_store`,
   and editor extensions may hold API keys in their own settings files. Restoring
   a machine image is the only reliable way to be sure.

## Caveat

A write-enabled deploy key can do what a repository admin can on that one
repository, including force-push and branch deletion. Appropriate for a
throwaway per-candidate repository; not for anything shared.
