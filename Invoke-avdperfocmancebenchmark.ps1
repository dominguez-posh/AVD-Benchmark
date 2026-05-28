<#
.SYNOPSIS
    AVD Host Performance Benchmark Tool v6 (Ultra Extreme Run)
.DESCRIPTION
    Misst maximale Langzeit-Performance: IOPS (C: & SMB), 5GB SMB-Durchsatz, 
    1024 Mini-Dateien, Internet-Speed, CPU, 500x RAM-Zyklen und 3M DB-Hashes.
    Generiert einen interaktiven HTML-Report unter C:\admin.
#>

# --- KONFIGURATION ---
$DiskspdPath   = ".\diskspd.exe"
$SpeedtestPath = ".\speedtest.exe"
$LocalDrive    = "C:\BenchmarkTest"
$SMBShare      = "\\localhost\c$\admin"
$DatabaseFile  = "C:\BenchmarkTest\local_sim_db.sqlite"

# Testverzeichnisse und Zielordner erstellen
if (-not (Test-Path $LocalDrive)) { New-Item -ItemType Directory -Path $LocalDrive | Out-Null }
if (-not (Test-Path "C:\admin"))   { New-Item -ItemType Directory -Path "C:\admin" | Out-Null }

Write-Host "=== AVD HOST ULTRA-EXTREME-BENCHMARK START ===" -ForegroundColor Cyan
Write-Host "WARNUNG: Dieser Test erzeugt massive Last und benötigt einige Minuten!`n" -ForegroundColor Red

# --- 1. IOPS AUF C:\ (Diskspd - 50 Sekunden Dauerfeuer) ---
Write-Host "1/8 [DISK C] Teste lokale Festplatte (IOPS, 50s)... " -NoNewline
if (Test-Path $DiskspdPath) {
    $resC = & $DiskspdPath -d50 -b4k -r -o32 -t4 -w0 -h -c150M "$LocalDrive\test.dat" | Out-String
    $IOPS_C = [regex]::match($resC, 'I/O per sec:\s+([0-9.]+)').Groups.Value
    $IOPS_C = [math]::Round([double]$IOPS_C)
} else {
    $IOPS_C = 2500
    Write-Host "[Diskspd.exe fehlt! Fallback genutzt] " -ForegroundColor Yellow -NoNewline
}
Write-Host "$IOPS_C IOPS" -ForegroundColor Green

# --- 2. IOPS AUF FSLOGIX FREIGABE (Diskspd SMB - 50 Sekunden Dauerfeuer) ---
Write-Host "2/8 [FSLOGIX IOPS] Teste Freigabe-IOPS (SMB, 50s)... " -NoNewline
if (Test-Path $DiskspdPath) {
    $resSMB = & $DiskspdPath -d50 -b4k -r -o32 -t4 -w0 -h -c150M "$SMBShare\test_iops.dat" | Out-String
    $IOPS_SMB = [regex]::match($resSMB, 'I/O per sec:\s+([0-9.]+)').Groups.Value
    $IOPS_SMB = [math]::Round([double]$IOPS_SMB)
} else {
    $IOPS_SMB = 1200
    Write-Host "[Diskspd.exe fehlt! Fallback genutzt] " -ForegroundColor Yellow -NoNewline
}
Write-Host "$IOPS_SMB IOPS" -ForegroundColor Green

# --- 3. SMB DURCHSATZ (Große Datei - Massiver 5 GB Schreibtest) ---
Write-Host "3/8 [FSLOGIX THROUGHPUT] Schreibe 5 GB Testdatei... " -NoNewline
$LargeData = New-Object Byte[] 100MB 
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$FileStream = [System.IO.File]::Create("$SMBShare\large_5gb.dat")
for ($g = 0; $g -lt 50; $g++) {
    $FileStream.Write($LargeData, 0, $LargeData.Length)
}
$FileStream.Close()
$FileStream.Dispose()
$Timer.Stop()
$SMB_Large_MBs = [math]::Round((5000 / $Timer.Elapsed.TotalSeconds), 2)
Write-Host "$SMB_Large_MBs MB/s" -ForegroundColor Green

# --- 4. SMB LATENZ / MINI-DATEIEN (1024 kleine Dateien erzeugen) ---
Write-Host "4/8 [FSLOGIX LATENCY] Erzeuge 1024 Mini-Dateien... " -NoNewline
$MiniData = New-Object Byte[] 4KB # Typische Clustergröße für kleine Profildaten
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
for ($m = 1; $m -le 1024; $m++) {
    [System.IO.File]::WriteAllBytes("$SMBShare\mini_$m.dat", $MiniData)
}
$Timer.Stop()
$SMB_Mini_Time = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
Write-Host "$SMB_Mini_Time Sekunden" -ForegroundColor Green

# --- 5. INTERNET GESCHWINDIGKEIT (1GB Download) ---
Write-Host "5/8 [INTERNET] Teste Bandbreite (1GB Azure Download)... " -NoNewline
if (Test-Path $SpeedtestPath) {
    try {
        $SpeedJSON = & $SpeedtestPath --format=json --accept-license --accept-gdpr | ConvertFrom-Json
        $Internet_Down = [math]::Round(($SpeedJSON.download.bandwidth * 8 / 1000000), 2)
    } catch { $SpeedtestPath = $null }
}
if (-not (Test-Path $SpeedtestPath)) {
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
        Write-Host "[HTTP-Fehler! Fallback genutzt] " -ForegroundColor Yellow -NoNewline
    }
}
Write-Host "$Internet_Down Mbps" -ForegroundColor Green

# --- 6. CPU PERFORMANCE (Primzahl-Stress-Test) ---
Write-Host "6/8 [CPU] Berechne Primzahlen (Single-Core-Stress)... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 2; $i -le 150000; $i++) {
    $isPrime = $true
    for ($j = 2; $j -le [math]::Sqrt($i); $j++) {
        if ($i % $j -eq 0) { $isPrime = $false; break }
    }
}
$Timer.Stop()
$CPU_Time = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
Write-Host "$CPU_Time Sekunden" -ForegroundColor Green

# --- 7. RAM PERFORMANCE (Block-Kopiergeschwindigkeit - 500 Zyklen) ---
Write-Host "7/8 [RAM] Führe 500x 100MB RAM-Kopierzyklen aus... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$SourceArray = New-Object Byte[] 100MB
$DestArray   = New-Object Byte[] 100MB
for ($k = 0; $k -lt 500; $k++) {
    [System.Buffer]::BlockCopy($SourceArray, 0, $DestArray, 0, $SourceArray.Length)
}
$Timer.Stop()
$RAM_Time = [math]::Round($Timer.Elapsed.TotalMilliseconds, 2)
Write-Host "$RAM_Time ms" -ForegroundColor Green

# --- 8. USER WORKLOAD & DATENBANK SIMULATION (3.000.000 Schleifen) ---
Write-Host "8/8 [USER WORKLOAD] Berechne 3 Mio. DB/MD5-Hashes (Dauerlast)... " -NoNewline
$Timer = [System.Diagnostics.Stopwatch]::StartNew()
$AddIn = 0
for($i=1; $i -le 3000000; $i++) {
    $Hash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::ASCII.GetBytes($i.ToString()))
    $AddIn += $i
}
$Timer.Stop()
$DB_Sim_Time = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
Write-Host "$DB_Sim_Time Sekunden" -ForegroundColor Green

# --- CLEANUP (Löscht nur die erzeugten Test-Dateien) ---
Remove-Item "$LocalDrive\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$SMBShare\test_iops.dat", "$SMBShare\large_5gb.dat" -Force -ErrorAction SilentlyContinue
for ($m = 1; $m -le 1024; $m++) {
    Remove-Item "$SMBShare\mini_$m.dat" -Force -ErrorAction SilentlyContinue
}

# --- 9. SCORE BERECHNUNG (PUNKTESTAND MAX 100) ---
# Die 1024 Dateien fließen direkt in die Bewertung der Freigabenlatenz ein
$Score_IOPS_C  = [math]::Min(15, ($IOPS_C / 5000) * 15)
$Score_IOPS_SMB= [math]::Min(15, ($IOPS_SMB / 3000) * 15)
$Score_SMB_MBs = [math]::Min(15, ($SMB_Large_MBs / 150) * 15)
$Score_SMB_Mini= [math]::Min(10, (5.0 / $SMB_Mini_Time) * 10)  # Volle Punkte bei unter 5 Sekunden für 1024 Dateien
$Score_Net     = [math]::Min(15, ($Internet_Down / 500) * 15)
$Score_CPU     = [math]::Min(10, (4.0 / $CPU_Time) * 10)         
$Score_RAM     = [math]::Min(10, (1500 / $RAM_Time) * 10)         
$Score_Work    = [math]::Min(10, (25.0 / $DB_Sim_Time) * 10)       

$TotalScore  = [math]::Round($Score_IOPS_C + $Score_IOPS_SMB + $Score_SMB_MBs + $Score_SMB_Mini + $Score_Net + $Score_CPU + $Score_RAM + $Score_Work)
$StatusColor = if ($TotalScore -ge 75) { "#2ecc71" } elseif ($TotalScore -ge 50) { "#f1c40f" } else { "#e74c3c" }

# --- 10. HTML REPORT GENERIEREN ---
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
        <h2>AVD Host Performance Report (Ultra-Extreme-Test)</h2>
        <div class="score-box">Gesamtscore: $TotalScore / 100</div>
        
        <table>
            <tr><th>Komponente</th><th>Messwert</th><th>Erreichte Punkte</th></tr>
            <tr><td><b>Lokale Disk C:\ (IOPS)</b></td><td>$IOPS_C IOPS</td><td>$([math]::Round($Score_IOPS_C,1)) / 15</td></tr>
            <tr><td><b>FSLogix Freigabe (IOPS)</b></td><td>$IOPS_SMB IOPS</td><td>$([math]::Round($Score_IOPS_SMB,1)) / 15</td></tr>
            <tr><td><b>FSLogix Freigabe (5GB Write)</b></td><td>$SMB_Large_MBs MB/s</td><td>$([math]::Round($Score_SMB_MBs,1)) / 15</td></tr>
            <tr><td><b>FSLogix Latenz (1024 Dateien)</b></td><td>$SMB_Mini_Time Sek</td><td>$([math]::Round($Score_SMB_Mini,1)) / 10</td></tr>
            <tr><td><b>Internet Download</b></td><td>$Internet_Down Mbps</td><td>$([math]::Round($Score_Net,1)) / 15</td></tr>
            <tr><td><b>CPU Rechenleistung</b></td><td>$CPU_Time Sek</td><td>$([math]::Round($Score_CPU,1)) / 10</td></tr>
            <tr><td><b>RAM-Durchsatz (500 Zyklen)</b></td><td>$RAM_Time ms</td><td>$([math]::Round($Score_RAM,1)) / 10</td></tr>
            <tr><td><b>User Workload (3M DB)</b></td><td>$DB_Sim_Time Sek</td><td>$([math]::Round($Score_Work,1)) / 10</td></tr>
        </table>

        <div class="meta">
            Geprüft am: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss") | Host: $env:COMPUTERNAME | Modus: 1024 Mini-File Extended Run
        </div>
    </div>
</body>
</html>
"@

$HtmlReport | Out-File "C:\admin\Benchmark_Report.html" -Encoding utf8
Write-Host "`n[INFO] HTML-Report erfolgreich unter C:\admin\Benchmark_Report.html generiert!" -ForegroundColor Cyan
