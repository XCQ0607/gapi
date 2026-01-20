@echo off
REM CFspider 集成测试脚本
REM 设置 cfspider 环境变量

echo ========================================
echo CFspider 集成配置测试
echo ========================================
echo.

REM 设置 cfspider 配置
set CFSPIDER_ENDPOINT=https://cfspider.web3.dpdns.org
set CFSPIDER_TOKEN=

REM 设置其他必要的环境变量（如果需要）
REM set AUTH_JSON_1=...
REM set API_KEYS=...

echo 环境变量已设置:
echo   CFSPIDER_ENDPOINT=%CFSPIDER_ENDPOINT%
echo   CFSPIDER_TOKEN=%CFSPIDER_TOKEN%
echo.
echo 正在启动服务器...
echo ========================================
echo.

node unified-server.js

pause
