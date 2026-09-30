@echo off
rem duplo clique: sobe o servidor local e abre o HOST. Args repassados (ex.: cam.cmd MINHACHAVE)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cam.ps1" %*
