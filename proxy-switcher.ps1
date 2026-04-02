# 强制控制台输出为 UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigFile = Join-Path $PSScriptRoot "config.json"

function Get-Proxies {
    if (-not (Test-Path $ConfigFile)) {
        @{ proxies = @() } | ConvertTo-Json | Out-File $ConfigFile -Encoding utf8
    }
    return Get-Content $ConfigFile -Raw -Encoding utf8 | ConvertFrom-Json
}

function Save-Proxies($json) {
    $json | ConvertTo-Json -Depth 10 | Out-File $ConfigFile -Encoding utf8
}

function Show-Menu {
    param($json, $cursorIdx)
    
    # 获取系统当前代理设置
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $sysProxyEnable = (Get-ItemProperty -Path $regPath -Name "ProxyEnable").ProxyEnable
    $sysProxyServer = (Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue).ProxyServer
    if ($null -eq $sysProxyServer) { $sysProxyServer = "" }

    Clear-Host
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "   浏览器代理一键切换工具 (v1.3.0) " -ForegroundColor Cyan
    Write-Host "   作者: lintg@sina.com  2026 " -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "操作指南: " -ForegroundColor Gray
    Write-Host " [↑/↓] 移动光标  [Enter] 切换代理  [U/D] 上下移动排序 " -ForegroundColor Gray
    Write-Host " [Del] 删除配置  [S] 捕获当前      [E] 编辑文件  [Q] 退出 " -ForegroundColor Gray
    Write-Host ""
    Write-Host "当前配置列表 (红色为系统活动配置): "
    
    $i = 0
    foreach ($p in $json.proxies) {
        $pServer = if ($p.server) { $p.server } else { "" }
        $itemEnableValue = if ($p.enable) { 1 } else { 0 }
        
        $isCurrent = ($pServer -eq $sysProxyServer -and $itemEnableValue -eq $sysProxyEnable)
        $isSelected = ($i -eq $cursorIdx)
        
        # 颜色逻辑
        $fgColor = if ($isCurrent) { "Red" } elseif ($p.enable) { "Yellow" } else { "Gray" }
        if ($isSelected) {
            $bgColor = "White"
            $fgColor = "Black"
        } else {
            $bgColor = "Black"
        }
        
        $status = if ($p.enable) { "[ON ]" } else { "[OFF]" }
        $currentMark = if ($isCurrent) { " <--- 活动 " } else { "" }
        $cursorPrefix = if ($isSelected) { "> " } else { "  " }
        
        Write-Host "$($cursorPrefix)$($i + 1). $($status) [$($p.name)] - $($pServer)$($currentMark) " -ForegroundColor $fgColor -BackgroundColor $bgColor
        $i++
    }
    Write-Host ""
}

$cursorIdx = 0
while ($true) {
    $json = Get-Proxies
    $count = $json.proxies.Count
    if ($cursorIdx -ge $count) { $cursorIdx = [Math]::Max(0, $count - 1) }

    Show-Menu $json $cursorIdx
    
    if ($host.UI.RawUI.KeyAvailable) {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        if ($key.VirtualKeyCode -eq 38) { # UpArrow
            $cursorIdx = if ($cursorIdx -gt 0) { $cursorIdx - 1 } else { $count - 1 }
        }
        elseif ($key.VirtualKeyCode -eq 40) { # DownArrow
            $cursorIdx = if ($cursorIdx -lt $count - 1) { $cursorIdx + 1 } else { 0 }
        }
        elseif ($key.VirtualKeyCode -eq 13) { # Enter
            if ($count -gt 0) {
                $p = $json.proxies[$cursorIdx]
                $enableFlag = if ($p.enable) { 1 } else { 0 }
                $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
                Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value $enableFlag
                if ($p.enable) { Set-ItemProperty -Path $regPath -Name "ProxyServer" -Value $p.server }
                $bypassValue = if ($p.bypass) { $p.bypass } else { $json.default_bypass }
                Set-ItemProperty -Path $regPath -Name "ProxyOverride" -Value $bypassValue
                
                # 刷新缓存
                try {
                    $signature = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
                    $wininet = Add-Type -MemberDefinition $signature -Name "WinInet_$([Guid]::NewGuid().ToString('N'))" -Namespace "WinInet" -PassThru
                    $wininet::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
                    $wininet::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
                } catch {}
                Write-Host "`n 已成功切换到: $($p.name) " -ForegroundColor Green
                Start-Sleep -Milliseconds 500
            }
        }
        elseif ($key.Character -eq 's' -or $key.Character -eq 'S') {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            $currentEnable = Get-ItemProperty -Path $regPath -Name "ProxyEnable"
            $currentServer = Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue
            $currentBypass = Get-ItemProperty -Path $regPath -Name "ProxyOverride" -ErrorAction SilentlyContinue
            
            Write-Host "`n [捕获当前代理配置] " -ForegroundColor Green
            $name = Read-Host " 输入新配置的名称 "
            if (-not $name) { $name = "配置_$(Get-Date -Format 'HHmm') " }
            
            $newProxy = @{
                name   = $name
                server = if ($currentServer) { $currentServer.ProxyServer } else { "" }
                enable = if ($currentEnable -and $currentEnable.ProxyEnable -eq 1) { $true } else { $false }
                bypass = if ($currentBypass) { $currentBypass.ProxyOverride } else { "" }
            }
            $json.proxies += $newProxy
            Save-Proxies $json
            Write-Host " 已保存！ " -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        elseif ($key.Character -eq 'e' -or $key.Character -eq 'E') {
            notepad $ConfigFile
        }
        elseif ($key.Character -eq 'q' -or $key.Character -eq 'Q') {
            break
        }
        elseif ($key.Character -eq 'u' -or $key.Character -eq 'U') {
            if ($cursorIdx -gt 0) {
                $temp = $json.proxies[$cursorIdx]
                $json.proxies[$cursorIdx] = $json.proxies[$cursorIdx - 1]
                $json.proxies[$cursorIdx - 1] = $temp
                Save-Proxies $json
                $cursorIdx--
            }
        }
        elseif ($key.Character -eq 'd' -or $key.Character -eq 'D') {
            if ($cursorIdx -lt $count - 1) {
                $temp = $json.proxies[$cursorIdx]
                $json.proxies[$cursorIdx] = $json.proxies[$cursorIdx + 1]
                $json.proxies[$cursorIdx + 1] = $temp
                Save-Proxies $json
                $cursorIdx++
            }
        }
        elseif ($key.VirtualKeyCode -eq 46) { # Delete
            if ($count -gt 0) {
                $confirm = Read-Host "`n 确定要删除选中配置吗？(y/n) "
                if ($confirm -eq 'y') {
                    $json.proxies = $json.proxies | Where-Object { $_ -ne $json.proxies[$cursorIdx] }
                    Save-Proxies $json
                    if ($cursorIdx -ge $json.proxies.Count) { $cursorIdx = [Math]::Max(0, $json.proxies.Count - 1) }
                }
            }
        }
    }
    else {
        Start-Sleep -Milliseconds 100
    }
}

