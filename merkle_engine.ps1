$ErrorActionPreference = "Stop"

function Get-SHA256String([string]$inputString) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputString)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    $hash  = $sha.ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString("x2") })
}

function Get-SHA256File([string]$filePath) {
    if (-not (Test-Path $filePath)) { return $null }
    $sha    = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($filePath)
    try {
        $hash = $sha.ComputeHash($stream)
        return -join ($hash | ForEach-Object { $_.ToString("x2") })
    } finally {
        $stream.Close()
    }
}

function Get-MerkleRoot([string[]]$leafHashes) {
    if ($leafHashes.Count -eq 0) { return Get-SHA256String "NULL_LEAF" }
    $level = $leafHashes
    while ($level.Count -gt 1) {
        $nextLevel = @()
        for ($i = 0; $i -lt $level.Count; $i += 2) {
            if ($i + 1 -lt $level.Count) {
                $combined = $level[$i] + $level[$i+1]
            } else {
                $combined = $level[$i] + $level[$i]
            }
            $nextLevel += Get-SHA256String $combined
        }
        $level = $nextLevel
    }
    return $level[0]
}

$leafHashes = @()
$files = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch "\\\.git\\" }
foreach ($file in $files) {
    $fHash = Get-SHA256File $file.FullName
    if ($fHash) { $leafHashes += $fHash }
}

$merkleRoot  = Get-MerkleRoot $leafHashes
$shortMerkle = $merkleRoot.Substring(0, 12)

Write-Host "================================================================================" -ForegroundColor DarkCyan
Write-Host "  ROBDOE ORACLE MERKLE ROOT : $merkleRoot" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor DarkCyan

$readmeLines = @(
    "",
    "## Robdoe Oracle & Merkle Core State",
    "- **Merkle Tree Root Hash:** ``$merkleRoot``",
    "- **Short Tag Identifier:** ``merkle-$shortMerkle``",
    "- **Oracle Core:** `src/robdoe_oracle.ps1` (Deterministic Phase/Thermal State Predictor)",
    "- **Sync Core:** Pure Software Thermal Kuramoto Engine"
)
Add-Content -Path "README.md" -Value ($readmeLines -join [Environment]::NewLine) -Encoding UTF8

git add -A
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git commit -m "feat(oracle): integrate Robdoe Oracle predictor & update merkle root [$shortMerkle] at $timestamp" --quiet

$tagName = "v2026.09.01-merkle-$shortMerkle"
git tag -f -a $tagName -m "Merkle Tree Root Hash: $merkleRoot"

$commits = git rev-list --reverse HEAD
$idx = 1
foreach ($c in $commits) {
    $seqTag = "v2026.09.01-rev{0:D2}" -f $idx
    git tag -f -a $seqTag $c -m "Sequential tag $seqTag for $c"
    $idx++
}

Write-Host "[+] Pushing repository, oracle module, commits, and tags to origin..." -ForegroundColor Yellow
git push origin HEAD --force
git push origin --tags --force
Write-Host "[✓] Robdoe Oracle integrated, tagged, and pushed to origin." -ForegroundColor Green
