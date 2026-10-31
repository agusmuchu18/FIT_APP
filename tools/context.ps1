param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('app','core','ui','home','analytics','auth','groups','habits','modules','nutrition','onboarding','profile','settings','sleep','streak','workout','test')]
    [string]$Area,
    [string]$Query,
    [ValidateRange(1, 80)]
    [int]$Limit = 30
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$relative = switch ($Area) {
    'app' { 'lib/app' }
    'core' { 'lib/core' }
    'ui' { 'lib/ui' }
    'test' { 'test' }
    default { "lib/features/$Area" }
}
$target = Join-Path $repo $relative
if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    throw "Área inexistente: $relative"
}

Push-Location -LiteralPath $repo
try {
    if ([string]::IsNullOrWhiteSpace($Query)) {
        rg --files -g '*.dart' -- $relative | Select-Object -First $Limit
    } else {
        rg -n -F --max-columns 180 --max-columns-preview -g '*.dart' -- $Query $relative |
            Select-Object -First $Limit
    }
} finally {
    Pop-Location
}
