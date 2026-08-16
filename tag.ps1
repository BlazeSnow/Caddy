<#
.SYNOPSIS
  根据 CHANGELOG.md 的最新版本创建并推送 git tag，触发 GitHub Actions 自动发布 Release。

.DESCRIPTION
  version.yml 在推送 v* 格式的 tag 时自动创建 Release（含 -beta 后缀的 tag 会标为 Prerelease）。
  本脚本默认读取 CHANGELOG.md 中最新的 "## vX.Y.Z" 版本号作为 tag；也可以用 -Tag 显式指定。
  使用 -Beta 时打 beta 预发布 tag（vX.Y.Z-beta.N），序号 N 自动取当前最大 +1。
  执行前会打印将要执行的操作并要求输入 y 确认，输入其他内容则直接取消、不做任何改动。

.PARAMETER Tag
  要打的版本号。稳定版为 vX.Y.Z（例如 v1.5.0）；配合 -Beta 时只需给基础版本 vX.Y.Z，
  beta 序号自动递增。缺省时从 CHANGELOG.md 读取最新版本。

.PARAMETER Beta
  打 beta 预发布 tag：vX.Y.Z-beta.N（N 自动递增，如 v1.4.4-beta.1、v1.4.4-beta.2）。
  推送该 tag 会触发 build.yml 构建 beta 镜像，并由 version.yml 创建 Prerelease。

.PARAMETER NoPush
  只创建 tag，不推送到远程（不会触发任何工作流）。

.EXAMPLE
  .\tag.ps1                       # 稳定版：v1.4.4
  .\tag.ps1 -Beta                 # beta：v1.4.4-beta.N
  .\tag.ps1 -Tag v1.5.0           # 指定稳定版
  .\tag.ps1 -Tag v1.5.0 -Beta     # 指定基础版本的 beta
  .\tag.ps1 -Beta -NoPush         # 只创建本地 beta tag
#>

[CmdletBinding()]
param(
    [string]$Tag,
    [switch]$Beta,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $RepoRoot
try {
    # 1. 确定基础版本号：优先用 -Tag，否则从 CHANGELOG.md 读取
    if (-not $Tag) {
        $changelog = Get-Content (Join-Path $RepoRoot 'CHANGELOG.md') -Raw -Encoding UTF8
        if ($changelog -match '(?m)^## v(\d+\.\d+\.\d+)') {
            $Tag = 'v' + $Matches[1]
            Write-Host "从 CHANGELOG.md 读取到最新版本：$Tag"
        }
        else {
            throw '未在 CHANGELOG.md 中找到 "## vX.Y.Z" 格式的版本号，请用 -Tag 显式指定。'
        }
    }

    # 2. 校验基础版本格式（beta 模式同样只接受 vX.Y.Z）
    if ($Tag -notmatch '^v\d+\.\d+\.\d+$') {
        if ($Beta) {
            throw "基础版本格式不正确：$Tag（beta 模式请给 vX.Y.Z，例如 v1.5.0，序号会自动递增）"
        }
        else {
            throw "tag 格式不正确：$Tag（应为 vX.Y.Z，例如 v1.5.0）"
        }
    }

    # 3. beta 模式：扫描本地 + 远程已有 beta tag，序号取最大值 +1
    if ($Beta) {
        $pattern = "$Tag-beta."
        $nums = @()
        git tag --list "$pattern*" | ForEach-Object {
            if ($_ -match "$pattern(\d+)$") { $nums += [int]$Matches[1] }
        }
        if ($LASTEXITCODE -ne 0) { throw 'git tag --list 执行失败' }

        git ls-remote --tags origin "$pattern*" | ForEach-Object {
            if ($_ -match "$pattern(\d+)$") { $nums += [int]$Matches[1] }
        }
        if ($LASTEXITCODE -ne 0) { throw 'git ls-remote 执行失败' }

        $next = if ($nums.Count -eq 0) { 1 } else { ($nums | Measure-Object -Maximum).Maximum + 1 }
        $Tag = "$Tag-beta.$next"
        Write-Host "beta 序号：已存在 $($nums -join ', ')，下一个为 $next"
    }

    # 4. 检查本地和远程是否已存在该 tag
    git tag --list $Tag | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git tag --list 执行失败' }
    if (git tag --list $Tag) {
        throw "本地已存在 tag：$Tag"
    }

    git ls-remote --tags origin $Tag | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git ls-remote 执行失败' }
    if (git ls-remote --tags origin $Tag) {
        throw "远程已存在 tag：$Tag"
    }

    # 5. 打印将要执行的操作，要求输入 y 确认
    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0) { $currentBranch = '未知' }
    Write-Host ''
    Write-Host '将要执行的操作：'
    Write-Host "  tag  ：$Tag"
    if ($Beta) { Write-Host '  类型 ：beta 预发布（触发 beta 镜像构建 + Prerelease）' }
    Write-Host "  分支 ：$currentBranch"
    if ($NoPush) {
        Write-Host '  动作 ：仅创建本地 tag（不推送）'
    }
    else {
        Write-Host '  动作 ：创建 tag 并推送到 origin'
    }
    $answer = Read-Host '确认执行？输入 y 继续，其他任意键取消'
    if ($answer -ne 'y' -and $answer -ne 'Y') {
        Write-Host '已取消，未做任何改动。'
        return
    }

    # 6. 创建带注释的 tag
    git tag -a $Tag -m "Release $Tag"
    if ($LASTEXITCODE -ne 0) { throw "创建 tag $Tag 失败" }
    Write-Host "已创建 tag：$Tag"

    # 7. 推送 tag 触发 Release 工作流
    if ($NoPush) {
        Write-Host "未推送（-NoPush）。如需触发 Release，请执行：git push origin $Tag"
    }
    else {
        git push origin $Tag
        if ($LASTEXITCODE -ne 0) { throw "推送 tag $Tag 失败" }
        Write-Host "已推送 tag $Tag，GitHub Actions 的 Version 工作流将自动创建 Release。"
        if ($Beta) {
            Write-Host '同时 build.yml 将自动构建 beta 镜像（blazesnow/caddy-beta）。'
        }
    }
}
finally {
    Pop-Location
}
