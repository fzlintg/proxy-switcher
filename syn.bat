@echo off
chcp 65001 >nul 2>&1

cd /d "%~dp0"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [错误] 当前目录不是Git仓库!
    exit /b 1
)

echo.
echo [同步] 当前分支:
git branch --show-current

echo.
echo [同步] 检查变更...
git status --short

git add -A

git diff --cached --quiet
if errorlevel 1 (
    echo.
    echo [同步] 提交变更...
    git commit -m "auto: %date% %time:~0,8%"
) else (
    echo.
    echo [同步] 无变更
)

echo.
echo [同步] 推送中...
git push

if errorlevel 1 (
    echo [同步] 推送失败，尝试拉取后重试...
    git pull --rebase
    git push
)

echo.
echo [同步] 完成!
git log -1 --oneline
echo.
