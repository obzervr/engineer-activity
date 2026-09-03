<#
.SYNOPSIS
  Prepares a per-candidate GitHub deploy key on an interview laptop (Windows).

.DESCRIPTION
  Generates a dedicated ed25519 keypair, pins GitHub's host key after verifying
  its fingerprint against Anthropic-independent published values, writes a
  managed block into the SSH config so ordinary github.com URLs resolve to this
  key, and prints the public half for pasting into the repository's deploy keys
  page.

  Run -Setup before the candidate arrives, -Verify after adding the key on
  GitHub, and -Revoke immediately after the interview.

  Deliberately does nothing destructive without -Revoke, and refuses to
  overwrite an existing key or an unmanaged SSH config block.

.PARAMETER Setup
  Generate the key, pin the host key, write the SSH config block.

.PARAMETER Verify
  Test the connection and confirm GitHub answers as the expected repository.

.PARAMETER Clone
  Clone the repository after a successful verify.

.PARAMETER Revoke
  Remove the key, the config block and the pinned host key from this device.

.PARAMETER Surname
  Candidate surname, used in the key filename and comment. Required except for -Verify.

.PARAMETER Repo
  Target repository as owner/name, e.g. obzervr/tech-interview.int-eng-smith.

.PARAMETER CandidateName
  Candidate's display name for git commit attribution.

.PARAMETER CandidateEmail
  Candidate's email for git commit attribution.

.EXAMPLE
  .\Prepare-InterviewDeployKey.ps1 -Setup -Surname smith -Repo obzervr/tech-interview.int-eng-smith
.EXAMPLE
  .\Prepare-InterviewDeployKey.ps1 -Verify -Repo obzervr/tech-interview.int-eng-smith
.EXAMPLE
  .\Prepare-InterviewDeployKey.ps1 -Revoke -Surname smith
#>

[CmdletBinding(DefaultParameterSetName = 'Setup')]
param(
  [Parameter(ParameterSetName = 'Setup', Mandatory)][switch]$Setup,
  [Parameter(ParameterSetName = 'Verify', Mandatory)][switch]$Verify,
  [Parameter(ParameterSetName = 'Revoke', Mandatory)][switch]$Revoke,

  [Parameter(ParameterSetName = 'Setup', Mandatory)]
  [Parameter(ParameterSetName = 'Revoke', Mandatory)]
  [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,38}$')]
  [string]$Surname,

  [Parameter(ParameterSetName = 'Setup', Mandatory)]
  [Parameter(ParameterSetName = 'Verify', Mandatory)]
  [ValidatePattern('^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$')]
  [string]$Repo,

  [Parameter(ParameterSetName = 'Setup')][string]$CandidateName,
  [Parameter(ParameterSetName = 'Setup')][string]$CandidateEmail,
  [Parameter(ParameterSetName = 'Verify')][switch]$Clone
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# GitHub's published host key fingerprints. Verified against
# docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# on 3 September 2026. GitHub rotates these (the RSA key was rotated in March
# 2023), so re-check them against that page each interview cycle.
$ExpectedFingerprints = @{
  'ssh-ed25519'         = 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'
  'ecdsa-sha2-nistp256' = 'SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM'
  'ssh-rsa'             = 'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s'
}
$PinnedKeyType = 'ssh-ed25519'

$SshDir      = Join-Path $env:USERPROFILE '.ssh'
$ConfigPath  = Join-Path $SshDir 'config'
$KnownHosts  = Join-Path $SshDir 'known_hosts'
$BeginMarker = '# BEGIN obzervr-interview (managed, safe to delete)'
$EndMarker   = '# END obzervr-interview'

function Write-Step  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    ok  $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "    !!  $m" -ForegroundColor Yellow }
function Fail        { param($m) Write-Host "    XX  $m" -ForegroundColor Red; exit 1 }

function Assert-OpenSsh {
  foreach ($tool in 'ssh-keygen', 'ssh-keyscan', 'ssh') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
      Fail "$tool not found. Install the Windows OpenSSH Client: Settings > System > Optional features > Add > OpenSSH Client."
    }
  }
}

function Lock-ToCurrentUser {
  param([string]$Path)
  # OpenSSH on Windows refuses a private key that other principals can read.
  # Break inheritance and grant only the current user.
  & icacls $Path /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Warn2 "icacls did not report success for $Path; check permissions manually." }
}

function Get-KeyPaths {
  param([string]$Surname)
  $base = Join-Path $SshDir ("id_ed25519_interview_{0}" -f $Surname.ToLower())
  [pscustomobject]@{ Private = $base; Public = "$base.pub" }
}

function Invoke-Setup {
  Assert-OpenSsh
  $keys = Get-KeyPaths -Surname $Surname

  Write-Step "Preparing $SshDir"
  if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Path $SshDir -Force | Out-Null }
  Lock-ToCurrentUser $SshDir
  Write-Ok $SshDir

  Write-Step "Generating the deploy keypair"
  if (Test-Path $keys.Private) {
    Fail "$($keys.Private) already exists. Run -Revoke for this surname first, or pick a different -Surname. Refusing to overwrite a key that may already be registered on a repository."
  }
  $comment = "interview-{0}-{1}" -f $Surname.ToLower(), (Get-Date -Format 'yyyyMM')
  & ssh-keygen -t ed25519 -C $comment -f $keys.Private -N '""' | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keys.Private)) { Fail "ssh-keygen failed." }
  Lock-ToCurrentUser $keys.Private
  Write-Ok "$($keys.Private) (comment: $comment)"

  Write-Step "Pinning github.com host key"
  # Verify before trusting. ssh-keyscan alone is trust-on-first-use; comparing
  # the fingerprint to a published value is what makes it a real check.
  $scanned = & ssh-keyscan -t $PinnedKeyType github.com 2>$null |
             Where-Object { $_ -and -not $_.StartsWith('#') }
  if (-not $scanned) { Fail "ssh-keyscan returned nothing. Check outbound access to github.com on port 22." }

  $tmp = New-TemporaryFile
  try {
    Set-Content -Path $tmp -Value $scanned -Encoding ascii
    $fpLine = (& ssh-keygen -lf $tmp | Select-Object -First 1)
    $actual = ($fpLine -split '\s+')[1]
    $expected = $ExpectedFingerprints[$PinnedKeyType]
    if ($actual -ne $expected) {
      Fail "Host key fingerprint mismatch for github.com.`n        expected $expected`n        got      $actual`n        Do NOT continue. Either GitHub rotated its key (check its published fingerprints page and update this script) or the connection is being intercepted."
    }
    Write-Ok "fingerprint matches published $PinnedKeyType key ($actual)"

    if (Test-Path $KnownHosts) {
      $existing = Get-Content $KnownHosts | Where-Object { $_ -notmatch '^github\.com\s' }
      Set-Content -Path $KnownHosts -Value $existing -Encoding ascii
    }
    Add-Content -Path $KnownHosts -Value $scanned -Encoding ascii
    Lock-ToCurrentUser $KnownHosts
    Write-Ok "$KnownHosts pinned (no first-connect prompt)"
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }

  Write-Step "Writing the SSH config block"
  # Overriding Host github.com (rather than using an alias) means ordinary
  # git@github.com URLs work, which matters because the candidate's AI agent
  # will generate ordinary URLs. Safe here only because this is a dedicated
  # interview account.
  if (Test-Path $ConfigPath) {
    $cfg = Get-Content $ConfigPath -Raw
    if ($cfg -match [regex]::Escape($BeginMarker)) {
      $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker) + '\r?\n?'
      $cfg = [regex]::Replace($cfg, $pattern, '')
      Set-Content -Path $ConfigPath -Value $cfg -Encoding ascii -NoNewline
      Write-Warn2 "replaced an existing managed block"
    } elseif ($cfg -match '(?im)^\s*Host\s+github\.com\s*$') {
      Fail "$ConfigPath already has an unmanaged 'Host github.com' block. Refusing to touch it. Remove it by hand, or run this on a clean interview account."
    }
  }
  $block = @"
$BeginMarker
Host github.com
  HostName github.com
  User git
  IdentityFile $($keys.Private)
  IdentitiesOnly yes
$EndMarker
"@
  Add-Content -Path $ConfigPath -Value $block -Encoding ascii
  Lock-ToCurrentUser $ConfigPath
  Write-Ok "$ConfigPath"

  if ($CandidateName -and $CandidateEmail) {
    Write-Step "Setting git commit identity"
    # A deploy key has no GitHub account, so commits are attributed solely by
    # these values. Without them the history is anonymous.
    & git config --global user.name  $CandidateName
    & git config --global user.email $CandidateEmail
    Write-Ok "$CandidateName <$CandidateEmail>"
  } else {
    Write-Warn2 "No -CandidateName/-CandidateEmail given. A deploy key carries no GitHub identity, so commits will use whatever git already has. Set them before the candidate commits."
  }

  Write-Host ""
  Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
  Write-Host " NEXT: add this public key as a deploy key WITH WRITE ACCESS" -ForegroundColor Cyan
  Write-Host " https://github.com/$Repo/settings/keys/new" -ForegroundColor Cyan
  Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
  Write-Host ""
  Get-Content $keys.Public
  Write-Host ""
  Write-Host " Title it: $comment"
  Write-Host " Tick 'Allow write access' or the candidate cannot push."
  Write-Host ""
  Write-Host " Then run:"
  Write-Host "   .\Prepare-InterviewDeployKey.ps1 -Verify -Repo $Repo -Clone"
  Write-Host ""
  if (Get-Command clip -ErrorAction SilentlyContinue) {
    Get-Content $keys.Public | clip
    Write-Ok "public key copied to the clipboard"
  }
}

function Invoke-Verify {
  Assert-OpenSsh
  Write-Step "Testing the connection to github.com"
  # ssh -T against GitHub always exits non-zero (it never grants a shell), so
  # the exit code is not the signal - the greeting is.
  $out = & ssh -T -o StrictHostKeyChecking=yes -o BatchMode=yes git@github.com 2>&1 | Out-String
  $out = $out.Trim()
  Write-Host "    $out"

  if ($out -match 'successfully authenticated') {
    if ($out -match [regex]::Escape($Repo)) {
      Write-Ok "authenticated as the deploy key for $Repo"
    } elseif ($out -match 'Hi\s+([^!]+)!') {
      $who = $Matches[1]
      if ($who -match '/') {
        Fail "This key is a deploy key for '$who', not '$Repo'. Wrong repository."
      }
      Write-Warn2 "Authenticated as the user account '$who', not as a deploy key. A personal account credential is in play - check that the intended deploy key is the one being offered."
    }
  } elseif ($out -match 'Permission denied') {
    Fail "Permission denied. The public key is probably not registered on $Repo yet, or was added without write access. Add it at https://github.com/$Repo/settings/keys/new"
  } elseif ($out -match 'Host key verification failed') {
    Fail "Host key verification failed. Re-run -Setup to re-pin the host key."
  } else {
    Fail "Unrecognised response. Investigate before the interview."
  }

  if ($Clone) {
    $target = ($Repo -split '/')[1]
    Write-Step "Cloning $Repo"
    if (Test-Path $target) { Fail "$target already exists in $(Get-Location). Move it aside first." }
    & git clone "git@github.com:$Repo.git"
    if ($LASTEXITCODE -ne 0) { Fail "git clone failed." }
    Write-Ok "cloned into $target"
    Write-Host ""
    Write-Host "    Confirm the starting position:" -ForegroundColor Cyan
    Write-Host "      cd $target; git log --oneline; npm install; npm test"
    Write-Host "    Expect ONE commit. For the expected test result, see the runbook -"
    Write-Host "    it is deliberately not printed here, because this file sits on the"
    Write-Host "    same machine the candidate uses."
  }
}

function Invoke-Revoke {
  $keys = Get-KeyPaths -Surname $Surname
  Write-Step "Removing local credentials for $Surname"

  foreach ($p in @($keys.Private, $keys.Public)) {
    if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "deleted $p" }
    else { Write-Warn2 "not present: $p" }
  }

  if (Test-Path $ConfigPath) {
    $cfg = Get-Content $ConfigPath -Raw
    if ($cfg -match [regex]::Escape($BeginMarker)) {
      $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker) + '\r?\n?'
      Set-Content -Path $ConfigPath -Value ([regex]::Replace($cfg, $pattern, '')) -Encoding ascii -NoNewline
      Write-Ok "removed the managed block from $ConfigPath"
    } else { Write-Warn2 "no managed block in $ConfigPath" }
  }

  if (Test-Path $KnownHosts) {
    & ssh-keygen -R github.com 2>$null | Out-Null
    Write-Ok "unpinned github.com from $KnownHosts"
  }

  Write-Host ""
  Write-Warn2 "Local files only. This does NOT revoke access."
  Write-Host "    Still to do, in this order:"
  Write-Host "      1. Delete the deploy key on GitHub  (repo > Settings > Deploy keys)"
  Write-Host "      2. Archive or delete the candidate repository"
  Write-Host "      3. Check Windows Credential Manager for any HTTPS credential:  cmdkey /list"
  Write-Host "         and %USERPROFILE%\.gcm\dpapi_store"
  Write-Host "      4. Restore the laptop snapshot - see the runbook"
  Write-Host ""
}

switch ($PSCmdlet.ParameterSetName) {
  'Setup'  { Invoke-Setup }
  'Verify' { Invoke-Verify }
  'Revoke' { Invoke-Revoke }
}
