@echo off
title ReBoundary MetaServer
color 0A
echo =========================================
echo Starting ReBoundary MetaServer...
echo =========================================
cd /d "%~dp0ReBoundaryMetaServer"
node index.js
pause
