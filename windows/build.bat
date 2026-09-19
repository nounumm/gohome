@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo === gohome Windows 빌드 ===
echo.

REM 네트워크 드라이브(Z: 공유 폴더)에서 빌드하면 파일 잠금·권한 문제가 난다.
net use "%~d0" >nul 2>&1
if not errorlevel 1 (
  echo [중단] 네트워크 드라이브 %~d0 에서 실행 중입니다.
  echo        C:\dev 같은 로컬 디스크에 복사한 뒤 다시 실행하세요.
  echo.
  pause
  exit /b 1
)

where dotnet >nul 2>&1
if errorlevel 1 (
  echo [중단] dotnet 을 찾을 수 없습니다. .NET 8 SDK 를 설치하세요.
  echo        https://dotnet.microsoft.com/download/dotnet/8.0
  echo.
  pause
  exit /b 1
)

echo [1/2] slim — 런타임 필요, 작은 exe
echo.
dotnet publish GoHome\GoHome.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o "%~dp0dist\slim"
if errorlevel 1 goto fail

echo.
echo [2/2] full — 런타임 포함, 단일 파일 압축
echo.
dotnet publish GoHome\GoHome.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o "%~dp0dist\full"
if errorlevel 1 goto fail

echo.
echo === 완료 ===
call :size "%~dp0dist\slim\GoHome.exe" slim
call :size "%~dp0dist\full\GoHome.exe" full
echo.
echo 실행해볼 것: dist\slim\GoHome.exe
echo.
pause
exit /b 0

:size
if not exist %1 (
  echo   %2  — 파일 없음
  goto :eof
)
for %%F in (%1) do set /a SZMB=%%~zF/1048576
for %%F in (%1) do echo   %2  %%~zF bytes ^(약 %SZMB% MB^)
goto :eof

:fail
echo.
echo [실패] 빌드가 중단됐습니다. 위 오류를 확인하세요.
echo.
pause
exit /b 1
