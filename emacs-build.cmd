@echo off
powershell -c scripts\setup-msys2.ps1
.\scripts\msys2.cmd -c "./emacs-build.sh %*"
