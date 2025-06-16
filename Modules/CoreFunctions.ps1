<#
.SYNOPSIS
    Belirtilen komutu yönetici haklarıyla gizli bir pencerede çalıştırır.
#>
function Invoke-AdminCommand {
    param ([string]$Command, [string]$Arguments = "")
    Add-Log "Yönetici komutu çalıştırılıyor: $Command $Arguments" -Level "DEBUG"
    try {
        $ps = New-Object System.Diagnostics.ProcessStartInfo

        # NSudo.exe'nin yolu
        $nsudoPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\NSudo.exe" # Veya NSudo.exe'nin WinFast.ps1'in olduğu klasörde olduğunu varsayarak: Join-Path $PSScriptRoot "Modules\NSudo.exe"
        # Not: Yukarıdaki satırı, NSudo.exe'nin betiğin neresinde olduğuna bağlı olarak ayarlamanız gerekebilir.
        # Eğer WinFast.ps1 ile aynı seviyede bir 'Modules' klasörü içindeyse, ilk tanım doğru.
        # Eğer NSudo.exe doğrudan WinFast.ps1 ile aynı klasördeyse, $nsudoPath = Join-Path $PSScriptRoot "NSudo.exe" olur.
        # Genellikle "Modules" klasörü içinde olması tercih edilir.

        if ($Command -eq "reg.exe" -and (Test-Path $nsudoPath)) {
            Add-Log "reg.exe için NSudo ile çalıştırma denemesi yapılıyor." -Level "INFO"
            $nsudoArguments = "-U:T -P:E -Wait -ShowWindowMode:hide `"$env:SystemRoot\System32\reg.exe`" $Arguments"
            
            $ps.FileName = $nsudoPath
            $ps.Arguments = $nsudoArguments
            $ps.Verb = "runas" # NSudo'nun kendisi yönetici olarak çalışmalı
            $ps.UseShellExecute = $true
            $ps.WindowStyle = "Hidden"
            
            $process = [System.Diagnostics.Process]::Start($ps)
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { throw "NSudo komutu hata koduyla tamamlandı: $($process.ExitCode)" }
            return $true
        } else {
            # reg.exe dışındaki komutlar veya NSudo bulunamazsa standart yöntem
            $ps.FileName = $Command
            $ps.Arguments = $Arguments
            $ps.Verb = "runas"
            $ps.UseShellExecute = $true
            $ps.WindowStyle = "Hidden"
            
            $process = [System.Diagnostics.Process]::Start($ps)
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { throw "Komut hata koduyla tamamlandı: $($process.ExitCode)" }
            return $true
        }
    } catch { 
        Add-Log "Yönetici komutu hatası: $_" -Level "ERROR"
        return $false 
    }
}
<#
.SYNOPSIS
    Bir Windows hizmetinin başlangıç türünü ve durumunu ayarlar. (Hibrit - NSudo Destekli)
#>
function Set-ServiceState {
    param([string]$ServiceName, [string]$StartupType = "Disabled", [boolean]$StopService = $true)
    
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (!$service) { Add-Log "Servis bulunamadı: $ServiceName" -Level "WARN"; return }

    Add-Log "Servis durumu ayarlanıyor: $ServiceName -> Başlangıç: $StartupType, Durdur: $StopService" -Level "ACTION"

    if (-not ($Global:TempUndoServiceActions | Where-Object { $_.ServiceName -eq $ServiceName -and $_.Action -eq "SetServiceState" })) {
        $originalServiceState = @{
            Action      = "SetServiceState"
            ServiceName = $ServiceName
            OriginalStartupType = $service.StartType
            OriginalStatus      = $service.Status
        }
        $Global:TempUndoServiceActions += $originalServiceState
    }

    try {
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        if ($StopService -and (Get-Service $ServiceName -ErrorAction SilentlyContinue).Status -eq 'Running') { 
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop 
        }
        Add-Log "Servis '$ServiceName' başarıyla ayarlandı (PS ile)." -Level "SUCCESS"
    } catch {
        if ($_.Exception.Message -like "*Erişim engellendi*" -or $_.Exception.Message -like "*Access is denied*") {
            Add-Log "Standart yöntemle erişim engellendi. NSudo ile yeniden deneniyor..." -Level "WARN"
            
            $nsudoPath = Join-Path $PSScriptRoot "Modules\NSudo.exe"
            
            if (-not (Test-Path $nsudoPath)) {
                Add-Log "HATA: NSudo.exe '$nsudoPath' yolunda bulunamadı! Korunan servis '$ServiceName' değiştirilemiyor." -Level "ERROR"
                Write-Host "HATA: NSudo.exe '$nsudoPath' yolunda bulunamadı." -ForegroundColor Red
                return
            }

            $scStartupType = switch ($StartupType) {
                "Manual"    { "demand" }
                "Disabled"  { "disabled" }
                "Automatic" { "auto" }
                default     { "demand" }
            }

            $configArgs = "-U:T -P:E -Wait -ShowWindowMode:hide sc.exe config `"$ServiceName`" start= $scStartupType"
            if (Invoke-AdminCommand -Command $nsudoPath -Arguments $configArgs) {
                Add-Log "Servis başlangıç türü NSudo ile başarıyla ayarlandı: $StartupType" -Level "SUCCESS"
            } else { Add-Log "Servis başlangıç türü NSudo ile ayarlanamadı." -Level "ERROR" }

            if ($StopService) {
                $stopArgs = "-U:T -P:E -Wait -ShowWindowMode:hide sc.exe stop `"$ServiceName`""
                if (Invoke-AdminCommand -Command $nsudoPath -Arguments $stopArgs) {
                    Add-Log "Servis NSudo ile başarıyla durduruldu." -Level "SUCCESS"
                } else { Add-Log "Servis NSudo ile durdurulamadı (zaten durmuş olabilir)." -Level "WARN" }
            }
        } else {
            Add-Log "Servis '$ServiceName' ayarlanırken farklı bir hata oluştu: $_" -Level "ERROR"
        }
    }
}

<#
.SYNOPSIS
    Kayıt defteri değeri ayarlar veya oluşturur. (Hibrit Yöntem - En Güvenilir).
#>
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    
    $legacyPaths = @(
        'HKCU\Control Panel\Mouse',
        'HKCU\Control Panel\Keyboard',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects',
        'HKCU\Control Panel\Desktop',
        'HKCU\Software\Microsoft\Windows\DWM',
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem'
    )

    $normalizedPath = $Path -replace '^[A-Z]{3,4}:\\', ''
    $isLegacyPath = $false
    foreach ($legacy in $legacyPaths) {
        if ($normalizedPath -eq ($legacy -replace '^[A-Z]{3,4}:\\', '')) {
            $isLegacyPath = $true
            break
        }
    }

    if ($isLegacyPath) {
        Add-Log "Uyumluluk için '$Path' yolunda REG.EXE kullanılıyor." -Level "WARN"
        $regPath = $Path.Replace(':\', '\')
        $regType = "REG_" + $Type.ToUpperInvariant().Replace("STRING", "SZ").Replace("EXPANDSTRING", "EXPAND_SZ").Replace("MULTISTRING", "MULTI_SZ")

        $regValueForRegExe = if ($regType -eq "REG_BINARY" -and ($Value -is [System.Collections.ArrayList] -or $Value -is [array])) {
            ($Value | ForEach-Object { '{0:x2}' -f [byte]$_ }) -join ''
        } elseif ($regType -eq "REG_MULTI_SZ" -and $Value -is [array]) {
            ($Value -join '\0')
        } else {
            $Value
        }
        
        $arguments = "add `"$regPath`" /v `"$Name`" /t $regType /d `"$regValueForRegExe`" /f"
        
        if (-not (Invoke-AdminCommand -Command "reg.exe" -Arguments $arguments)) {
            Add-Log "reg.exe komutu ile '$Name' değeri ayarlanamadı." -Level "ERROR"
        } else {
            Add-Log "Kayıt defteri değeri başarıyla ayarlandı (reg.exe ile): $regPath -> '$Name' = '$Value'" -Level "SUCCESS"
        }

    } else {
        Add-Log "PS ile kayıt defteri değeri ayarlanıyor: $Path -> '$Name' = '$Value' (Tip: $Type)" -Level "INFO"
        try {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Add-Log "Kayıt defteri değeri başarıyla ayarlandı (PS ile): $Path -> '$Name' = '$Value'" -Level "SUCCESS"
        } catch {
            Add-Log "Kayıt defteri değeri ayarlanamadı: '$Path' -> '$Name'. Hata: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}


function Remove-RegistryKey {
    param ([string]$Path, [string]$Name = "")
    try {
        if ($Name) {
            if (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
                Add-Log "Kayıt defteri değeri başarıyla silindi: $Path -> $Name" -Level "SUCCESS"
            }
        } else {
            if (Test-Path -LiteralPath $Path) {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
                Add-Log "Kayıt defteri anahtarı başarıyla silindi: $Path" -Level "SUCCESS"
            }
        }
    } catch { Add-Log "Kayıt defteri silme hatası: $_" -Level "ERROR" }
}

<#
.SYNOPSIS
    Uygulanan tweak'lerin orijinal değerlerini içeren bir geri alma (undo) betiği oluşturur. (ONARILDI v4)
#>
function Generate-UndoScript {
    param([string]$Category)
    $undoActions = @()
    $jsonPath = $Global:JsonSettingsFile
    if (-not (Test-Path $jsonPath)) { Add-Log "JSON dosyası bulunamadı: $jsonPath" -Level "ERROR"; return $null }

    Add-Log "Geri alma betiği oluşturuluyor: $Category" -Level "ACTION"

    try {
        $config = Get-Content -Path $jsonPath -Raw -Encoding utf8 | ConvertFrom-Json
        $tweaks = $config.PSObject.Properties[$Category].Value
        if (-not $tweaks) { return $null }

        foreach ($tweak in $tweaks) {
            if ($tweak.Action -ne "Set") { continue }
            
            try {
                # ONARIM: Önce anahtarın varlığını kontrol et
                if (Test-Path -LiteralPath $tweak.Path) {
                    $originalProperty = Get-ItemProperty -LiteralPath $tweak.Path -Name $tweak.Name -ErrorAction SilentlyContinue
                    if ($null -ne $originalProperty) {
                        $originalValue = $originalProperty.($tweak.Name)
                        $valueKind = (Get-Item -LiteralPath $tweak.Path).GetValueKind($tweak.Name).ToString()
                        $undoActions += @{ Action = "Set"; Path = $tweak.Path; Name = $tweak.Name; Value = $originalValue; Type = $valueKind }
                    } else {
                        $undoActions += @{ Action = "RemoveValue"; Path = $tweak.Path; Name = $tweak.Name }
                    }
                } else {
                    $undoActions += @{ Action = "RemoveValue"; Path = $tweak.Path; Name = $tweak.Name }
                }
            } catch {
                Add-Log "Geri alma bilgisi oluşturulurken hata ($($tweak.Path)\$($tweak.Name)): $_" -Level "WARN"
                # Hata durumunda bile devam et, geri alma eylemini 'sil' olarak ekle.
                $undoActions += @{ Action = "RemoveValue"; Path = $tweak.Path; Name = $tweak.Name }
            }
        }

        if ($Global:TempUndoServiceActions.Count -gt 0) {
            $undoActions += $Global:TempUndoServiceActions
            $Global:TempUndoServiceActions = @()
        }

    } catch { Add-Log "Geri alma betiği oluşturulurken JSON işleme hatası: $_" -Level "ERROR"; return $null }

    if ($undoActions.Count -gt 0) {
        $undoFileName = "Undo-$Category-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').json"
        $undoFilePath = Join-Path $Global:UndoFolderPath $undoFileName
        $undoActions | ConvertTo-Json -Depth 5 | Out-File -FilePath $undoFilePath -Encoding utf8
        Add-Log "Geri alma betiği oluşturuldu: $undoFilePath" -Level "SUCCESS"
        return $undoFilePath
    }
    Add-Log "Geri alınacak bir ayar değişikliği bulunamadı: $Category" -Level "INFO"
    return $null
}


function Apply-RegistryTweaksFromFile {
    param([string]$JsonPath, [string]$Category)
    if (-not (Test-Path $JsonPath)) { Add-Log "JSON dosyası bulunamadı: $JsonPath" -Level "ERROR"; return $false }

    Add-Log "Ayarlar uygulanıyor: $JsonPath -> $Category" -Level "ACTION"

    try {
        $config = Get-Content -Path $JsonPath -Raw -Encoding utf8 | ConvertFrom-Json
        $actionsToApply = if ($Category) { $config.PSObject.Properties[$Category].Value } else { $config }
        if (-not $actionsToApply) { return $false }

        foreach ($action in $actionsToApply) {
            switch ($action.Action) {
                "Set" { Set-RegistryValue -Path $action.Path -Name $action.Name -Value $action.Value -Type $action.Type }
                "RemoveKey" { Remove-RegistryKey -Path $action.Path }
                "RemoveValue" { Remove-RegistryKey -Path $action.Path -Name $action.Name }
            }
        }
        return $true
    } catch { Add-Log "JSON işlenirken hata oluştu: $_" -Level "ERROR"; return $false }
}

function Generate-AndApplyTweaks {
    param([string]$Category)

    Add-Log "Merkezi Tweak işlemi başlatılıyor: Kategori '$Category'" -Level "ACTION"
    $undoFilePath = Generate-UndoScript -Category $Category
    if ($undoFilePath) {
        Add-Log "Geri alma dosyası başarıyla oluşturuldu: $undoFilePath" -Level "INFO"
    }
    $jsonPath = $Global:JsonSettingsFile
    if (-not (Apply-RegistryTweaksFromFile -JsonPath $jsonPath -Category $Category)) {
        Add-Log "Tweak'ler uygulanırken bir hata oluştu: Kategori '$Category'" -Level "ERROR"
    } else {
        Add-Log "Tweak'ler başarıyla uygulandı: Kategori '$Category'" -Level "SUCCESS"
    }
}

# WinFastProjesi\Modules\UtilityFunctions.ps1 dosyasına eklenecek/güncellenecek fonksiyonlar

<#
.SYNOPSIS
    Belirtilen JSON dosyasından uygulamaları okur ve Applications anahtarının altındaki diziyi döndürür.
.PARAMETER JsonPath
    Okunacak JSON dosyasının tam yolu.
#>
function Get-WinFastApplicationsJson {
    param(
        [string]$JsonPath
    )

    Add-Log "JSON dosyası okunuyor: $JsonPath" -Level "INFO"

    if (-not (Test-Path $JsonPath)) {
        Add-Log "HATA: JSON dosyası bulunamadı. Boş bir liste döndürülüyor: $JsonPath" -Level "ERROR"
        Write-Host "HATA: Uygulama listesi JSON dosyası bulunamadı: '$JsonPath'" -ForegroundColor Red
        return @() # Dosya yoksa boş bir dizi döndür
    }

    try {
        $content = Get-Content -Path $JsonPath -Raw -Encoding utf8
        
        # İçerik boşsa veya sadece boşluksa
        if ([string]::IsNullOrWhiteSpace($content)) {
            Add-Log "UYARI: JSON dosyası boş veya sadece boşluk karakterleri içeriyor. Boş liste döndürülüyor: $JsonPath" -Level "WARNING"
            Write-Host "UYARI: Uygulama listesi JSON dosyası boş." -ForegroundColor Yellow
            return @()
        }

        $jsonObj = $content | ConvertFrom-Json -ErrorAction Stop # Hata olursa catch bloğuna düş

        # Eğer okunan obje doğrudan bir dizi ise (yani JSON [ ile başlıyorsa)
        if ($jsonObj -is [System.Array]) {
            Add-Log "BİLGİ: JSON dosyası kök seviyesinde bir dizi olarak okundu. Doğrudan dizi döndürülüyor." -Level "INFO"
            return $jsonObj
        }
        # Eğer okunan obje bir hash tablo veya nesne ise ve içinde 'Applications' anahtarı varsa
        elseif ($jsonObj -is [System.Object] -and $jsonObj.PSObject.Properties.Name -contains "Applications" -and $jsonObj.Applications -is [System.Array]) {
            Add-Log "BİLGİ: JSON dosyası 'Applications' anahtarı altında bir dizi olarak okundu." -Level "INFO"
            return $jsonObj.Applications
        }
        # Beklenmeyen başka bir format ise
        else {
            Add-Log "HATA: JSON dosyası beklenen formatta değil ('Applications' anahtarı altında dizi veya kök dizi). Boş liste döndürülüyor: $JsonPath - Okunan obje türü: $($jsonObj.GetType().Name)" -Level "ERROR"
            Write-Host "HATA: Uygulama listesi JSON dosyası beklenen formatta değil." -ForegroundColor Red
            return @()
        }
    } catch {
        Add-Log "KRİTİK HATA: JSON dosyası okunamadı veya bozuk. $($_.Exception.Message). Boş bir liste döndürülüyor: $JsonPath" -Level "ERROR"
        Write-Host "KRİTİK HATA: Uygulama listesi JSON dosyası işlenirken hata oluştu: $($_.Exception.Message)" -ForegroundColor Red
        return @() # Hata durumunda boş bir dizi döndür
    }
}

<#
.SYNOPSIS
    Belirtilen uygulama listesini Applications anahtarının altında JSON dosyasına yazar.
.PARAMETER AppsList
    Yazılacak uygulama objelerinin listesi (dizi).
.PARAMETER JsonPath
    Yazılacak JSON dosyasının tam yolu.
#>
function Set-WinFastApplicationsJson {
    param(
        [array]$AppsList,
        [string]$JsonPath
    )
    try {
        # 'Applications' kök anahtarı altında JSON'a dönüştür ve yaz
        @{ Applications = $AppsList } | ConvertTo-Json -Depth 3 -Compress | Set-Content -Path $JsonPath -Encoding utf8
        Add-Log "Uygulama listesi JSON dosyasına başarıyla kaydedildi: $JsonPath" -Level "SUCCESS"
        return $true
    } catch {
        Add-Log "HATA: Uygulama listesi JSON dosyasına kaydedilemedi: $JsonPath - Hata: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "UYARI: Uygulama listesi kaydedilemedi! Bir sorun oluştu." -ForegroundColor Yellow
        return $false
    }
}