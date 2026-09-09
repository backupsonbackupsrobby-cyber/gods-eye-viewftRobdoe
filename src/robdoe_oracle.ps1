class RobdoeOracle {
    [double]$BaseFreq; [double]$CouplingK
    RobdoeOracle([double]$freq, [double]$k) { $this.BaseFreq = $freq; $this.CouplingK = $k }
    [hashtable] PredictState([double]$tempC, [double[]]$currentPhases) {
        $tScalar = [Math]::Max(1.0, $tempC / 20.0); $effK = $this.CouplingK * $tScalar
        $N = $currentPhases.Count; $cosSum = 0.0; $sinSum = 0.0; $nextPhases = New-Object double[] $N
        for ($i = 0; $i -lt $N; $i++) {
            $interaction = 0.0
            for ($j = 0; $j -lt $N; $j++) { $interaction += [Math]::Sin($currentPhases[$j] - $currentPhases[$i]) }
            $dTheta = $this.BaseFreq + ($effK / $N) * $interaction
            $nextPhases[$i] = ($currentPhases[$i] + $dTheta * 0.01) % (2 * [Math]::PI)
            $cosSum += [Math]::Cos($nextPhases[$i]); $sinSum += [Math]::Sin($nextPhases[$i])
        }
        $R = [Math]::Sqrt(($cosSum * $cosSum) + ($sinSum * $sinSum)) / $N
        return @{ "OrderParameter_R" = [Math]::Round($R, 6); "ThermalScalar" = [Math]::Round($tScalar, 4) }
    }
}
$oracle = [RobdoeOracle]::new(40.0, 1.5)
$res = $oracle.PredictState(32.5, @(0.0, 0.8, 1.9, 3.4))
Write-Host "ROBDOE ORACLE ACTIVE // R:" $res["OrderParameter_R"] -ForegroundColor Yellow
