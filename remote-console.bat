@echo off
set EXITCODE=%ERRORLEVEL%
if "%~1"=="/?" goto :usage
set ARGC=0
for %%a in ( %* ) do set /a ARGC+=1
if %ARGC% equ 0 (
    goto :usage
)
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
    echo VirtualBox が検出されませんでした。>&2
    echo %CMDCMDLINE% | findstr /I " /c " >nul && echo. && pause
    exit /b 1
) else set PATH=%VBOX_DIR%;%PATH%
set INTERVAL_SECONDS=1
set TIMEOUT_ERRORLEVEL=255
set VM_NAME=%~1
chcp 65001 > nul
VBoxManage showvminfo "%VM_NAME%" --machinereadable | findstr /i "VMState=" | findstr /i "running" > nul
if %ERRORLEVEL% neq 0 (
    VBoxManage startvm "%VM_NAME%" --type headless
)
if %ARGC% equ 2 (
    set SSH_ARGS="%~2"
    goto :connection
)
set VM_USER=%~2
set VM_HOST=%~3
if "%VM_HOST%"=="" for /f "tokens=2" %%A in ('VBoxManage guestproperty get "%VM_NAME%" "/VirtualBox/GuestInfo/Net/0/V4/IP"') do if not %%A==value (
    set VM_HOST=%%A
    set W=...
    goto :userspecified
)
set W="%VM_HOST:0=%"
set W="%W:1=%"
set W="%W:2=%"
set W="%W:3=%"
set W="%W:4=%"
set W="%W:5=%"
set W="%W:6=%"
set W="%W:7=%"
set W="%W:8=%"
set W="%W:9=%"
set W=%W:"=%
:userspecified
if "%VM_USER%"=="" (
    set /p VM_USER=login: 
    goto :userspecified
)
if "%W%"=="" (
    set SSH_ARGS="%VM_USER%@localhost" -p "%VM_HOST%"
) else (
    set SSH_ARGS="%VM_USER%@%VM_HOST%"
)
goto :connection
:polling
VBoxManage showvminfo "%VM_NAME%" --machinereadable | findstr /i "VMState=" | findstr /i "running" > nul
if %ERRORLEVEL% neq 0 (
    goto :termination
)
:connection
ssh -t %SSH_ARGS% 2> nul
if %ERRORLEVEL% neq %TIMEOUT_ERRORLEVEL% (
    set EXITCODE=%ERRORLEVEL%
    echo.
    echo.
)
timeout /t %INTERVAL_SECONDS% > nul
goto :polling
:usage
echo Oracle VirtualBox の仮想マシン (VM) のゲストOSを起動し、
echo これをホストOS側のターミナルで遠隔操作を行います。
echo.
echo 使用方法:
echo     %~nx0 VM名
echo     %~nx0 VM名 パターン
echo     %~nx0 VM名 ユーザー名 接続先
echo.
echo 引数:
echo     VM名	ゲストOSとなるVM名を指定します。
echo     パターン	SSH構成ファイル ( %%USERPROFILE%%\.ssh\config )
echo            	に登録された Host パターンを指定します。
echo     ユーザー名	ゲストOSのログインユーザー名を指定します。
echo            	"" (空値) を指定すると、標準入力から
echo            	ログインユーザー名を指定できます。
echo     接続先	ゲストOSの接続先となるホスト名、IPアドレス、
echo            	又はポート番号を指定します。
echo            	NATポートフォワーディングを利用する場合は、
echo            	ポート番号を指定します。
echo                "" (空値) を指定すると、自動検出を試みます。
echo %CMDCMDLINE% | findstr /I " /c " >nul && echo. && pause
:termination
exit %EXITCODE%
