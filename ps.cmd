@echo off
title 代理切换器
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0proxy-switcher.ps1"
