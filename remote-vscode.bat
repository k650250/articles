@echo off
set "VBOX_DIR="
for /f "tokens=2,*" %%A in ('
    reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Oracle\VirtualBox" /v InstallDir 2^>nul ^| find "InstallDir"
') do set "VBOX_DIR=%%B"
if "%VBOX_DIR%"=="" (
    for /f "tokens=2,*" %%A in ('
        reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Oracle\VirtualBox" /v InstallDir 2^>nul ^| find "InstallDir"
    ') do set "VBOX_DIR=%%B"
)
if "%VBOX_DIR%"=="" (
    echo Oracle VirtualBox が検出されませんでした。>&2
    echo %CMDCMDLINE% | findstr /I " /c " >nul && echo. && pause
    exit /b 1
) else set PATH=%VBOX_DIR%;%PATH%
if "%~1"=="/?" goto :usage

set VM_NAME=
set HOST_PATTERN=

if "%VM_NAME%%HOST_PATTERN%"=="" goto :usage
set WORKER_PATH=%TEMP%\%~n0-worker.bat
set STARTING_DIR=%~dp0
set SERVER_SERVICE_NAME=sshd
set INTERVAL_SECONDS=1
set ARGC=0
for %%a in ( %* ) do set /a ARGC+=1
if %ARGC% equ 0 (
    goto :console
)
echo @code --wait --remote "ssh-remote+%HOST_PATTERN%" "%~1" > "%WORKER_PATH%"
:waitforexit
if exist "%WORKER_PATH%" (
    timeout -t %INTERVAL_SECONDS% > nul
    goto :waitforexit
)
goto :eof
:console
del /q "%WORKER_PATH%" 2> nul
for /f "tokens=4" %%A in ('sc query "%SERVER_SERVICE_NAME%" ^| find "STATE"') do (
    set SERVER_SERVICE_STATE=%%A
)
if /i "%SERVER_SERVICE_STATE%"=="STOPPED" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%STARTING_DIR%Start-ServiceWithElevation.ps1" "%SERVER_SERVICE_NAME%"
    if %ERRORLEVEL% neq 0 (
        echo サービス "%SERVER_SERVICE_NAME%" の起動に失敗しました。終了コード=%ERRORLEVEL% >&2
        pause
        exit %ERRORLEVEL%
    )
)
start "" /b /d "%STARTING_DIR%" remote-console.bat "%VM_NAME%" "%HOST_PATTERN%"
:waituntilready
if not exist %WORKER_PATH% (
    timeout -t %INTERVAL_SECONDS% > nul
    goto :waituntilready
)
cmd /c "%WORKER_PATH%"
del /q "%WORKER_PATH%" 2> nul
goto :eof
:usage
for /f "tokens=2" %%A in ('VBoxManage list hostonlyifs ^| findstr /i "IPAddress:"') do (
    set HOST_IP=%%A
)
set SELF_PATH=%~dpnx0
echo Oracle VirtualBox の仮想マシン (VM) のゲストOSを起動し、
echo これをホストOS側の Visual Studio Code で遠隔操作を行います。
echo.
echo ホストOS側での事前準備:
echo     1. sshd (OpenSSH SSH Server) のインストール
echo     2. SSH構成ファイル ( %%USERPROFILE%%\.ssh\config )
echo        に Host パターンの記述
echo     3. %~nx0 ファイル冒頭部の環境変数定義
echo        VM_NAME にゲストOSのVM名、
echo        HOST_PATTERN に Host パターンの値の設定
echo     4. Visual Studio Code の拡張機能 Remote Development
echo        (ID: ms-vscode-remote.vscode-remote-extensionpack)
echo        のインストール
echo     5. Visual Studio Code の、リモート エクスプローラーにて
echo        Host パターンが検出されているかの確認
echo.
echo ゲストOS側での事前準備:
echo     1. スタートアップ・スクリプト (例: ~/.bashrc) への
echo        下記コードの追記
echo.
echo ```bash
echo if [ ! -e .vscode-running ]; then
echo     touch .vscode-running ^&^& ssh -tt '%USERNAME%@%HOST_IP%' ""%SELF_PATH:\=\\%" "$HOME""
echo     rm -f .vscode-running ^&^& shutdown -h now
echo fi
echo ```
echo.
echo 使用方法:
echo     %~nx0 [パス]
echo.
echo 引数:
echo     [パス]	Visual Studio Code にてSSH接続後の初期ディレクトリ
echo            	のパスを指定します。
echo             	※注意　この引数は、特殊な場合を除いて、使用不可
echo.
echo %CMDCMDLINE% | findstr /I " /c " >nul && echo. && pause
