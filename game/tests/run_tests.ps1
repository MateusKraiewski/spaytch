<#
.SYNOPSIS
    Verifica a compilação de todos os scripts do projeto e, só então, roda os testes headless.

.DESCRIPTION
    Corrige dois problemas reais descobertos rodando contra Godot 4.7.2 (ver
    docs/ARCHITECTURE.md, "Phase 0.2.1" e "Phase 0.3"):

    1) `godot --headless --script X.gd` pode imprimir "ALL TESTS PASSED" com exit code 0
       mesmo quando um script do qual X.gd depende (referenciado via class_name, ex:
       MapValidator) falhou ao compilar.

         - `--check-only --script <arquivo-com-o-erro>`        -> exit code != 0 (confiável)
         - `--check-only --script <arquivo-que-DEPENDE-dele>`   -> exit code 0 (NÃO confiável)
         - `--editor --quit` (scan completo do projeto)         -> exit code 0 (NÃO confiável)

       Godot só propaga o erro de compilação no exit code quando o arquivo checado é
       exatamente aquele com o problema. Este script contorna isso rodando `--check-only` em
       CADA .gd do projeto, individualmente, antes de rodar qualquer teste — garante que o
       arquivo com erro (seja ele qual for) será checado diretamente em algum momento da
       varredura e vai falhar com exit code != 0, abortando a execução dos testes.

    2) O cache de classes globais do Godot (registro de `class_name`, persistido em
       `.godot/global_script_class_cache.cfg`) só é atualizado por um scan de projeto do
       editor (`--editor --quit`) — NÃO automaticamente por uma execução normal ou por
       `--check-only`. Um `class_name` novo (ex: MapPath, BasicEnemy, EnemySpawner ao serem
       criados na Phase 0.3) fica invisível para QUALQUER outro script — inclusive em
       execução normal do jogo, não só em `--check-only` — até esse cache ser atualizado.
       Sem isso, todo o compile-check (e a própria execução do jogo) falha com
       "Identifier not found" para classes que na verdade estão corretas. Por isso este
       script sempre roda um `--editor --quit` de refresh ANTES do compile-check por arquivo.

    Não depende de nenhum addon externo — só do próprio binário do Godot.

.PARAMETER GodotExe
    Caminho para o executável do Godot 4.7.2. Se omitido, usa $env:GODOT_BIN, ou tenta "godot"
    no PATH.

.EXAMPLE
    ./run_tests.ps1
    ./run_tests.ps1 -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
#>
param(
    [string]$GodotExe = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" })
)

$ProjectPath = Split-Path -Parent $PSScriptRoot

$godotCmd = Get-Command $GodotExe -ErrorAction SilentlyContinue
if (-not $godotCmd) {
    Write-Host "Godot executable not found: '$GodotExe'." -ForegroundColor Red
    Write-Host "Set -GodotExe, or `$env:GODOT_BIN, or add 'godot' to PATH." -ForegroundColor Red
    exit 1
}
$Godot = $godotCmd.Source

Write-Host "== Phase 1/3: refresh global class_name cache (editor scan) ==" -ForegroundColor Cyan
& $Godot --headless --editor --quit --path $ProjectPath | Out-Null
Write-Host "  Cache refreshed."

Write-Host ""
Write-Host "== Phase 2/3: compile-check every .gd script individually ==" -ForegroundColor Cyan
$scriptFiles = Get-ChildItem -Path $ProjectPath -Recurse -Filter *.gd |
    Where-Object { $_.FullName -notmatch '\\\.godot\\' }

$compileFailures = @()
foreach ($file in $scriptFiles) {
    $relPath = $file.FullName.Substring($ProjectPath.Length + 1) -replace '\\', '/'
    $resPath = "res://$relPath"
    & $Godot --headless --check-only --path $ProjectPath --script $resPath
    if ($LASTEXITCODE -ne 0) {
        $compileFailures += $resPath
        Write-Host "  FAIL (exit $LASTEXITCODE): $resPath" -ForegroundColor Red
    }
}

if ($compileFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "Compile check failed for $($compileFailures.Count) script(s). Aborting before running tests." -ForegroundColor Red
    foreach ($f in $compileFailures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host "  All $($scriptFiles.Count) scripts compiled cleanly." -ForegroundColor Green

Write-Host ""
Write-Host "== Phase 3/3: run test suites ==" -ForegroundColor Cyan
$testFiles = @(
    "res://tests/grid_tests.gd",
    "res://tests/map_tests.gd",
    "res://tests/path_tests.gd",
    "res://tests/enemy_tests.gd",
    "res://tests/integration_tests.gd",
    "res://tests/dinosaur_definition_tests.gd",
    "res://tests/placement_tests.gd",
    "res://tests/targeting_tests.gd",
    "res://tests/dinosaur_tests.gd",
    "res://tests/projectile_tests.gd",
    "res://tests/combat_integration_tests.gd",
    "res://tests/economy_tests.gd",
    "res://tests/egg_tests.gd",
    "res://tests/wave_tests.gd",
    "res://tests/game_loop_integration_tests.gd",
    "res://tests/ux_tests.gd",
    "res://tests/animated_visual_tests.gd"
)
$testFailures = @()
foreach ($test in $testFiles) {
    Write-Host "-- $test --"
    & $Godot --headless --path $ProjectPath --script $test
    $exit = $LASTEXITCODE
    Write-Host "   exit code: $exit"
    if ($exit -ne 0) { $testFailures += $test }
}

if ($testFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "$($testFailures.Count) test suite(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "ALL GREEN: compile-check + tests passed." -ForegroundColor Green
exit 0
