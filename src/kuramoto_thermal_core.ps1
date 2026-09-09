$ErrorActionPreference = "Stop"
$N = 4; $K0 = 1.5; $dt = 0.01
$omega = @(40.0, 40.5, 39.5, 40.2)
$theta = @(0.0, 0.8, 1.9, 3.4)
$temp = 32.5
$tScalar = [Math]::Max(1.0, $temp / 20.0)
$K = $K0 * $tScalar
Write-Host ("=== SOFTWARE THERMAL KURAMOTO ENGINE RUNNING // T = {0}°C (K = {1:F2}) ===" -f $temp, $K) -ForegroundColor Red
$newTheta = New-Object double[] $N; $cosSum = 0.0; $sinSum = 0.0
for ($i = 0; $i -lt $N; $i++) {
    $interaction = 0.0
    for ($j = 0; $j -lt $N; $j++) { $interaction += [Math]::Sin($theta[$j] - $theta[$i]) }
    $dTheta = $omega[$i] + ($K / $N) * $interaction
    $newTheta[$i] = ($theta[$i] + $dTheta * $dt) % (2 * [Math]::PI)
    $cosSum += [Math]::Cos($newTheta[$i]); $sinSum += [Math]::Sin($newTheta[$i])
}
$R = [Math]::Sqrt(($cosSum * $cosSum) + ($sinSum * $sinSum)) / $N
Write-Host ("[SOFTWARE LOCK] Order Parameter R: {0:F4}" -f $R) -ForegroundColor Green
