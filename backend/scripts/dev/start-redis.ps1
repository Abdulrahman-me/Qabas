# Starts the native Redis 7.4 dev server (localhost only) if it is not already running.
# Install location and config: %LOCALAPPDATA%\Programs\Redis\redis.local.conf (see backend/README.md).
$ErrorActionPreference = 'Stop'
$redisDir = Join-Path $env:LOCALAPPDATA 'Programs\Redis'
$cli = Join-Path $redisDir 'redis-cli.exe'
$server = Join-Path $redisDir 'redis-server.exe'

if (-not (Test-Path $server)) { throw "Redis not found at $redisDir. See backend/README.md." }

$pong = & $cli -h 127.0.0.1 -p 6379 ping 2>$null
if ($pong -eq 'PONG') { Write-Host 'Redis is already running on 127.0.0.1:6379.'; exit 0 }

Start-Process -FilePath $server -ArgumentList 'redis.local.conf' -WorkingDirectory $redisDir -WindowStyle Hidden
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if ((& $cli -h 127.0.0.1 -p 6379 ping 2>$null) -eq 'PONG') { Write-Host 'Redis started on 127.0.0.1:6379.'; exit 0 }
}
throw "Redis did not respond; check $redisDir\redis.log"
