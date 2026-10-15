@echo off
chcp 65001 >nul
echo ============================================
echo    RogueCoop - Windows 导出向导
echo ============================================
echo.
echo 正在启动 Godot 编辑器...
echo 请在 Godot 中执行：
echo   项目 -> 导出 -> 添加 Windows Desktop
echo   -> Export Project -> 选择桌面位置
echo.
echo 按任意键启动 Godot...
pause >nul

start /d "D:\Godot" Godot_v4.7.2-stable_win64.exe --path "%~dp0"

echo.
echo Godot 已启动。导出完成后按任意键退出。
pause >nul
