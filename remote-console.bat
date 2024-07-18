@echo off
set Path=C:\Program Files\Oracle\VirtualBox;%Path%
set VM_NAME=%~1
set VM_USER=%~2
set VM_PORT=%~3
VBoxManage showvminfo "%VM_NAME%" --machinereadable | findstr /i "VMState=" | findstr /i "running" > nul
if %ERRORLEVEL% neq 0 (
    VBoxManage startvm "%VM_NAME%" --type headless
)
ssh "%VM_USER%@localhost" -p "%VM_PORT%"
