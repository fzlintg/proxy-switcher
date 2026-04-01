# 强制控制台输出为 UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigFile = "config.json"

function Show-Menu {
    if (-not (Test-Path $ConfigFile)) {
        @{ proxies = @() } | ConvertTo-Json | Out-File $ConfigFile -Encoding utf8
    }
    
    $json = Get-Content $ConfigFile -Raw -Encoding utf8 | ConvertFrom-Json
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      浏览器代理一键切换工具 (v1.0.0)" -ForegroundColor Cyan
    Write-Host "      作者: lintg@sina.com  版权所有 2026" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "当前配置列表:"
    
    $i = 1
    foreach ($p in $json.proxies) {
        $color = if ($p.enable) { "Yellow" } else { "Gray" }
        $status = if ($p.enable) { "[ON]" } else { "[OFF]" }
        Write-Host " $i. $($status) [$($p.name)] - $($p.server)" -ForegroundColor $color
        $i++
    }
    
    Write-Host ""
    Write-Host " s. 捕获并保存当前系统代理" -ForegroundColor Green
    Write-Host " e. 编辑配置文件 (Notepad)"
    Write-Host " q. 退出"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "选择操作 [1-$i, s, e, q]"
    
    if ($choice -eq 'q') { break }
    if ($choice -eq 'e') {
        notepad $ConfigFile
        continue
    }
    
    $json = Get-Content $ConfigFile -Raw -Encoding utf8 | ConvertFrom-Json
    
    if ($choice -eq 's') {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $currentEnable = Get-ItemProperty -Path $regPath -Name "ProxyEnable"
        $currentServer = Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue
        $currentBypass = Get-ItemProperty -Path $regPath -Name "ProxyOverride" -ErrorAction SilentlyContinue
        
        $name = Read-Host "输入新配置的名称"
        if (-not $name) { $name = "未命名配置_$(Get-Date -Format 'HHmm')" }
        
        $newServer = if ($currentServer) { $currentServer.ProxyServer } else { "" }
        $newEnable = if ($currentEnable -and $currentEnable.ProxyEnable -eq 1) { $true } else { $false }
        $newBypass = if ($currentBypass) { $currentBypass.ProxyOverride } else { "" }
        
        $newProxy = @{
            name   = $name
            server = $newServer
            enable = $newEnable
            bypass = $newBypass
        }
        
        $json.proxies += $newProxy
        $json | ConvertTo-Json -Depth 10 | Out-File $ConfigFile -Encoding utf8
        Write-Host "`n已成功保存当前配置！ " -ForegroundColor Green
        Start-Sleep -Seconds 1
        continue
    }

    if ([int]::TryParse($choice, [ref]0)) {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $json.proxies.Count) {
            $p = $json.proxies[$idx]
            $enable = if ($p.enable) { 1 } else { 0 }
            
            # 更新注册表
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value $enable
            
            if ($p.enable) {
                Set-ItemProperty -Path $regPath -Name "ProxyServer" -Value $p.server
            }
            
            # 如果配置中有 bypass 则使用，否则使用全局默认或空
            $bypassValue = if ($p.bypass) { $p.bypass } else { $json.default_bypass }
            Set-ItemProperty -Path $regPath -Name "ProxyOverride" -Value $bypassValue
            
            Write-Host "`n已成功切换到: $($p.name) " -ForegroundColor Green
            
            # 刷新系统设置以立即生效
            try {
                $signature = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
                $wininet = Add-Type -MemberDefinition $signature -Name "WinInet_$([Guid]::NewGuid().ToString('N'))" -Namespace "WinInet" -PassThru
                $wininet::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
                $wininet::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
            } catch {
                Write-Host "提示：刷新系统设置失败，可能需要手动刷新浏览器。 " -ForegroundColor Gray
            }
            
        } else {
            Write-Host "`n无效选择！ " -ForegroundColor Red
        }
    } else {
        Write-Host "`n请输入有效的数字或操作符。 " -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "按下回车键继续..."
}
