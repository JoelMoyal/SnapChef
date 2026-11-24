# Uses the verified portable SDK without changing global PATH or Git settings.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sdkRoot = Join-Path $projectRoot 'tmp/flutter-tools/flutter'
$executable = Join-Path $sdkRoot 'bin/flutter.bat'
if (-not (Test-Path -LiteralPath $executable)) {
  throw 'Portable Flutter SDK is missing. Install Flutter 3.47.8 or extract its official archive into tmp/flutter-tools.'
}
$existingCount = [int][Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
$changes = @{
  PUB_CACHE = (Join-Path $projectRoot 'tmp/pub-cache')
  FLUTTER_SUPPRESS_ANALYTICS = 'true'
  GIT_CONFIG_COUNT = [string]($existingCount + 1)
}
$changes["GIT_CONFIG_KEY_$existingCount"] = 'safe.directory'
$changes["GIT_CONFIG_VALUE_$existingCount"] = $sdkRoot.Replace('\', '/')
$original = @{}
foreach ($name in $changes.Keys) {
  $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
  [Environment]::SetEnvironmentVariable($name, $changes[$name], 'Process')
}
$result = 1
Push-Location $projectRoot
try {
  & $executable @args
  $result = $LASTEXITCODE
} finally {
  Pop-Location
  foreach ($name in $original.Keys) {
    [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process')
  }
}
exit $result
