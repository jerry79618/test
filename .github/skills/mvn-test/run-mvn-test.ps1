param(
    [Parameter(Mandatory=$true)]  [string]$ProjectRoot,
    [Parameter(Mandatory=$true)]  [string]$Tag,
    [Parameter(Mandatory=$true)]  [string]$EnvProfile
)

# Set JAVA_HOME if not set
if (-not $env:JAVA_HOME) {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $env:JAVA_HOME = Split-Path (Split-Path $javaCmd.Source -Parent) -Parent
    }
}
if ($env:JAVA_HOME) {
    $env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH
}

# Set Maven path if not in PATH
if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    $mvnCmd = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        $env:PATH = (Split-Path $mvnCmd.Source -Parent) + ";" + $env:PATH
    }
}

# Switch to project root
Set-Location -Path $ProjectRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project Root : $ProjectRoot"              -ForegroundColor Cyan
Write-Host "Tag          : $Tag"                      -ForegroundColor Cyan
Write-Host "Env Profile  : $EnvProfile"               -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Execute mvn test
mvn test "-Dcucumber.filter.tags=@$Tag" -P $EnvProfile

exit $LASTEXITCODE
