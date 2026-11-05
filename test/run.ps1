$ErrorActionPreference = 'Stop'

$vim = $null
$cmd = Get-Command vim.exe -ErrorAction SilentlyContinue
if ($cmd) {
    $vim = $cmd.Source
}
if (-not $vim) {
    $vim = 'C:\Program Files\Vim\vim.exe'
}

$result = Join-Path $PSScriptRoot 'result.txt'
$env:SP_TEST_RESULT = $result
Remove-Item $result -ErrorAction SilentlyContinue

& $vim -Nu (Join-Path $PSScriptRoot 'vimrc') -S (Join-Path $PSScriptRoot 'test_smart_pwd.vim')
$code = $LASTEXITCODE

if (Test-Path $result) {
    $text = (Get-Content $result -Raw).Trim()
    Write-Output $text
    if ($text -ne 'PASS') {
        exit 1
    }
}
else {
    Write-Output 'No result file produced'
    exit 1
}

exit $code
