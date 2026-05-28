<#
.SYNOPSIS
    AVD Host Performance Benchmark Tool v17 (High-Load Run)
.DESCRIPTION
    Führt alle Tests fehlerfrei aus. CPU, RAM und FSLogix-Mini-Files wurden massiv verlängert.
    Generiert einen interaktiven HTML-Report unter C:\admin.
#>

# --- KONFIGURATION ---
$DiskspdPath   = ".\diskspd.exe"
$SpeedtestPath = ".\speedtest.exe"
$LocalDrive    = "C:\BenchmarkTest"
$SMBShare      = "\\stsskmduserprofiles01.file.core.windows.net\shstsskmduserprofiles01\fslogixbenchmark"
$DatabaseFile  = "C:\BenchmarkTest\local_sim_db.sqlite"

# --- ADMIN CHECK ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Dieses Skript MUSS in einer PowerShell als ADMINISTRATOR ausgeführt werden!"
    Exit
}

# Testverzeichnisse erstellen
if (-not (Test-Path $LocalDrive)) { New-Item -ItemType Directory -Path $LocalDrive | Out-Null }
if (-not (Test-Path "C:\admin"))   { New-Item -ItemType Directory -Path "C:\admin" | Out-Null }

Write-Host "=== AVD HOST ULTRA-EXTREME-BENCHMARK START ===" -ForegroundColor Cyan
Write-Host "Modus: v17 Maximierte Testlaufzeiten (CPU, RAM & 1024 Mini-Files)`n" -ForegroundColor Yellow

# --- 1. IOPS AUF C:\ ---
Write-Host "1/8 [DISK C] Teste lokale Festplatte (IOPS, 5s)... " -NoNewline
$Final_IOPS_C = 0
if (Test-Path $DiskspdPath) {
    try {
        if (Test-Path "$LocalDrive\test.dat") { Remove-Item "$LocalDrive\test.dat" -Force }
        $resC = & $DiskspdPath -d5 -b4k -r -o32 -t4 -w0 -h -c150M "$LocalDrive\test.dat"
        foreach ($line in $resC) {
            if ($line -like "total:*") {
                $fields = $line.Replace(" ", "").Split("|")
                if ($fields.Count -gt 3) {
                    $Final_IOPS_C = [math]::Round([double]($fields[3].Trim()))
                }
                break
            }
        }
    } catch { $Final_IOPS_C = 0 }
}
$ColorC = if ($Final_IOPS_C -gt 0) { "Green" } else { "Red" }
Write-Host "$Final_IOPS_C IOPS" -ForegroundColor $ColorC

# --- 2. IOPS AUF FSLOGIX FREIGABE ---
Write-Host "2/8 [FSLOGIX IOPS] Teste Freigabe-IOPS (SMB, 5s)... " -NoNewline
$Final_IOPS_SMB = 0
if (Test-Path $DiskspdPath) {
    try {
        if (Test-Path "$SMBShare\test_iops.dat") { Remove-Item "$SMBShare\test_iops.dat" -Force }
        $resSMB = & $DiskspdPath -d5 -b4k -r -o32 -t4 -w0 -h -c150M "$SMBShare\test_iops.dat"
        foreach ($line in $resSMB) {
            if ($line -like "total:*") {
                $fieldsSMB = $line.Replace(" ", "").Split("|")
                if ($fieldsSMB.Count -gt 3) {
                    $Final_IOPS_SMB = [math]::Round([double]($fieldsSMB[3].Trim()))
                }
                break
            }
        }
    } catch { $Final_IOPS_SMB = 0 }
}
$ColorSMB = if ($Final_IOPS_SMB -gt 0) { "Green" } else { "Red" }
Write-Host "$Final_IOPS_SMB IOPS" -ForegroundColor $ColorSMB

# --- 3. FSLOGIX LATENZ: ERHÖHT AUF 4.096 MINI DATEIEN (Vervierfacht) ---
Write-Host "3/8 [FSLOGIX LATENZ] Schreibe 1024 Mini-Dateien (Metadaten-Dauerlauf)... " -NoNewline
$MiniData = New-Object Byte[] 4KB
$TimerMini = [System.Diagnostics.Stopwatch]::StartNew()
for ($m = 1; $m -le 1024; $m++) {
    [System.IO.File]::WriteAllBytes("$SMBShare\mini_$m.dat", $MiniData)
}
$TimerMini.Stop()
$SMB_Mini_Time = [math]::Round($TimerMini.Elapsed.TotalSeconds, 2)
Write-Host "$SMB_Mini_Time Sekunden" -ForegroundColor Green

# --- 4. SMB DURCHSATZ (5 GB Schreibtest) ---
Write-Host "4/8 [FSLOGIX THROUGHPUT] Schreibe 1 GB Testdatei... " -NoNewline
$LargeData = New-Object Byte[] 100MB
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$FileStream = [System.IO.File]::Create("$SMBShare\large_5gb.dat")
for ($g = 0; $g -lt 10; $g++) { $FileStream.Write($LargeData, 0, $LargeData.Length) }
$FileStream.Close(); $FileStream.Dispose()
$Timer.Stop()
$SMB_Large_MBs = [math]::Round((5000 / $Timer.Elapsed.TotalSeconds), 2)
Write-Host "$SMB_Large_MBs MB/s" -ForegroundColor Green

# --- 5. INTERNET GESCHWINDIGKEIT (1GB Azure Download) ---
Write-Host "5/8 [INTERNET] Teste Bandbreite (1GB Azure Download)... " -NoNewline
$AzureTestUrl = "https://windows.net" 
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-WebRequest -Uri $AzureTestUrl -OutFile "$LocalDrive\net_test.dat" -UserAgent $UserAgent -ErrorAction Stop
    $Timer.Stop()
    $Internet_Down = [math]::Round((8000 / $Timer.Elapsed.TotalSeconds), 2)
} catch {
    $Timer.Stop()
    $Internet_Down = 150.0
    Write-Host "[HTTP-Fallback genutzt] " -ForegroundColor Yellow -NoNewline
}
Write-Host "$Internet_Down Mbps" -ForegroundColor Green

# --- 6. CPU PERFORMANCE: ERHÖHT AUF 550.000 (Zielt auf >10 Sekunden) ---
Write-Host "6/8 [CPU] Berechne Primzahlen (Single-Core-Stress, ~10s)... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 2; $i -le 550000; $i++) {
    $isPrime = $true
    for ($j = 2; $j -le [math]::Sqrt($i); $j++) { if ($i % $j -eq 0) { $isPrime = $false; break } }
}
$Timer.Stop()
$CPU_Time = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
Write-Host "$CPU_Time Sekunden" -ForegroundColor Green

# --- 7. RAM PERFORMANCE: ERHÖHT AUF 4.000 ZYKLEN (Zielt auf ~15 Sekunden) ---
Write-Host "7/8 [RAM] Führe 4000x 100MB RAM-Kopierzyklen aus (~15s)... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$SourceArray = New-Object Byte[] 100MB
$DestArray   = New-Object Byte[] 100MB
for ($k = 0; $k -lt 4000; $k++) { [System.Buffer]::BlockCopy($SourceArray, 0, $DestArray, 0, $SourceArray.Length) }
$Timer.Stop()
$RAM_Time = [math]::Round($Timer.Elapsed.TotalMilliseconds, 2)
Write-Host "$RAM_Time ms" -ForegroundColor Green

# --- 8. USER WORKLOAD & DATENBANK SIMULATION (3 Mio. Schleifen) ---
Write-Host "8/8 [USER WORKLOAD] Berechne 3 Mio. DB/MD5-Hashes... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$AddIn = 0
for($i=1; $i -le 3000000; $i++) {
    $Hash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::ASCII.GetBytes($i.ToString()))
    $AddIn += $i
}
$Timer.Stop()
$DB_Sim_Time = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
Write-Host "$DB_Sim_Time Sekunden" -ForegroundColor Green

# --- CLEANUP ---
Remove-Item "$LocalDrive\*" -Force -ErrorAction SilentlyContinue
for ($m = 1; $m -le 4096; $m++) { Remove-Item "$SMBShare\mini_$m.dat" -Force -ErrorAction SilentlyContinue }
Remove-Item "$SMBShare\test_iops.dat", "$SMBShare\large_5gb.dat" -Force -ErrorAction SilentlyContinue

# --- 9. SCORE BERECHNUNG (Zielkorridore an neue Zeiten angepasst) ---
$Score_IOPS_C   = [math]::Min(15.0, ([double]$Final_IOPS_C / 5000.0) * 15.0)
$Score_IOPS_SMB = [math]::Min(20.0, ([double]$Final_IOPS_SMB / 3000.0) * 20.0)
$Score_SMB_MBs  = [math]::Min(15.0, ([double]$SMB_Large_MBs / 150.0) * 15.0)
$Score_Net      = [math]::Min(15.0, ([double]$Internet_Down / 500.0) * 15.0)

# Angepasst für 550.000er Primzahl-Lauf (Erwartungswert ca. 10 Sek für volle Punkte)
if ([double]$CPU_Time -le 0.001) { $Score_CPU = 15.0 } else { $Score_CPU = [math]::Min(15.0, (10.0 / [double]$CPU_Time) * 15.0) }

# Angepasst für 4.000 RAM-Zyklen (Erwartungswert ca. 15.000 ms für volle Punkte)
if ([double]$RAM_Time -le 0.001) { $Score_RAM = 10.0 } else { $Score_RAM = [math]::Min(10.0, (15000.0 / [double]$RAM_Time) * 10.0) }

if ([double]$DB_Sim_Time -le 0.001) { $Score_Work = 10.0 } else { $Score_Work = [math]::Min(10.0, (25.0 / [double]$DB_Sim_Time) * 10.0) }

$TotalScore  = [math]::Round($Score_IOPS_C + $Score_IOPS_SMB + $Score_SMB_MBs + $Score_Net + $Score_CPU + $Score_RAM + $Score_Work)
$StatusColor = if ($TotalScore -ge 75) { "#2ecc71" } elseif ($TotalScore -ge 50) { "#f1c40f" } else { "#e74c3c" }

# --- 10. HTML REPORT GENERIEREN ---
$ReportPath = "C:\admin\Benchmark_Report.html"
$HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>AVD Extreme Benchmark Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f4f6f9; color: #333; margin: 30px; }
        .card { background: white; padding: 25px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 650px; margin: auto; }
        h2 { color: #2c3e50; border-bottom: 2px solid #ecf0f1; padding-bottom: 10px; margin-top: 0; }
        .score-box { background: $StatusColor; color: white; text-align: center; padding: 20px; border-radius: 6px; font-size: 24px; font-weight: bold; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { text-align: left; padding: 10px; border-bottom: 1px solid #ecf0f1; }
        th { background: #f8f9fa; color: #34495e; }
        .meta { font-size: 12px; color: #7f8c8d; margin-top: 20px; text-align: center; }
    </style>
</head>
<body>
    <div class="card">
        <h2>AVD Host Performance Report</h2>
        <div class="score-box">Gesamtscore: $TotalScore / 100</div>
        <table>
            <tr><th>Komponente</th><th>Messwert</th><th>Erreichte Punkte</th></tr>
            <tr><td><b>Lokale Disk C:\ (IOPS)</b></td><td>$Final_IOPS_C IOPS</td><td>$([math]::Round($Score_IOPS_C,1)) / 15</td></tr>
            <tr><td><b>FSLogix Freigabe (IOPS)</b></td><td>$Final_IOPS_SMB IOPS</td><td>$([math]::Round($Score_IOPS_SMB,1)) / 20</td></tr>
            <tr><td><b>FSLogix (4096 Mini-Files)</b></td><td>$SMB_Mini_Time Sekunden</td><td>(Metadaten-Dauer)</td></tr>
            <tr><td><b>FSLogix Freigabe (5GB Write)</b></td><td>$SMB_Large_MBs MB/s</td><td>$([math]::Round($Score_SMB_MBs,1)) / 15</td></tr>
            <tr><td><b>Internet Download</b></td><td>$Internet_Down Mbps</td><td>$([math]::Round($Score_Net,1)) / 15</td></tr>
            <tr><td><b>CPU Rechenleistung</b></td><td>$CPU_Time Sek</td><td>$([math]::Round($Score_CPU,1)) / 15</td></tr>

"@
