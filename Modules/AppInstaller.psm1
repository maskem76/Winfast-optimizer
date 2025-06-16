# WinFastProjesi\Modules\AppInstaller.psm1
# =====================================================================
#             BÖLÜM 3: UYGULAMA YÜKLEYİCİ (NİHAİ HİBRİT SİSTEM)
# =====================================================================

# Start-AppInstallation fonksiyonu Invoke-AppInstaller'ın dışında tanımlanacak
# Global yolları kullanacak

<#
.SYNOPSIS
    Uygulama kurulumunu başlatan yardımcı fonksiyon.
    Bu fonksiyon, Invoke-AppInstaller'ın dışında tanımlanmıştır ve global değişkenleri kullanır.
.PARAMETER appsToInstall
    Kurulacak uygulama objelerinin listesi.
#>
function Start-AppInstallation {
    param($appsToInstall)
    foreach ($app in $appsToInstall) {
        Write-Host "`nKuruluyor: '$($app.AppName)' (Kaynak: $($app.Source))..." -ForegroundColor Green
        Add-Log "Kurulum başlatılıyor: $($app.AppName) (Kaynak: $($app.Source))" -Level "ACTION"

        try {
            if ($app.Source -eq "local") {
                $installerFile = Join-Path $global:WinFastAppInstallerInstallersPath $app.FileName 
                
                if (-not (Test-Path $installerFile)) {
                    Write-Host "HATA: Yerel kurulum dosyası bulunamadı: '$installerFile'" -ForegroundColor Red
                    Add-Log "HATA: Yerel kurulum dosyası bulunamadı: '$installerFile'" -Level "ERROR"
                    continue 
                }

                if ($app.FileName.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-Host "UYARI: ZIP dosyaları doğrudan katılımsız kurulamaz. Lütfen içeriğini manuel olarak çıkarın ve kurun." -ForegroundColor Yellow
                    Add-Log "UYARI: ZIP dosyası seçildi, manuel işlem gerekli: $($app.AppName) ($installerFile)" -Level "WARNING"
                    continue 
                }

                if ($app.IsAutoFound -or [string]::IsNullOrWhiteSpace($app.SilentArgs)) {
                    Add-Log "Otomatik bulunan veya parametreleri eksik yerel kurulum: '$($app.AppName)'. Yaygın parametreler deneniyor..." -Level "WARNING"
                    
                    $commonSilentArgs = @("/S", "/quiet", "-s", "/qn", "/passive", "/install") 
                    $installedSuccessfully = $false

                    foreach ($args in $commonSilentArgs) {
                        Write-Host "  -> Deneniyor: '$args'" -ForegroundColor DarkYellow
                        try {
                            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                            $processInfo.FileName = $installerFile
                            $processInfo.Arguments = $args
                            $processInfo.UseShellExecute = $false 
                            $processInfo.RedirectStandardOutput = $true 
                            $processInfo.RedirectStandardError = $true 
                            $processInfo.CreateNoWindow = $true 

                            $process = New-Object System.Diagnostics.Process
                            $process.StartInfo = $processInfo

                            $process.Start() | Out-Null
                            $process.WaitForExit()

                            $output = $process.StandardOutput.ReadToEnd()
                            $errorOutput = $process.StandardError.ReadToEnd()

                            if ($process.ExitCode -eq 0) {
                                Add-Log "'$($app.AppName)' kurulumu başarıyla tamamlandı (Parametre: '$args'). Çıktı: $output $errorOutput" -Level "SUCCESS"
                                $installedSuccessfully = true
                                break
                            } else {
                                Add-Log "'$($app.AppName)' kurulumu '$args' ile başarısız (Çıkış Kodu: $($process.ExitCode)). Çıktı: $output $errorOutput" -Level "WARNING"
                            }
                        } catch {
                            Add-Log "'$($app.AppName)' kurulumu '$args' ile başlatılamadı: $($_.Exception.Message)" -Level "ERROR"
                        }
                    }

                    if (-not $installedSuccessfully) {
                        Write-Host "HATA: '$($app.AppName)' için otomatik katılımsız kurulum denemeleri başarısız oldu veya desteklenmiyor olabilir. Manuel kurulum gerekebilir." -ForegroundColor Red
                        Add-Log "HATA: '$($app.AppName)' için otomatik katılımsız kurulum denemeleri başarısız oldu." -Level "ERROR"
                    }

                } else { 
                    Add-Log "Yerel kurulum (belirtilen parametrelerle): $installerFile $($app.SilentArgs)" -Level "ACTION"
                    try {
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = $installerFile
                        $processInfo.Arguments = $app.SilentArgs
                        $processInfo.UseShellExecute = $false
                        $processInfo.RedirectStandardOutput = $true
                        $processInfo.RedirectStandardError = true
                        $processInfo.CreateNoWindow = $true

                        $process = New-Object System.Diagnostics.Process
                        $process.StartInfo = $processInfo

                        $process.Start() | Out-Null
                        $process.WaitForExit()

                        $output = $process.StandardOutput.ReadToEnd()
                        $errorOutput = $process.StandardError.ReadToEnd()

                        if ($process.ExitCode -eq 0) { 
                            Add-Log "'$($app.AppName)' kurulumu başarıyla tamamlandı. Çıktı: $output $errorOutput" -Level "SUCCESS" 
                        } else { 
                            Add-Log "UYARI: '$($app.AppName)' kurulumu bir hata koduyla tamamlandı: $($process.ExitCode). Çıktı: $output $errorOutput" -Level "WARNING" 
                        }
                    } catch {
                        Add-Log "HATA: '$($app.AppName)' manuel katılımsız kurulumu başlatılamadı: $($_.Exception.Message)" -Level "ERROR"
                        Write-Host "HATA: '$($app.AppName)' kurulumu başlatılamadı: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

            } else { # winget uygulamaları
                Add-Log "Winget kurulumu başlatılıyor: $($app.PackageId)" -Level "ACTION"
                $arguments = "install -e --id `"$($app.PackageId)`" --silent --accept-package-agreements --accept-source-agreements --source winget"
                
                try {
                    $wingetOutput = & winget $arguments *>&1 
                    
                    if ($LASTEXITCODE -eq 0) {
                        Add-Log "'$($app.AppName)' kurulumu başarıyla tamamlandı (Winget). Çıktı: $wingetOutput" -Level "SUCCESS"
                    } elseif ($LASTEXITCODE -eq 1603) { 
                        Write-Host "UYARI: '$($app.AppName)' kurulumu başarısız oldu (Winget Hata Kodu: $($LASTEXITCODE)). Yükleyici hatası veya zaten yüklü olabilir." -ForegroundColor Yellow
                        Add-Log "UYARI: '$($app.AppName)' kurulumu başarısız (Winget - ExitCode: $($LASTEXITCODE)). Çıktı: $wingetOutput" -Level "WARNING"
                    } else {
                        Write-Host "UYARI: '$($app.AppName)' kurulumu bir hata koduyla tamamlandı (Winget Hata Kodu: $($LASTEXITCODE))." -ForegroundColor Yellow
                        Add-Log "UYARI: '$($app.AppName)' kurulumu başarısız (Winget - ExitCode: $($LASTEXITCODE)). Çıktı: $wingetOutput" -Level "WARNING"
                    }
                } catch {
                    Write-Host "HATA: '$($app.AppName)' için Winget işlemi başlatılamadı veya bir sorun oluştu: $($_.Exception.Message)" -ForegroundColor Red
                    Add-Log "HATA: '$($app.AppName)' için Winget işlemi başlatılamadı: $($_.Exception.Message)" -Level "ERROR"
                }
            }
        } catch { 
            Write-Host "HATA: '$($app.AppName)' kurulumu sırasında beklenmedik bir hata oluştu: $($_.Exception.Message)" -ForegroundColor Red 
            Add-Log "HATA: '$($app.AppName)' kurulumu sırasında beklenmedik hata: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    Write-Host "`nSeçilen tüm kurulum işlemleri tamamlandı." -ForegroundColor Green; Start-Sleep 3
}

<#
.SYNOPSIS
    WinFast Hibrit Uygulama Yükleyici ana menü fonksiyonu.
    Uygulama listesini okur, tarar ve kullanıcıya seçim sunar.
.PARAMETER ProjectRootPath
    WinFast ana betiğinin (WinFast.ps1) bulunduğu kök dizinin yolu.
#>
function Invoke-AppInstaller {
    param(
        [string]$ProjectRootPath # WinFast.ps1'den gelen kök dizin yolu
    )

    Add-Log "Hibrit Uygulama Yükleyici modülü başlatıldı." -Level "ACTION"
    
    # Global kapsamdaki yolları güncelle
    $global:WinFastAppInstallerBasePath = $ProjectRootPath
    $global:WinFastAppInstallerConfigFile = Join-Path $global:WinFastAppInstallerBasePath "Data\Applications.json"
    $global:WinFastAppInstallerInstallersPath = Join-Path $global:WinFastAppInstallerBasePath "Installers"

    Add-Log "Proje Kök Dizini (parametre): $ProjectRootPath" -Level "DEBUG"
    Add-Log "Applications.json Yolu: $global:WinFastAppInstallerConfigFile" -Level "DEBUG"
    Add-Log "Installers Klasör Yolu: $global:WinFastAppInstallerInstallersPath" -Level "DEBUG"

    if (-not (Test-Path $global:WinFastAppInstallerInstallersPath)) { 
        New-Item -Path $global:WinFastAppInstallerInstallersPath -ItemType Directory -Force | Out-Null 
        Add-Log "Installers klasörü oluşturuldu: $global:WinFastAppInstallerInstallersPath" -Level "INFO"
    }
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        Write-Host "HATA: 'winget' bulunamadı. Winget uygulamaları yüklenemez." -ForegroundColor Red; 
        Add-Log "HATA: 'winget' bulunamadı. Winget uygulamaları yüklenemeyecek." -Level "ERROR"; 
    }

    Add-Log "Applications.json okunmaya çalışılıyor..." -Level "INFO"
    # Get-WinFastJsonList fonksiyonunu kullanırken RootKey'i belirtiyoruz
    $allApps = Get-WinFastJsonList -JsonPath $global:WinFastAppInstallerConfigFile -RootKey "Applications"

    if ($allApps -eq $null) {
        $allApps = @() 
        Add-Log "Get-WinFastJsonList null döndürdü, liste boş olarak ayarlandı." -Level "WARNING"
    }
    
    Add-Log "Applications.json okuma tamamlandı. JSON'dan okunan başlangıç uygulama sayısı: $($allApps.Count)" -Level "INFO"

    Add-Log "Installers klasörü taranıyor ve yeni yerel uygulamalar aranıyor: $global:WinFastAppInstallerInstallersPath" -Level "INFO"
    $existingLocalFileNames = $allApps | Where-Object { $_.Source -eq 'local' } | Select-Object -ExpandProperty FileName

    $newLocalAppsCount = 0
    Get-ChildItem -Path $global:WinFastAppInstallerInstallersPath -File -Include "*.exe", "*.msi", "*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notin $existingLocalFileNames) { 
            $appName = $_.BaseName
            $silentArgs = ""
            if ($_.Extension -eq ".zip") {
                $appName += " (ZIP)" 
            } else {
                $silentArgs = "/S" 
            }

            $newEntry = [PSCustomObject]@{
                AppName     = $appName; Source = "local"; FileName = $_.Name; SilentArgs = $silentArgs;
                Category    = "Katılımsız"; Recommended = $false; Available = true; IsAutoFound = true;
            }
            $allApps += $newEntry
            $newLocalAppsCount++
            Add-Log "Yeni yerel uygulama bulundu ve listeye eklendi: $($newEntry.AppName) ($($newEntry.FileName))" -Level "INFO"
        }
    }
    Add-Log "Yerel uygulamalar listesi güncellendi. Yeni eklenen yerel uygulama: $newLocalAppsCount. Toplam yerel uygulama: $($allApps | Where-Object {$_.Source -eq 'local'}).Count" -Level "INFO"

    $allApps | Where-Object { $_.Source -eq 'winget' } | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name "Available" -Value $true -Force 
    }
    Add-Log "Winget uygulamalarının durumu kontrol edildi. Toplam Winget uygulama: $($allApps | Where-Object {$_.Source -eq 'winget'}).Count" -Level "INFO"

    if ($allApps.Count -gt 0) { 
        # Set-WinFastJsonList fonksiyonunu kullanırken RootKey'i belirtiyoruz
        Set-WinFastJsonList -DataList $allApps -JsonPath $global:WinFastAppInstallerConfigFile -RootKey "Applications"
    } else {
        Add-Log "UYARI: Uygulama listesi boş olduğu için Applications.json'a kaydedilmedi." -Level "WARNING"
    }

    # Ana menüye geçiş döngüsü
      while ($true) {
        cls
        Write-Host "--- WinFast Hibrit Uygulama Yükleyici ---" -ForegroundColor Yellow
        Write-Host "Kuruluma hazır uygulamalar:"

        # Sadece Available olanları listele ve AppName'e göre sırala
        $availableApps = $allApps | Where-Object { $_.Available } | Sort-Object AppName

        # >>>>>> BU KOD BLOĞUNU DİKKATLE KOPYALA VE ESKİSİYLE DEĞİŞTİR <<<<<<
        # Hata ayıklama: $availableApps'in içeriğini ve tipini logla
        Add-Log "DEBUG: availableApps listesi oluşturuldu. Eleman sayısı: $($availableApps.Count)" -Level "DEBUG"
        if ($availableApps.Count -gt 0) {
            Add-Log "DEBUG: availableApps listesinin tipi: $($availableApps.GetType().FullName)" -Level "DEBUG"
            Add-Log "DEBUG: availableApps listesindeki ilk elemanın tipi: $($availableApps[0].GetType().FullName)" -Level "DEBUG"
            Add-Log "DEBUG: availableApps listesinin içeriği (JSON formatında loglanıyor):" -Level "DEBUG"
            # $availableApps içeriğini JSON olarak logla, böylece tüm özelliklerini görebiliriz
            $availableApps | ConvertTo-Json -Depth 3 | Out-String | Add-Log -Level "DEBUG" 
        } else {
            Write-Host "`nKRİTİK HATA: Kuruluma uygun hiçbir uygulama bulunamadı. Lütfen log dosyasını kontrol edin." -ForegroundColor Red
            Add-Log "KRİTİK HATA: availableApps listesi boş geldi. allApps.Count: $($allApps.Count)." -Level "CRITICAL_ERROR"
            Add-Log "DEBUG: allApps değişkeninin içeriği (listeleme öncesi):" -Level "DEBUG"
            $allApps | Out-String | Add-Log -Level "DEBUG" 
            Start-Sleep 5 
            return 
        }
        # >>>>>> YUKARIDAKİ KOD BLOĞUNU KOPYALAMAYI BURADA BİTİR <<<<<<
        
        for ($i = 0; $i -lt $availableApps.Count; $i++) {
            $app = $availableApps[$i]
            $sourceTagColor = if($app.Source -eq "local") {"Green"} else {"Cyan"}
            Write-Host (" {0,2} - {1}" -f ($i + 1), "$($app.AppName) [$($app.Source)]") -ForegroundColor $sourceTagColor
        }
        
        Write-Host "`nT - Tümünü Kur" -ForegroundColor Magenta
        Write-Host "X - Ana Menüye Dön" -ForegroundColor Red
        
        $choice = Read-Host "`nKurmak istediğiniz uygulamaların numarasını virgülle ayırarak girin (örn: 1,3,5)"

        if ($choice.ToUpper().Trim() -eq 'X') { 
            Add-Log "Kullanıcı Uygulama Yükleyici menüsünden çıktı." -Level "INFO"
            break 
        }

        $appsToInstall = @() 
        if ($choice.ToUpper().Trim() -eq 'T') {
            $appsToInstall = $availableApps | Select-Object * Add-Log "Kullanıcı tüm uygulamaları kurmayı seçti. Toplam $($appsToInstall.Count) uygulama kurulacak." -Level "INFO"
        } else {
            $indices = $choice -split ',' | ForEach-Object { 
                $trimmedChoice = $_.Trim() 
                if ($trimmedChoice -match '^\d+$') {
                    [int]$trimmedChoice - 1 
                } else {
                    Add-Log "Geçersiz giriş formatı (numara değil) atlandı: '$trimmedChoice'" -Level "WARNING"
                }
            } | Where-Object { $_ -ne $null } 

            foreach($index in $indices){
                if ($index -ge 0 -and $index -lt $availableApps.Count) {
                    $appsToInstall += $availableApps[$index] | Select-Object * Add-Log "Kurulacak uygulamaya eklendi: $($availableApps[$index].AppName) (Menü İndeksi: $($index + 1))" -Level "DEBUG"
                } else {
                    Write-Host "UYARI: Geçersiz uygulama numarası atlandı: $($index + 1). Lütfen listedeki geçerli bir numara girin." -ForegroundColor Yellow 
                    Add-Log "UYARI: Geçersiz veya liste dışı uygulama numarası atlandı: $($index + 1). Kullanıcı girişi: '$choice'" -Level "WARNING"
                }
            }
        }
        
        if ($appsToInstall.Count -gt 0) { 
            Write-Host "`nSeçilen $($appsToInstall.Count) uygulama kuruluma hazırlanıyor..." -ForegroundColor Green
            Add-Log "Seçilen $($appsToInstall.Count) uygulama için Start-AppInstallation çağrıldı." -Level "INFO"
            Start-AppInstallation -appsToInstall $appsToInstall 
        } else {
            Write-Host "`nGEÇERSİZ SEÇİM VEYA UYGULAMA BULUNAMADI. Lütfen listeden geçerli numaralar girin veya 'T' ya da 'X' kullanın." -ForegroundColor Red
            Add-Log "Geçersiz seçim: Hiçbir geçerli uygulama seçilmedi. Kullanıcı girişi: '$choice'" -Level "WARNING"
            Start-Sleep 3
        }
    }