# Experiment script for pushing a feature branch to origin
# Usage: run this from anywhere; the script will use its own repository directory.
# Example: . '\path\to\qingfood-health\experiment_push_feature_branch.ps1' -BranchSuffix 1

Param(
    [string]$BranchSuffix = ''
)

Set-StrictMode -Version Latest

Write-Host "=== Git feature branch push experiment ==="

# Use the script directory as the Git repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
$repoRoot = Resolve-Path .
Write-Host "Repository root: $repoRoot"

# Show current branch and remotes
Write-Host "Current status:"
git status --short
Write-Host "Current branch:"
git branch --show-current
Write-Host "Remote origin:"
git remote -v

# Interactive branch selection
if (-not $PSBoundParameters.ContainsKey('BranchSuffix') -or [string]::IsNullOrWhiteSpace($BranchSuffix)) {
    $inputValue = Read-Host "请输入要推送的 feature 分支后缀或完整分支名（例如 1 或 feature/1），直接回车默认 feature/1"
    if ([string]::IsNullOrWhiteSpace($inputValue)) {
        $inputValue = '1'
    }
    if ($inputValue -match '^feature/') {
        $branchName = $inputValue
    } else {
        $branchName = "feature/$inputValue"
    }
} else {
    if ($BranchSuffix -match '^feature/') {
        $branchName = $BranchSuffix
    } else {
        $branchName = "feature/$BranchSuffix"
    }
}

$branchName = $branchName.Trim()
Write-Host "目标分支：$branchName"

# Ensure origin is correct
$expectedRemote = 'https://github.com/sunset-cdy/qingfood-health.git'
$remoteExists = git remote | Select-String -Pattern '^origin$' -Quiet
if (-not $remoteExists) {
    Write-Host "添加 origin 远程：$expectedRemote"
    git remote add origin $expectedRemote
} else {
    $remoteUrl = git remote get-url origin
    if ($remoteUrl -ne $expectedRemote) {
        Write-Host "设置 origin 为预期远程：$expectedRemote"
        git remote set-url origin $expectedRemote
    }
}

# Fetch all remote heads
Write-Host "Fetching origin..."
git fetch origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: fetch failed with exit code $LASTEXITCODE. Please verify remote and network connectivity."
}

# Determine base branch (main or master)
$possibleBases = @('main','master')
$baseBranch = $null
foreach ($branch in $possibleBases) {
    if (git show-ref --verify --quiet "refs/heads/$branch") {
        $baseBranch = $branch
        break
    }
}
if (-not $baseBranch) {
    Write-Host "未找到本地 main 或 master 分支，尝试使用 origin/main 或 origin/master..."
    foreach ($branch in $possibleBases) {
        if (git ls-remote --heads origin $branch) {
            $baseBranch = $branch
            break
        }
    }
}
if (-not $baseBranch) {
    throw "No main/master branch found locally or on origin."
}
Write-Host "Using base branch: $baseBranch"

# Create or checkout the feature branch
$branches = git branch --format '%(refname:short)'
if ($branches -notcontains $branchName) {
    Write-Host "Creating local branch $branchName from $baseBranch..."
    git checkout $baseBranch
    git pull origin $baseBranch
    git checkout -b $branchName
} else {
    Write-Host "Local branch $branchName already exists."
    $answer = Read-Host "是否切换到该分支并继续推送？(Y/N)"
    if ($answer.Trim().ToUpper() -ne 'Y') {
        Write-Host "操作已取消。"
        exit 0
    }
    git checkout $branchName
}

Write-Host "当前分支："
git branch --show-current

# Confirm push
$confirmPush = Read-Host "是否将 $branchName 推送到 origin? 输入 Y 确认，否则取消"
if ($confirmPush.Trim().ToUpper() -ne 'Y') {
    Write-Host "推送已取消。"
    exit 0
}

Write-Host "Pushing $branchName to origin..."
git push -u origin $branchName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed with exit code $LASTEXITCODE. 请检查网络连接和远程权限。"
    exit $LASTEXITCODE
}

Write-Host "Experiment complete. 分支 $branchName 已推送到 origin。"
