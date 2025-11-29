param(
    # Full path (or relative) to the project folder on disk.
    # - For new projects: folder will be created (parent must exist).
    # - For existing projects: folder must already exist and contain a .git directory.
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    # GitLab repository URL (mandatory in all modes).
    [Parameter(Mandatory = $true)]
    [string]$GitLabUrl,

    # GitHub repository URL (mandatory in all modes).
    [Parameter(Mandatory = $true)]
    [string]$GitHubUrl,

    # Scenario:
    #  - FromGitLab : new project, clone from GitLab then add GitHub as extra push URL
    #  - FromGitHub : new project, clone from GitHub then add GitLab as extra push URL
    #  - Existing   : project folder already exists; fix/restore multi-remote setup
    [Parameter(Mandatory = $true)]
    [ValidateSet("FromGitLab", "FromGitHub", "Existing")]
    [string]$Mode,

    # When Mode = Existing, choose which remote should be treated as primary.
    # This determines which URL is used as the FETCH url of origin.
    [ValidateSet("GitLab", "GitHub")]
    [string]$Primary = "GitLab",

    # If set, pushes all branches and tags to origin after configuration.
    # This is disabled by default to avoid accidental pushes.
    [switch]$SyncNow
)

function Fail($msg) {
    Write-Error $msg
    exit 1
}

# --- Check prerequisites ---------------------------------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git command not found. Install Git and ensure it's in PATH."
}

# Normalize path
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction SilentlyContinue)?.Path ?? $ProjectPath

$projectDirExists = Test-Path -LiteralPath $ProjectPath

# --- Helper: ensure parent directory exists -------------------------------

function Ensure-ParentDir([string]$path) {
    $parent = Split-Path -Parent $path
    if (-not $parent) {
        return
    }
    if (-not (Test-Path -LiteralPath $parent)) {
        Fail "Parent directory does not exist: $parent"
    }
}

# --- Mode handling ---------------------------------------------------------

switch ($Mode) {

    "FromGitLab" {
        if ($projectDirExists) {
            Fail "Mode 'FromGitLab': project folder already exists: $ProjectPath"
        }

        Ensure-ParentDir $ProjectPath

        Write-Host "Cloning from GitLab into: $ProjectPath"
        git clone $GitLabUrl $ProjectPath
        if ($LASTEXITCODE -ne 0) { Fail "git clone from GitLab failed." }

        Set-Location $ProjectPath

        # Ensure origin fetch = GitLab, add GitHub as extra push URL
        git remote set-url origin $GitLabUrl  | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail "Failed to set origin URL to GitLab." }

        # Add GitHub as additional push URL if not present
        $remotes = git remote -v
        if ($remotes -notmatch [regex]::Escape($GitHubUrl)) {
            git remote set-url --add origin $GitHubUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "Failed to add GitHub as additional push URL." }
        }

        Write-Host "✅ Multi-remote configured (primary: GitLab, mirror: GitHub)."
    }

    "FromGitHub" {
        if ($projectDirExists) {
            Fail "Mode 'FromGitHub': project folder already exists: $ProjectPath"
        }

        Ensure-ParentDir $ProjectPath

        Write-Host "Cloning from GitHub into: $ProjectPath"
        git clone $GitHubUrl $ProjectPath
        if ($LASTEXITCODE -ne 0) { Fail "git clone from GitHub failed." }

        Set-Location $ProjectPath

        # Ensure origin fetch = GitHub, add GitLab as extra push URL
        git remote set-url origin $GitHubUrl  | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail "Failed to set origin URL to GitHub." }

        $remotes = git remote -v
        if ($remotes -notmatch [regex]::Escape($GitLabUrl)) {
            git remote set-url --add origin $GitLabUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "Failed to add GitLab as additional push URL." }
        }

        Write-Host "✅ Multi-remote configured (primary: GitHub, mirror: GitLab)."
    }

    "Existing" {
        if (-not $projectDirExists) {
            Fail "Mode 'Existing': project folder does not exist: $ProjectPath"
        }

        Set-Location $ProjectPath

        # Check that it's a git repo
        $isRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0 -or $isRepo -ne "true") {
            Fail "Mode 'Existing': $ProjectPath is not a Git repository."
        }

        # Ensure origin exists (or create it)
        $originExists = $false
        $remotesList = git remote 2>$null
        if ($LASTEXITCODE -eq 0 -and $remotesList -match "^origin$") {
            $originExists = $true
        }

        if (-not $originExists) {
            Write-Host "No 'origin' remote found. Creating one."
            git remote add origin $GitLabUrl 2>$null
            if ($LASTEXITCODE -ne 0) {
                Fail "Failed to create 'origin' remote. Check URLs and repo state."
            }
        }

        # Decide primary URL based on parameter
        $primaryUrl   = ($Primary -eq "GitLab") ? $GitLabUrl : $GitHubUrl
        $secondaryUrl = ($Primary -eq "GitLab") ? $GitHubUrl : $GitLabUrl

        Write-Host "Setting origin primary (fetch) to $Primary: $primaryUrl"
        git remote set-url origin $primaryUrl | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail "Failed to set origin primary URL." }

        # Make sure secondary URL is present as a push URL
        $remotes = git remote -v
        if ($remotes -notmatch [regex]::Escape($secondaryUrl)) {
            Write-Host "Adding secondary push URL: $secondaryUrl"
            git remote set-url --add origin $secondaryUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "Failed to add secondary push URL." }
        } else {
            Write-Host "Secondary push URL is already configured."
        }

        Write-Host "✅ Existing repo updated for multi-remote sync (primary: $Primary)."
    }
}

Write-Host "`nCurrent remotes:"
git remote -v

if ($SyncNow) {
    Write-Host "`nPushing all branches and tags to origin (all configured push URLs)..."
    git push origin --all
    if ($LASTEXITCODE -ne 0) { Fail "Failed to push branches." }

    git push origin --tags
    if ($LASTEXITCODE -ne 0) { Fail "Failed to push tags." }

    Write-Host "✅ Sync complete."
} else {
    Write-Host "`n(no automatic push performed; use -SyncNow to push branches/tags)"
}
