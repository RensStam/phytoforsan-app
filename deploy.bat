@echo off
cd /d "%~dp0"

echo Bestanden kopiëren naar deploy map...
copy /Y index.html deploy\index.html
copy /Y sw.js deploy\sw.js

echo Wijzigingen naar GitHub sturen...
git add deploy\index.html deploy\sw.js
git commit -m "deploy update"
git push origin main

echo.
echo Klaar! App is live op:
echo https://rensstam.github.io/phytoforsan-app/deploy/
echo.
pause
