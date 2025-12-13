param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName
)

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- 非管理者なら自分自身を昇格再実行 ---
if (-not (Is-Admin)) {

    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" `"$ServiceName`""

    Start-Process powershell -ArgumentList $args -Verb RunAs
    exit 0
}

# --- サービス存在確認 ---
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Error "Service '$ServiceName' not found."
    exit 1
}

# --- 既に起動中なら成功 ---
if ($svc.Status -eq 'Running') {
    exit 0
}

# --- 起動処理 ---
try {
    Start-Service -Name $ServiceName -ErrorAction Stop
}
catch {
    Write-Error "Failed to start service '$ServiceName'."
    exit 1
}

# --- 起動確認 ---
$svc.Refresh()
if ($svc.Status -eq 'Running') {
    exit 0
}

exit 1
