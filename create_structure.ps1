Write-Host "Creando estructura de carpetas para la app..." -ForegroundColor Cyan

# Helper para crear carpetas sin tirar error si ya existen
function New-Dir {
    param([string]$path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

# Lista de todas las carpetas a crear
$folders = @(
    # Raíz / assets / tests / scripts
    "assets\icons",
    "assets\images",
    "assets\fonts",
    "assets\lottie",
    "assets\mock_data",
    "tool",
    "scripts",
    ".github\workflows",
    "test\unit\core",
    "test\unit\features",
    "test\widget\features",
    "test\integration",
    "integration_test",

    # lib/app
    "lib\app\env",
    "lib\app\router",
    "lib\app\di\modules",
    "lib\app\theme",
    "lib\app\localization\l10n",
    "lib\app\analytics",

    # lib/core
    "lib\core\constants",
    "lib\core\errors",
    "lib\core\utils",
    "lib\core\network\interceptors",
    "lib\core\storage",
    "lib\core\platform",
    "lib\core\domain",
    "lib\core\presentation\state",
    "lib\core\presentation\navigation",
    "lib\core\extensions",
    "lib\core\config",

    # lib/shared
    "lib\shared\design_system\atoms",
    "lib\shared\design_system\molecules",
    "lib\shared\design_system\organisms",
    "lib\shared\design_system\layout",
    "lib\shared\charts",
    "lib\shared\forms",
    "lib\shared\dialogs",
    "lib\shared\animations",
    "lib\shared\misc",

    # lib/features root
    "lib\features",

    # features/auth
    "lib\features\auth\data\datasources",
    "lib\features\auth\data\models",
    "lib\features\auth\data\repositories_impl",
    "lib\features\auth\domain\entities",
    "lib\features\auth\domain\repositories",
    "lib\features\auth\domain\usecases",
    "lib\features\auth\presentation\pages",
    "lib\features\auth\presentation\controllers",
    "lib\features\auth\presentation\widgets",

    # features/onboarding
    "lib\features\onboarding\data\datasources",
    "lib\features\onboarding\data\models",
    "lib\features\onboarding\domain\entities",
    "lib\features\onboarding\domain\usecases",
    "lib\features\onboarding\presentation\pages",
    "lib\features\onboarding\presentation\controllers",
    "lib\features\onboarding\presentation\widgets",

    # features/profile
    "lib\features\profile\data\datasources",
    "lib\features\profile\data\models",
    "lib\features\profile\domain\entities",
    "lib\features\profile\domain\usecases",
    "lib\features\profile\presentation\pages",
    "lib\features\profile\presentation\controllers",
    "lib\features\profile\presentation\widgets",

    # features/dashboard
    "lib\features\dashboard\domain\entities",
    "lib\features\dashboard\domain\usecases",
    "lib\features\dashboard\presentation\pages",
    "lib\features\dashboard\presentation\controllers",
    "lib\features\dashboard\presentation\widgets",

    # features/templates
    "lib\features\templates\data\datasources",
    "lib\features\templates\data\models",
    "lib\features\templates\data\repositories_impl",
    "lib\features\templates\domain\entities",
    "lib\features\templates\domain\usecases",
    "lib\features\templates\presentation\pages",
    "lib\features\templates\presentation\controllers",
    "lib\features\templates\presentation\widgets",

    # features/training
    "lib\features\training\data\datasources",
    "lib\features\training\data\models",
    "lib\features\training\domain\entities",
    "lib\features\training\domain\repositories",
    "lib\features\training\domain\usecases",
    "lib\features\training\presentation\pages",
    "lib\features\training\presentation\controllers",
    "lib\features\training\presentation\widgets",

    # features/nutrition
    "lib\features\nutrition\data\datasources",
    "lib\features\nutrition\data\models",
    "lib\features\nutrition\domain\entities",
    "lib\features\nutrition\domain\repositories",
    "lib\features\nutrition\domain\usecases",
    "lib\features\nutrition\presentation\pages",
    "lib\features\nutrition\presentation\controllers",
    "lib\features\nutrition\presentation\widgets",

    # features/sleep
    "lib\features\sleep\data\datasources",
    "lib\features\sleep\data\models",
    "lib\features\sleep\domain\entities",
    "lib\features\sleep\domain\repositories",
    "lib\features\sleep\domain\usecases",
    "lib\features\sleep\presentation\pages",
    "lib\features\sleep\presentation\controllers",
    "lib\features\sleep\presentation\widgets",

    # features/device_integration
    "lib\features\device_integration\data\datasources",
    "lib\features\device_integration\data\models",
    "lib\features\device_integration\domain\entities",
    "lib\features\device_integration\domain\repositories",
    "lib\features\device_integration\domain\usecases",
    "lib\features\device_integration\presentation\pages",
    "lib\features\device_integration\presentation\controllers",
    "lib\features\device_integration\presentation\widgets",

    # features/groups
    "lib\features\groups\data\datasources",
    "lib\features\groups\data\models",
    "lib\features\groups\domain\entities",
    "lib\features\groups\domain\repositories",
    "lib\features\groups\domain\usecases",
    "lib\features\groups\presentation\pages",
    "lib\features\groups\presentation\controllers",
    "lib\features\groups\presentation\widgets",

    # features/analytics
    "lib\features\analytics\data\datasources",
    "lib\features\analytics\data\models",
    "lib\features\analytics\domain\entities",
    "lib\features\analytics\domain\repositories",
    "lib\features\analytics\domain\usecases",
    "lib\features\analytics\presentation\pages",
    "lib\features\analytics\presentation\controllers",
    "lib\features\analytics\presentation\widgets",

    # features/notifications
    "lib\features\notifications\data\datasources",
    "lib\features\notifications\data\models",
    "lib\features\notifications\domain\entities",
    "lib\features\notifications\domain\repositories",
    "lib\features\notifications\domain\usecases",
    "lib\features\notifications\presentation\pages",
    "lib\features\notifications\presentation\controllers",

    # features/settings / support / legal
    "lib\features\settings\domain\entities",
    "lib\features\settings\presentation\pages",
    "lib\features\settings\presentation\widgets",
    "lib\features\support",
    "lib\features\legal",

    # Placeholders: experiments & wellbeing
    "lib\features\experiments",
    "lib\features\wellbeing"
)

foreach ($folder in $folders) {
    New-Dir $folder
}

Write-Host "Estructura creada con éxito ✅" -ForegroundColor Green
