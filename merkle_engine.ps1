<#
.SYNOPSIS
Deterministic Recursive Merkle Tree Engine & Cryptographic Attestation Seal.
.DESCRIPTION
Scans all workspace artifacts recursively, builds a pairwise SHA-256 Merkle Tree,
and outputs the immutable sovereign Merkle Root Seal into BUILD_SEALED_MANIFEST.json.
#>
class RecursiveMerkleEngine {
static [string] ComputeSHA256([byte[]]$bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToUpper()
    } finally {
        $sha.Dispose()
    }
}

static [string] ComputeStringSHA256([string]$inputStr) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputStr)
    return [RecursiveMerkleEngine]::ComputeSHA256($bytes)
}

static [string] ComputeFileSHA256([string]$filePath) {
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    return [RecursiveMerkleEngine]::ComputeSHA256($bytes)
}

static [hashtable] BuildMerkleTree([string]$rootPath) {
    # Fetch all files recursively excluding .git directory and manifest output
    $files = Get-ChildItem -Path $rootPath -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne 'BUILD_SEALED_MANIFEST.json' } |
        Sort-Object FullName

    if ($files.Count -eq 0) {
        throw "No valid files found to build Merkle Tree."
    }

    # Step 1: Compute Leaf Hashes
    $leafNodes = [System.Collections.Generic.List[string]]::new()
    $manifestLeaves = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($file in $files) {
        $relPath = $file.FullName.Replace($rootPath, "").TrimStart('\', '/')
        $hash = [RecursiveMerkleEngine]::ComputeFileSHA256($file.FullName)
        $leafNodes.Add($hash)
        $manifestLeaves.Add(@{
            "RelativePath" = $relPath
            "SHA256"       = $hash
            "SizeBytes"    = $file.Length
        })
    }

    # Step 2: Pairwise Recursive Reduction to Merkle Root
    $currentLevel = $leafNodes
    $treeDepth = 0

    while ($currentLevel.Count -gt 1) {
        $nextLevel = [System.Collections.Generic.List[string]]::new()
        $treeDepth++

        for ($i = 0; $i -lt $currentLevel.Count; $i += 2) {
            $left = $currentLevel[$i]
            $right = if (($i + 1) -lt $currentLevel.Count) { $currentLevel[$i + 1] } else { $left }
            $combined = [RecursiveMerkleEngine]::ComputeStringSHA256($left + $right)
            $nextLevel.Add($combined)
        }
        $currentLevel = $nextLevel
    }

    $merkleRoot = $currentLevel[0]

    return @{
        "MerkleRootHash" = $merkleRoot
        "TotalFiles"     = $files.Count
        "TreeDepth"      = $treeDepth
        "Leaves"         = $manifestLeaves
        "TimestampUtc"   = ([datetime]::UtcNow).ToString("o")
    }
}
}

# Run Engine & Output Manifest
try {
Write-Host "=== INITIALIZING RECURSIVE SHA-256 MERKLE TREE ENGINE ===" -ForegroundColor Cyan
$result = [RecursiveMerkleEngine]::BuildMerkleTree((Get-Location).Path)

$manifest = @{
    "Engine"         = "God's Eye View - Sovereign Merkle Proof Core v1.0"
    "MerkleRoot"     = $result["MerkleRootHash"]
    "TotalArtifacts" = $result["TotalFiles"]
    "TreeDepth"      = $result["TreeDepth"]
    "Timestamp"      = $result["TimestampUtc"]
    "ArtifactLeaves" = $result["Leaves"]
}

$jsonOutput = $manifest | ConvertTo-Json -Depth 5
Set-Content -Path "BUILD_SEALED_MANIFEST.json" -Value $jsonOutput -Encoding UTF8

Write-Host ("`n[✔] RECURSIVE MERKLE ROOT SEAL: {0}" -f $result["MerkleRootHash"]) -ForegroundColor Green
Write-Host ("[*] Total Artifacts Processed: {0} | Tree Depth: {1}" -f $result["TotalFiles"], $result["TreeDepth"]) -ForegroundColor Yellow
Write-Host ("[*] Attestation manifest sealed to .\BUILD_SEALED_MANIFEST.json") -ForegroundColor Cyan
} catch {
Write-Error "Merkle Tree calculation failed: $_"
}
