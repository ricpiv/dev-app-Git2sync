<#
.SYNOPSIS
    Sets up a Git repository with multiple remotes (GitLab and GitHub) for synchronization.
#>
param(
    # Full path to the project folder (target) OR the parent directory (root).
    # - If path exists: treated as Parent Directory (repo will be cloned inside).
    # - If path does not exist: treated as Target Directory (repo will be cloned as this name).
    [string]$Path,

    # GitLab repository URL (mandatory in all modes).
    [string]$GitLabUrl,

    # GitHub repository URL (mandatory in all modes).
    [string]$GitHubUrl,

    # Scenario:
    #  - FromGitLab : new project, clone from GitLab then add GitHub as extra push URL
    #  - FromGitHub : new project, clone from GitHub then add GitLab as extra push URL
    #  - Existing   : project folder already exists; fix/restore multi-remote setup
    [ValidateSet("FromGitLab", "FromGitHub", "Existing")]
    [string]$Mode,

    # When Mode = Existing, choose which remote should be treated as primary.
    # This determines which URL is used as the FETCH url of origin.
    [ValidateSet("GitLab", "GitHub")]
    [string]$Primary = "GitLab",

    # Optional: Configure local git user email
    [string]$UserEmail,

    # Optional: Configure local git user name
    [string]$UserName,

    # If set, pushes all branches and tags to origin after configuration.
    # This is disabled by default to avoid accidental pushes.
    [switch]$SyncNow
)

# --- Help / Usage Check ----------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Path) -or 
    [string]::IsNullOrWhiteSpace($GitLabUrl) -or 
    [string]::IsNullOrWhiteSpace($GitHubUrl) -or 
    [string]::IsNullOrWhiteSpace($Mode)) {
    
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "   Multi-Remote Git Sync Setup Helper" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script configures a local Git repository to sync with both GitLab and GitHub."
    Write-Host "It ensures that 'git push' updates both remotes simultaneously."
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Green
    Write-Host "  .\Setup-MultiRemoteSync.ps1 -Path <path> -GitLabUrl <url> -GitHubUrl <url> -Mode <mode> [options]"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Green
    Write-Host "  -Path         : Target project path OR Parent directory."
    Write-Host "                  - If folder exists: Repo is cloned INSIDE this folder."
    Write-Host "                  - If folder missing: Repo is cloned AS this folder."
    Write-Host "  -GitLabUrl    : URL of the GitLab repository."
    Write-Host "  -GitHubUrl    : URL of the GitHub repository."
    Write-Host "  -Mode         : One of the following:"
    Write-Host "                  'FromGitLab' : Clone from GitLab, add GitHub as mirror."
    Write-Host "                  'FromGitHub' : Clone from GitHub, add GitLab as mirror."
    Write-Host "                  'Existing'   : Configure an existing local repo."
    Write-Host "  -Primary      : (Optional) Which remote to fetch from (Default: GitLab)."
    Write-Host "  -UserEmail    : (Optional) Set 'user.email' for this repo."
    Write-Host "  -UserName     : (Optional) Set 'user.name' for this repo."
    Write-Host "  -SyncNow      : (Optional) Immediately push all branches/tags to both remotes."
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  1. Clone from GitLab into C:\Repos (creates C:\Repos\MyApp):"
    Write-Host "     .\Setup-MultiRemoteSync.ps1 -Path 'C:\Repos' -GitLabUrl '...' -GitHubUrl '...' -Mode FromGitLab"
    Write-Host ""
    Write-Host "  2. Clone from GitLab as specific folder C:\Apps\MyNewApp:"
    Write-Host "     .\Setup-MultiRemoteSync.ps1 -Path 'C:\Apps\MyNewApp' -GitLabUrl '...' -GitHubUrl '...' -Mode FromGitLab"
    Write-Host ""
    exit 0
}

function Fail($msg) {
    Write-Error $msg
    exit 1
}

# --- Check prerequisites ---------------------------------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git command not found. Install Git and ensure it's in PATH."
}

# Normalize path
$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if ($resolvedPath) {
    $Path = $resolvedPath.Path
}

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

# --- Helper: Get Repo Name from URL ---------------------------------------
function Get-RepoName([string]$url) {
    return ($url -split '/')[-1] -replace '\.git$', ''
}

# --- Helper: Check if repo is empty ---------------------------------------
function Test-RepoEmpty {
    # If HEAD doesn't resolve to a commit, it's likely empty (or corrupt, but we assume empty for new clones)
    git rev-parse --verify HEAD 2>&1 | Out-Null
    return $LASTEXITCODE -ne 0
}

# --- Helper: Configure Git Identity ---------------------------------------
function Configure-Identity {
    if (-not [string]::IsNullOrWhiteSpace($UserEmail)) {
        Write-Host "Setting user.email to: $UserEmail"
        git config user.email $UserEmail
        if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to set user.email" }
    }
    if (-not [string]::IsNullOrWhiteSpace($UserName)) {
        Write-Host "Setting user.name to: $UserName"
        git config user.name $UserName
        if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to set user.name" }
    }
}

# --- Mode handling ---------------------------------------------------------

switch ($Mode) {

    "FromGitLab" {
        $TargetDir = $Path
        $ParentDir = $null
        
        if (Test-Path -LiteralPath $Path) {
            # Path exists -> Treat as Parent
            $repoName = Get-RepoName $GitLabUrl
            $TargetDir = Join-Path $Path $repoName
            $ParentDir = $Path
            if (Test-Path -LiteralPath $TargetDir) {
                Fail "Mode 'FromGitLab': Target folder already exists: $TargetDir"
            }
            Write-Host "Path '$Path' exists. Cloning '$repoName' inside it."
        } else {
            # Path does not exist -> Treat as Target
            Ensure-ParentDir $Path
            $ParentDir = Split-Path -Parent $Path
        }

        Write-Host "Cloning from GitLab into: $TargetDir"
        Write-Host "Command: git clone `"$GitLabUrl`" `"$TargetDir`"" -ForegroundColor Gray
        
        # Use Start-Process to ensure output is visible and not swallowed
        $proc = Start-Process -FilePath "git" -ArgumentList "clone `"$GitLabUrl`" `"$TargetDir`"" -NoNewWindow -Wait -PassThru
        
        if ($proc.ExitCode -ne 0) { 
            Fail "git clone from GitLab failed (Exit Code: $($proc.ExitCode))." 
        }

        if (-not (Test-Path -LiteralPath $TargetDir)) {
            Write-Host "⚠️  DEBUG: Target directory NOT found: $TargetDir" -ForegroundColor Red
            if ($ParentDir) {
                Write-Host "Contents of parent directory ($ParentDir):" -ForegroundColor Gray
                Get-ChildItem -LiteralPath $ParentDir | Select-Object Name, Mode, LastWriteTime | Format-Table -AutoSize
            }
            Fail "Git clone appeared to succeed, but target directory was not created: $TargetDir"
        }

        Set-Location $TargetDir -ErrorAction Stop

        # Configure Identity
        Configure-Identity

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
        
        if (Test-RepoEmpty) {
            Write-Host "⚠️  WARNING: Repository appears to be empty (no commits)." -ForegroundColor Yellow
            Write-Host "   You must create a commit (e.g. 'git commit --allow-empty -m \"Initial commit\"') before pushing." -ForegroundColor Yellow
        }
    }

    "FromGitHub" {
        $TargetDir = $Path
        $ParentDir = $null
        
        if (Test-Path -LiteralPath $Path) {
            # Path exists -> Treat as Parent
            $repoName = Get-RepoName $GitHubUrl
            $TargetDir = Join-Path $Path $repoName
            $ParentDir = $Path
            if (Test-Path -LiteralPath $TargetDir) {
                Fail "Mode 'FromGitHub': Target folder already exists: $TargetDir"
            }
            Write-Host "Path '$Path' exists. Cloning '$repoName' inside it."
        } else {
            # Path does not exist -> Treat as Target
            Ensure-ParentDir $Path
            $ParentDir = Split-Path -Parent $Path
        }

        Write-Host "Cloning from GitHub into: $TargetDir"
        Write-Host "Command: git clone `"$GitHubUrl`" `"$TargetDir`"" -ForegroundColor Gray

        # Use Start-Process to ensure output is visible and not swallowed
        $proc = Start-Process -FilePath "git" -ArgumentList "clone `"$GitHubUrl`" `"$TargetDir`"" -NoNewWindow -Wait -PassThru

        if ($proc.ExitCode -ne 0) { 
            Fail "git clone from GitHub failed (Exit Code: $($proc.ExitCode))." 
        }

        if (-not (Test-Path -LiteralPath $TargetDir)) {
            Write-Host "⚠️  DEBUG: Target directory NOT found: $TargetDir" -ForegroundColor Red
            if ($ParentDir) {
                Write-Host "Contents of parent directory ($ParentDir):" -ForegroundColor Gray
                Get-ChildItem -LiteralPath $ParentDir | Select-Object Name, Mode, LastWriteTime | Format-Table -AutoSize
            }
            Fail "Git clone appeared to succeed, but target directory was not created: $TargetDir"
        }

        Set-Location $TargetDir -ErrorAction Stop

        # Configure Identity
        Configure-Identity

        # Ensure origin fetch = GitHub, add GitLab as extra push URL
        git remote set-url origin $GitHubUrl  | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail "Failed to set origin URL to GitHub." }

        $remotes = git remote -v
        if ($remotes -notmatch [regex]::Escape($GitLabUrl)) {
            git remote set-url --add origin $GitLabUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "Failed to add GitLab as additional push URL." }
        }

        Write-Host "✅ Multi-remote configured (primary: GitHub, mirror: GitLab)."
        
        if (Test-RepoEmpty) {
            Write-Host "⚠️  WARNING: Repository appears to be empty (no commits)." -ForegroundColor Yellow
            Write-Host "   You must create a commit (e.g. 'git commit --allow-empty -m \"Initial commit\"') before pushing." -ForegroundColor Yellow
        }
    }

    "Existing" {
        if (-not (Test-Path -LiteralPath $Path)) {
            Fail "Mode 'Existing': project folder does not exist: $Path"
        }

        Set-Location $Path -ErrorAction Stop

        # Check that it's a git repo
        $isRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0 -or $isRepo -ne "true") {
            Fail "Mode 'Existing': $Path is not a Git repository."
        }

        # Configure Identity
        Configure-Identity

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
        if ($Primary -eq "GitLab") {
            $primaryUrl   = $GitLabUrl
            $secondaryUrl = $GitHubUrl
        } else {
            $primaryUrl   = $GitHubUrl
            $secondaryUrl = $GitLabUrl
        }

        Write-Host "Setting origin primary (fetch) to $($Primary): $primaryUrl"
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
    if (Test-RepoEmpty) {
        Write-Host "`n⚠️  Skipping -SyncNow because the repository is empty." -ForegroundColor Yellow
        Write-Host "   Create a commit first, then run 'git push origin --all'" -ForegroundColor Yellow
    } else {
        Write-Host "`nPushing all branches and tags to origin (all configured push URLs)..."
        git push origin --all
        if ($LASTEXITCODE -ne 0) { Fail "Failed to push branches." }

        git push origin --tags
        if ($LASTEXITCODE -ne 0) { Fail "Failed to push tags." }

        Write-Host "✅ Sync complete."
    }
} else {
    Write-Host "`n(no automatic push performed; use -SyncNow to push branches/tags)"
}
