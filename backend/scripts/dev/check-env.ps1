# Verifies the native Qabas development environment. Exit code 0 only when every check passes.
$ErrorActionPreference = 'Continue'
$failed = 0
function Check([string]$name, [scriptblock]$test) {
    try {
        $detail = & $test
        if ($detail) { Write-Host ("[ OK ] {0,-12} {1}" -f $name, $detail) }
        else { throw 'no output' }
    } catch {
        Write-Host ("[FAIL] {0,-12} {1}" -f $name, $_) -ForegroundColor Red
        $script:failed++
    }
}

$backendDir = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$envFile = Join-Path $backendDir '.env'
$psql = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
$redisCli = Join-Path $env:LOCALAPPDATA 'Programs\Redis\redis-cli.exe'

Check 'python3.12' { $v = & py -3.12 -c "import sys;print(sys.version.split()[0])"; if ($v -notlike '3.12.*') { throw "got $v" }; $v }
Check 'uv'         { (& uv --version) }
Check 'ffmpeg'     { (& ffmpeg -hide_banner -version 2>$null | Select-Object -First 1) }
Check 'node'       { (& node --version) }
Check 'redis'      {
    if ((& $redisCli -h 127.0.0.1 ping 2>$null) -ne 'PONG') { throw 'not responding (run scripts/dev/start-redis.ps1)' }
    (& $redisCli -h 127.0.0.1 INFO server | Select-String 'redis_version').ToString().Trim()
}
Check 'pg service' { $s = Get-Service postgresql-x64-16; if ($s.Status -ne 'Running') { throw $s.Status }; 'postgresql-x64-16 running' }

if (Test-Path $envFile) {
    $vars = @{}
    Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Z_]+)=(.*)$' } | ForEach-Object { $vars[$Matches[1]] = $Matches[2] }
    foreach ($key in 'DATABASE_URL', 'TEST_DATABASE_URL') {
        Check $key {
            if ($vars[$key] -notmatch '^postgresql\+asyncpg://([^:]+):([^@]+)@([^:/]+):(\d+)/(.+)$') { throw 'malformed URL' }
            $user, $pass, $dbHost, $port, $db = $Matches[1..5]
            $env:PGPASSWORD = $pass
            try { $r = & $psql -h $dbHost -p $port -U $user -d $db -t -A -c "select current_database() || ' / ' || version()" 2>&1 }
            finally { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
            if ($LASTEXITCODE -ne 0) { throw $r }
            ($r -split ',')[0]
        }
    }
} else {
    Write-Host "[FAIL] database     $envFile missing (run scripts/dev/create-dev-db.ps1)" -ForegroundColor Red
    $failed++
}

if ($failed) { Write-Host "$failed check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All environment checks passed.'
