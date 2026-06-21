@echo off
cd /d "%~dp0"

echo Versienummers ophogen...
powershell -NoProfile -Command "$u8 = New-Object Text.UTF8Encoding($false); $sw = [IO.File]::ReadAllText('sw.js', $u8); $sw = [regex]::Replace($sw, 'relax-breathing-humming-v(\d+)', { param($m) 'relax-breathing-humming-v' + ([int]$m.Groups[1].Value + 1) }); [IO.File]::WriteAllText('sw.js', $sw, $u8); $ix = [IO.File]::ReadAllText('index.html', $u8); $rx = New-Object regex 'v(\d+)\.(\d+)\.(\d+)'; $ix = $rx.Replace($ix, { param($m) $maj = [int]$m.Groups[1].Value; $min = [int]$m.Groups[2].Value; $pat = [int]$m.Groups[3].Value + 1; if ($pat -gt 9) { $pat = 0; $min += 1 }; if ($min -gt 9) { $min = 0; $maj += 1 }; 'v' + $maj + '.' + $min + '.' + $pat }, 1); [IO.File]::WriteAllText('index.html', $ix, $u8)"

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
