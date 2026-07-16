param(
    [string]$DbHost = 'localhost',
    [int]$DbPort = 5432,
    [string]$DbName = 'prevente_db',
    [string]$DbUser = 'postgres'
)

$ErrorActionPreference = 'Stop'
$resultFile = 'C:\tmp\prevente-product-restore-result.txt'
$seedFile = Join-Path $PSScriptRoot 'seed_demo_products.sql'
$knownPsqlPaths = @(
    'C:\Program Files\PostgreSQL\18\bin\psql.exe',
    'C:\Program Files\PostgreSQL\17\bin\psql.exe',
    'C:\Program Files\PostgreSQL\16\bin\psql.exe',
    'C:\Program Files\PostgreSQL\15\bin\psql.exe'
)

$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
$psql = if ($psqlCommand) {
    $psqlCommand.Source
} else {
    $knownPsqlPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $psql) {
    throw 'psql was not found. Install the PostgreSQL command-line tools first.'
}

$passwordBstr = [IntPtr]::Zero
try {
    $securePassword = Read-Host "PostgreSQL password for $DbUser@$DbHost" -AsSecureString
    if ($securePassword.Length -eq 0) {
        throw 'No PostgreSQL password was entered.'
    }

    $passwordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordBstr)

    & $psql `
        -v ON_ERROR_STOP=1 `
        -h $DbHost `
        -p $DbPort `
        -U $DbUser `
        -d $DbName `
        -f $seedFile
    if ($LASTEXITCODE -ne 0) {
        throw "Product restore failed (psql exit code $LASTEXITCODE)."
    }

    $catalogCount = & $psql `
        -At `
        -h $DbHost `
        -p $DbPort `
        -U $DbUser `
        -d $DbName `
        -c "SELECT COUNT(*) FROM produits WHERE reference IN ('41022-200','41022-250','41022-500','41022-1000','41022-2000','9305-200','9305-250','9305-500','9305-1000','9305-2000','ALP-200','ALP-250','ALP-500','ALP-1000','ALP-2000','ALC-200','ALC-250','ALC-500','ALC-1000','ALC-2000')"
    if ($LASTEXITCODE -ne 0) {
        throw "Product verification failed (psql exit code $LASTEXITCODE)."
    }

    "SUCCESS catalog_count=$catalogCount" | Set-Content -LiteralPath $resultFile -Encoding utf8
    Write-Host "Restore complete: $catalogCount of 20 TeaSud products are present." -ForegroundColor Green
} catch {
    "ERROR $($_.Exception.Message)" | Set-Content -LiteralPath $resultFile -Encoding utf8
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    if ($passwordBstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBstr)
    }
}

Read-Host 'Press Enter to close'
