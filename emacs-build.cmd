@echo off
if x%1 == x goto default
if %1==--help goto help
if %1==-h goto help
if %1==-? goto help
goto run

:default
emacs-build.cmd --clone --deps --build --pack-emacs --pdf-tools --mu --isync --hunspell --pack-all
goto:eof

:help
type %~dp0\scripts\help.txt
goto:eof

:run
powershell -c scripts\setup-msys2.ps1
.\scripts\msys2.cmd -c "./emacs-build.sh %*"
