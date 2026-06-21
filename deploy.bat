@echo off
cd /d "%~dp0"

echo Versienummers ophogen...
powershell -NoProfile -Command "$u8 = New-Object Text.UTF8Encoding($false); $bump = { param($s, $pat) [regex]::new($pat).Replace($s, { param($m) $maj=[int]$m.Groups[1].Value; $min=[int]$m.Groups[2].Value; $p=[int]$m.Groups[3].Value+1; if($p -gt 9){$p=0;$min++}; if($min -gt 9){$min=0;$maj++}; $m.Value.Substring(0,$m.Value.Length-$m.Groups[1].Value.Length-$m.Groups[2].Value.Length-$m.Groups[3].Value.Length-2) + $maj + '.' + $min + '.' + $p }, 1) }; $ixChanged = [bool](git status --porcelain -- index.html); $beChanged = [bool](git status --porcelain -- backend.html); if ($ixChanged) { $sw = [IO.File]::ReadAllText('sw.js', $u8); $sw = [regex]::Replace($sw, 'relax-breathing-humming-v(\d+)', { param($m) 'relax-breathing-humming-v' + ([int]$m.Groups[1].Value + 1) }); [IO.File]::WriteAllText('sw.js', $sw, $u8); $ix = [IO.File]::ReadAllText('index.html', $u8); $ix = & $bump $ix 'v(\d+)\.(\d+)\.(\d+)'; [IO.File]::WriteAllText('index.html', $ix, $u8); Write-Host 'Frontend-versie opgehoogd.' }; if ($beChanged) { $be = [IO.File]::ReadAllText('backend.html', $u8); $be = & $bump $be 'backend v(\d+)\.(\d+)\.(\d+)'; [IO.File]::WriteAllText('backend.html', $be, $u8); Write-Host 'Backend-versie opgehoogd.' }"

echo Bestanden kopieren naar deploy map...
copy /Y index.html deploy\index.html
copy /Y sw.js deploy\sw.js
copy /Y backend.html deploy\backend.html
if exist deploy\admin.html del /Q deploy\admin.html
if not exist deploy\tegels mkdir deploy\tegels
xcopy /Y /I /Q tegels\*.webp deploy\tegels\ >nul
if not exist deploy\js mkdir deploy\js
xcopy /Y /I /Q js\*.js deploy\js\ >nul

echo Wijzigingen naar GitHub sturen...
git add -A index.html sw.js backend.html js deploy\index.html deploy\sw.js deploy\backend.html deploy\js deploy\manifest.json deploy\tegels supabase
git commit -m "deploy update"
git push origin master:main

echo.
echo Klaar! App is live op:
echo https://rensstam.github.io/phytoforsan-app/deploy/
echo.
pause
