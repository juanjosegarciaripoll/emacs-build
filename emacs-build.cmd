@echo off
if %1==--help goto help
if %1==-h goto help
if %1==-? goto help
goto run

:help
type %~dp0\scripts\help.txt
goto:eof

:run
powershell -c scripts\setup-msys2.ps1
.\scripts\msys2.cmd -c "./emacs-build.sh %*"
