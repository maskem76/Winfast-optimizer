# =====================================================================
#             BÖLÜM 1: TEMEL SİSTEM ARAÇLARI
# =====================================================================

<#
.SYNOPSIS
    Yeni bir sistem geri yükleme noktası oluşturur.
#>
function New-SystemRestorePoint {
    if (Confirm-Action -Prompt "Yeni bir Sistem Geri Yükleme noktası oluşturulacak. Bu işlem birkaç dakika sürebilir.") {
        Add-Log "Sistem geri yükleme noktası oluşturuluyor..." -Level "ACTION"
        try {
            Checkpoint-Computer -Description "WinFast Script Öncesi - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Add-Log "Sistem geri yükleme noktası başarıyla oluşturuldu." -Level "SUCCESS"
        } catch {
            Add-Log "Geri yükleme noktası oluşturulamadı: $_" -Level "ERROR"
            Write-Host "HATA: Sistem geri yükleme noktası oluşturulamadı. Sistem Korumasının açık olduğundan veya ilgili hizmetlerin çalıştığından emin olun." -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Kayıt Defteri'nin tam yedeğini alır.
#>
function Backup-Registry {
    if (Confirm-Action -Prompt "Kayıt Defteri'nin yedeği 'C:\RegistryBackups' altına alınacak.") {
        $backupPath = "C:\RegistryBackups\RegBackup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        Add-Log "Yedekleme başlatıldı: $backupPath" -Level "ACTION"
        $hives = @{ "HKLM" = "HKEY_LOCAL_MACHINE"; "HKCU" = "HKEY_CURRENT_USER"; "HKU" = "HKEY_USERS"; "HKCR" = "HKEY_CLASSES_ROOT" }
        foreach ($hive in $hives.GetEnumerator()) {
            Add-Log "'$($hive.Value)' yedekleniyor..." -Level "INFO"
            $arguments = "export `"$($hive.Key)`" `"$backupPath\$($hive.Value).reg`" /y"
            if (-not (Invoke-AdminCommand "reg.exe" $arguments)) {
                Add-Log "'$($hive.Value)' yedeklemesi BAŞARISIZ OLDU." -Level "ERROR"
            } else {
                Add-Log "'$($hive.Value)' başarıyla yedeklendi." -Level "SUCCESS"
            }
        }
        Add-Log "Yedekleme tamamlandı."
        Invoke-Item $backupPath
    }
}

<#
.SYNOPSIS
    Daha önce yapılan değişiklikleri geri alma betiği dosyasından geri yükler.
#>
function Restore-TweaksFromUndoFile {
    while ($true) {
        cls
        Write-Host "--- Geri Alma Menüsü ---" -ForegroundColor Yellow
        Write-Host "1. Betik Tarafından Yapılan Değişiklikleri Geri Al (JSON Dosyaları)" -ForegroundColor Cyan
        Write-Host "2. Kayıt Defteri Temizleyici Yedeklerini Geri Yükle (.REG Dosyaları)" -ForegroundColor Cyan
        Write-Host "X. Ana Menüye Dön" -ForegroundColor Red

        $subChoice = Read-Host "`nLütfen yapmak istediğiniz işlemi seçin"

        switch ($subChoice.ToUpper()) {
            "1" {
                Add-Log "Betik değişikliklerini geri alma seçeneği belirlendi." -Level "ACTION"
                $undoFiles = Get-ChildItem -Path $Global:UndoFolderPath -Filter "Undo-*.json" -ErrorAction SilentlyContinue
                if ($undoFiles.Count -eq 0) { Write-Host "Geri alınacak betik bulunamadı ($Global:UndoFolderPath)." -ForegroundColor Yellow; Start-Sleep 2; continue }
                $sortedUndoFiles = $undoFiles | Sort-Object -Property LastWriteTime -Descending
                Write-Host "Bulunan Geri Alma Betikleri (En Yeniden En Eskiye):" -ForegroundColor Yellow
                for ($i = 0; $i -lt $sortedUndoFiles.Count; $i++) { Write-Host "$($i + 1). $($sortedUndoFiles[$i].Name) (Tarih: $($sortedUndoFiles[$i].LastWriteTime.ToString('g')))" -ForegroundColor DarkCyan }
                $choice = Read-Host "`nHangi değişikliği geri almak istiyorsunuz? (Numara girin)"
                if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $sortedUndoFiles.Count) {
                    $fileToRestore = $sortedUndoFiles[[int]$choice - 1]
                    if (Confirm-Action -Prompt "'$($fileToRestore.Name)' dosyasındaki değişiklikler geri yüklenecek.") {
                        Apply-RegistryTweaksFromFile -JsonPath $fileToRestore.FullName -Category $null
                        Write-Host "`nİşlem tamamlandı. Ana menüye dönmek için bir tuşa basın..." -ForegroundColor DarkGray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                } else { Write-Host "Geçersiz seçim." -ForegroundColor Red; Start-Sleep 2 }
            }
            "2" {
                Add-Log "Kayıt defteri yedeğini geri yükleme seçildi." -Level "ACTION"
                $cleanupBackupPath = "C:\RegistryBackups\Cleanup"
                $regBackupFiles = Get-ChildItem -Path $cleanupBackupPath -Filter "*.reg" -ErrorAction SilentlyContinue
                if ($regBackupFiles.Count -eq 0) { Write-Host "Geri yüklenecek .reg yedeği bulunamadı." -ForegroundColor Yellow; Start-Sleep 2; continue }
                $sortedRegBackupFiles = $regBackupFiles | Sort-Object -Property LastWriteTime -Descending
                Write-Host "Bulunan Kayıt Defteri Yedekleri:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $sortedRegBackupFiles.Count; $i++) { Write-Host "$($i + 1). $($sortedRegBackupFiles[$i].Name) (Tarih: $($sortedRegBackupFiles[$i].LastWriteTime.ToString('g')))" -ForegroundColor DarkCyan }
                $choice = Read-Host "`nHangi .reg dosyasını geri yüklemek istiyorsunuz?"
                if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $sortedRegBackupFiles.Count) {
                    $fileToRestore = $sortedRegBackupFiles[[int]$choice - 1]
                    if (Confirm-Action -Prompt "'$($fileToRestore.Name)' NSudo ile yüklenecek. RİSKLİDİR!" -Challenge "ONAYLA") {
                        $nsudoPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules\NSudo.exe"
                        if (-not (Test-Path $nsudoPath)) { Add-Log "HATA: NSudo.exe bulunamadı!" -Level "ERROR"; Write-Host "HATA: NSudo.exe bulunamadı." -ForegroundColor Red; Start-Sleep 3; continue }
                        $arguments = "-U:T -P:E -Wait `"$env:SystemRoot\System32\reg.exe`" import `"$($fileToRestore.FullName)`""
                        if (Invoke-AdminCommand -Command $nsudoPath -Arguments $arguments) { Write-Host "`nYedek başarıyla geri yüklendi." -ForegroundColor Green }
                        else { Write-Host "`nHATA: Yedek geri yüklenemedi." -ForegroundColor Red }
                        Start-Sleep 3
                    }
                } else { Write-Host "Geçersiz seçim." -ForegroundColor Red; Start-Sleep 2 }
            }
            "X" { return }
            default { Add-Log "Geçersiz alt menü seçimi: $subChoice" -Level "WARN" }
        }
    }
}

# =====================================================================
#             BÖLÜM 2: YEDEKLEME VE ISO OLUŞTURMA
# =====================================================================

<#
.SYNOPSIS
    Kullanıcıya 'Hızlı' (wimlib-imagex) ve 'Güvenli' (WinPE/DISM) yedekleme seçenekleri sunan ana menüyü başlatır.
#>
function Invoke-WindowsBackup {
    while ($true) {
        cls
        Write-Host "--- Kurulu Windows'un Görüntüsünü Alma ---" -ForegroundColor Yellow
        Write-Host "1. Hızlı Yedekleme (wimlib-imagex ile)" -ForegroundColor Cyan
        Write-Host "   - Çalışan sistem üzerinden, yeniden başlatmadan yedek alır."
        Write-Host "   - [ÇOĞU KULLANICI İÇİN ÖNERİLİR]"
        Write-Host
        Write-Host "2. Güvenli Yedekleme (WinPE ile Soğuk Yedekleme)" -ForegroundColor Green
        Write-Host "   - En güvenilir ve kararlı yöntemdir."
        Write-Host "   - Bilgisayarı WinPE USB'sinden başlatmanızı gerektirir."
        Write-Host "   - [İLERİ DÜZEY KULLANICILAR İÇİN]"
        Write-Host
        Write-Host "X. Ana Menüye Dön" -ForegroundColor Red
        $choice = Read-Host "`nSeçiminiz (1, 2 veya X)"
        switch ($choice.ToUpper()) {
            "1" { Start-HotBackupWithWimlib }
            "2" { Start-ColdBackupGuideWithDISM }
            "X" { return }
            default { Add-Log "Geçersiz yedekleme yöntemi seçimi: $choice" -Level "WARN" }
        }
        if ($choice -in "1", "2") {
             Write-Host "`nİşlem tamamlandı. Menüye dönmek için bir tuşa basın..." -ForegroundColor DarkGray
             $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

<#
.SYNOPSIS
    Çalışan sistem üzerinden wimlib-imagex kullanarak bir WIM/ESD yedeği alır.
#>
function Start-HotBackupWithWimlib {
    cls; Add-Log "Hızlı Yedekleme (wimlib-imagex ile) başlatıldı." -Level "ACTION"; Write-Host "--- HIZLI YEDEKLEME (wimlib-imagex ile) ---" -ForegroundColor Green
    $wimlibPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) "Modules\wimlib-imagex.exe"
    if (-not (Test-Path -Path $wimlibPath)) { Add-Log "HATA: wimlib-imagex.exe bulunamadı." -Level "ERROR"; Write-Host "HATA: 'wimlib-imagex.exe' betiğin 'Modules' klasöründe bulunamadı." -ForegroundColor Red; Start-Sleep 5; return }
    $backupPath = Read-Host "Yedek dosyasının kaydedileceği klasör yolunu girin (Örn: D:\Yedekler)"
    if (-not (Test-Path -Path $backupPath -PathType Container)) {
        $create = Read-Host "`n'$backupPath' klasörü bulunamadı. Oluşturulsun mu? (E/H)" -ForegroundColor Yellow
        if ($create -match "^[Ee]$") { try { New-Item -Path $backupPath -ItemType Directory -Force -ErrorAction Stop | Out-Null; Add-Log "Yedekleme klasörü oluşturuldu: $backupPath" -Level "SUCCESS"; Write-Host "'$backupPath' oluşturuldu." -ForegroundColor Green } catch { Add-Log "Klasör oluşturulamadı: $($_.Exception.Message)" -Level "ERROR"; Write-Host "HATA: Klasör oluşturulamadı." -ForegroundColor Red; return } } 
        else { Add-Log "Kullanıcı klasör oluşturmayı reddetti." -Level "WARN"; Write-Host "İşlem iptal edildi." -ForegroundColor Red; return }
    }
    $imageTypeInput = Read-Host "Yedek türünü seçin (WIM veya ESD)"; $imageType = $imageTypeInput.Replace('ı', 'i').Replace('İ', 'I')
    if ($imageType.ToUpper() -ne "WIM" -and $imageType.ToUpper() -ne "ESD") { Add-Log "Geçersiz imaj türü: $imageTypeInput" -Level "ERROR"; Write-Host "HATA: Lütfen sadece 'WIM' veya 'ESD' girin." -ForegroundColor Red; Start-Sleep 3; return }
    $baseFileName = "SystemBackup_$(Get-Date -Format 'yyyy-MM-dd')"; $fileName = "$baseFileName.$($imageType.ToLower())"; $fullPath = Join-Path -Path $backupPath -ChildPath $fileName; $i = 1
    while (Test-Path $fullPath) { $fileName = "${baseFileName}_${i}.$($imageType.ToLower())"; $fullPath = Join-Path $backupPath $fileName; $i++ }
    Add-Log "Yedekleme dosyası: $fullPath" -Level "INFO"; $compressArg = if ($imageType.ToUpper() -eq "ESD") { "--compress=LZMS" } else { "--compress=LZX" }
    $argumentList = @( "capture", "$($env:SystemDrive)\", $fullPath, "WinFast_Snapshot_Yedek", "--snapshot", $compressArg, "--check")
    Write-Host "`nYedekleme başlatılıyor. Bu işlem uzun sürebilir..." -ForegroundColor Green; Add-Log "wimlib-imagex komutu çalıştırılıyor: $wimlibPath $($argumentList -join ' ')" -Level "ACTION"
    $process = Start-Process -FilePath $wimlibPath -ArgumentList $argumentList -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -eq 0) { Add-Log "Yedekleme başarılı." -Level "SUCCESS"; Write-Host "`n[BAŞARILI] Yedekleme tamamlandı! Dosya: $fullPath" -ForegroundColor Green } 
    else { Add-Log "Yedekleme başarısız. Hata Kodu: $($process.ExitCode)" -Level "ERROR"; Write-Host "`n[HATA] Yedekleme sırasında hata oluştu! Hata Kodu: $($process.ExitCode)" -ForegroundColor Red; if (Test-Path $fullPath) { Remove-Item $fullPath -Force } }
}

<#
.SYNOPSIS
    Kullanıcıya WinPE ve standart DISM komutu ile nasıl yedek alacağı konusunda rehberlik eder.
#>
function Start-ColdBackupGuideWithDISM {
    cls
    Add-Log "Güvenli Yedekleme (Soğuk/DISM) rehberi başlatıldı." -Level "ACTION"
    Write-Host "--- GÜVENLİ YEDEKLEME (WinPE ile Soğuk Yedekleme) ---" -ForegroundColor Green
    Write-Host "Bu yöntem, sizin için standart bir DISM komutu oluşturacaktır."
    Write-Host
    $backupPath = Read-Host "Yedek dosyasının kaydedileceği yolu girin (Örn: D:\Yedekler)"
    $imageTypeInput = Read-Host "Yedek türünü seçin (WIM veya ESD)"
    $imageType = $imageTypeInput.Replace('ı', 'i').Replace('İ', 'I')
    if ($imageType.ToUpper() -ne "WIM" -and $imageType.ToUpper() -ne "ESD") { Add-Log "Geçersiz imaj türü: $imageTypeInput" -Level "ERROR"; Write-Host "HATA: Lütfen sadece 'WIM' veya 'ESD' girin." -ForegroundColor Red; Start-Sleep 3; return }
    $fileName = "SystemBackup_$(Get-Date -Format 'yyyy-MM-dd').$($imageType.ToLower())"
    $fullPath = Join-Path -Path $backupPath -ChildPath $fileName
    $compressArg = if ($imageType.ToUpper() -eq "ESD") { "/Compress:recovery" } else { "/Compress:max" }
    cls
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow; Write-Host "                      HAZIRLANMANIZ GEREKENLER" -ForegroundColor Yellow; Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "1. İçinde Windows PE olan bir USB belleginiz olduğundan emin olun."
    Write-Host "2. Bilgisayarı yeniden başlatın ve bu USB bellekten açın."
    Write-Host "3. Komut satırı (X:\Sources>) geldiğinde, önce disk harflerini 'diskpart' -> 'list volume' komutlarıyla kontrol edin."
    Write-Host "4. Ardından aşağıda sizin için oluşturulan komutu dikkatlice yazın:"
    Write-Host
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Cyan; Write-Host "                         KOPYALANACAK KOMUT (DISM)" -ForegroundColor Cyan; Write-Host "---------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host; Write-Host "dism /capture-image /imagefile:`"$fullPath`" /capturedir:$($env:SystemDrive)\ /name:`"WinFast Guvenli Yedek`" $compressArg /checkintegrity /verify" -ForegroundColor White; Write-Host
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Red
    Write-Host "NOT: Komuttaki '$($env:SystemDrive)\' sizin Windows'unuzun kurulu olduğu sürücüdür. WinPE içinde harf değişebilir (D: olabilir)."
    Write-Host "Aynı şekilde yedek yolu sürücü harfi de değişebilir. Lütfen komutu yazmadan once harfleri doğrulayın!" -ForegroundColor Red
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Red
}

<#
.SYNOPSIS
    Özel bir WIM dosyasını ve bir şablon ISO'yu kullanarak önyüklenebilir bir Windows ISO dosyası oluşturur.
#>
function Invoke-CreateBootableISO {
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    function Write-HostSilent { param([string]$Message, [string]$ForegroundColor = "Gray"); if (-not $Silent) { Write-Host $Message -ForegroundColor $ForegroundColor } }
    cls
    Add-Log "Önyüklenebilir ISO Oluşturma modülü başlatıldı." -Level "ACTION"
    Write-HostSilent "--- Özel Yedekten Önyüklenebilir ISO Oluşturma ---" "Yellow"

    $oscdimgExePath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) "Modules\oscdimg.exe"
    if (-not (Test-Path -Path $oscdimgExePath)) { Add-Log "oscdimg.exe bulunamadı: $oscdimgExePath" -Level "ERROR"; Write-Host "HATA: 'oscdimg.exe' betiğin 'Modules' klasöründe bulunamadı." -ForegroundColor Red; return }

    $customWimPath = Read-Host "Lütfen yedeklediğiniz WIM/ESD dosyasının tam yolunu girin (Örn: D:\Yedekler\SystemBackup.wim)"
    if (-not (Test-Path -Path $customWimPath -PathType Leaf)) { Add-Log "Geçersiz özel WIM yolu: $customWimPath" -Level "ERROR"; Write-Host "HATA: Belirtilen WIM/ESD dosyası bulunamadı." -ForegroundColor Red; return }
    if (-not ($customWimPath -match '\.(w[iı]m|esd)$')) { Add-Log "Geçersiz WIM/ESD uzantısı." -Level "ERROR"; Write-Host "HATA: Geçersiz dosya uzantısı. Sadece .wim veya .esd dosyaları kabul edilir." -ForegroundColor Red; return }

    $templateIsoPath = Read-Host "Lütfen ŞABLON olarak kullanılacak Windows ISO dosyasının tam yolunu girin"
    if (-not (Test-Path -Path $templateIsoPath -PathType Leaf)) { Add-Log "Geçersiz şablon ISO yolu: $templateIsoPath" -Level "ERROR"; Write-Host "HATA: Belirtilen şablon ISO dosyası bulunamadı." -ForegroundColor Red; return }
    if (-not ($templateIsoPath -match '\.iso$')) { Add-Log "Geçersiz ISO uzantısı." -Level "ERROR"; Write-Host "HATA: Geçersiz dosya uzantısı. Sadece .iso dosyaları kabul edilir." -ForegroundColor Red; return }

    $defaultLabel = "WINFAST_" + (Get-Date -Format "yyyyMMdd"); $newIsoLabel = Read-Host "Yeni ISO dosyası için bir CİLT ETİKETİ girin [Varsayılan: $defaultLabel]"; if ([string]::IsNullOrWhiteSpace($newIsoLabel)) { $newIsoLabel = $defaultLabel };
    if ($newIsoLabel -notmatch '^[a-zA-Z0-9_]+$') { Add-Log "Geçersiz karakter ISO etiketi: $newIsoLabel" -Level "ERROR"; Write-Host "HATA: ISO etiketi sadece harf, rakam ve alt çizgi içerebilir." -ForegroundColor Red; return }
    if ($newIsoLabel.Length -gt 32) { Add-Log "ISO Etiketi çok uzun." -Level "ERROR"; Write-Host "HATA: ISO etiketi en fazla 32 karakter olabilir." -ForegroundColor Red; return }
    
    $newIsoPath = Read-Host "Yeni ISO dosyasının kaydedileceği tam yolu ve adı girin (Örn: D:\OzelWin11.iso)"; if (-not ($newIsoPath -match '\.iso$')) { Add-Log "Hedef ISO yolu .iso ile bitmiyor." -Level "ERROR"; Write-Host "HATA: Kayıt yolu bir .iso uzantısı ile bitmelidir." -ForegroundColor Red; return }
    
    try { $requiredSpace = (Get-Item $templateIsoPath).Length * 1.2; $driveInfo = Get-PSDrive -Name (Split-Path -Path $newIsoPath -Qualifier).Trim(':'); if ($driveInfo.Free -lt $requiredSpace) { Add-Log "Yetersiz disk alanı." -Level "ERROR"; Write-Host "HATA: Yetersiz disk alanı. Hedef sürücüde en az $([math]::Round($requiredSpace/1GB,2)) GB boş alan gerekiyor." -ForegroundColor Red; return } } catch { Add-Log "Disk alanı kontrol edilemedi: $($_.Exception.Message)" -Level "WARN"; Write-HostSilent "UYARI: Disk alanı kontrol edilemedi, yine de devam ediliyor." "Yellow" }
    
    $tempWorkingDir = Join-Path -Path $env:TEMP -ChildPath "WinFast_ISO_Temp"; if (Test-Path $tempWorkingDir) { Remove-Item -Path $tempWorkingDir -Recurse -Force }; New-Item -Path $tempWorkingDir -ItemType Directory -Force | Out-Null; Add-Log "Geçici çalışma klasörü oluşturuldu: $tempWorkingDir" -Level "INFO"
    
    $tempConvertedWim = $null
    if ($customWimPath -match '\.esd$') {
        Write-HostSilent "`nESD dosyası taranıyor..." "Cyan"; $wimInfo = dism /Get-WimInfo /WimFile:$customWimPath; $indexCount = ($wimInfo | Where-Object {$_ -match "Index"}).Count; $sourceIndex = 1; if ($indexCount -gt 1) { Write-Host "`nBu ESD dosyasında birden fazla sürüm bulundu:" -ForegroundColor Yellow; $wimInfo | Where-Object {$_ -like "Index :*" -or $_ -like "Name :*"}; $sourceIndex = Read-Host "`nLütfen kullanmak istediğiniz sürümün Index numarasını girin" }; Write-HostSilent "ESD dosyası WIM formatına dönüştürülüyor (Index: $sourceIndex)..." "Yellow"; $tempConvertedWim = Join-Path -Path $env:TEMP -ChildPath "converted_install.wim"; if(Test-Path $tempConvertedWim) { Remove-Item $tempConvertedWim -Force }; dism /export-image /SourceImageFile:$customWimPath /SourceIndex:$sourceIndex /DestinationImageFile:$tempConvertedWim /Compress:max /CheckIntegrity; if ($LASTEXITCODE -ne 0) { Add-Log "ESD'den WIM'e dönüşüm başarısız." -Level "ERROR"; Write-Host "HATA: ESD dosyası WIM formatına dönüştürülemedi." -ForegroundColor Red; return }; $customWimPath = $tempConvertedWim; Add-Log "ESD dosyası başarıyla geçici WIM dosyasına dönüştürüldü." -Level "SUCCESS"
    }

    Write-HostSilent "`nŞablon ISO dosyası bağlanıyor ve içeriği kopyalanıyor..." "Cyan"
    Add-Log "Sanal Disk (vds) hizmeti kontrol ediliyor..." -Level "INFO"
    try {
        $vdsService = Get-Service -Name "vds" -ErrorAction SilentlyContinue
        if ($vdsService -and $vdsService.Status -ne 'Running') {
            Write-HostSilent "Sanal Disk hizmeti başlatılıyor..." "DarkCyan"
            Start-Service -Name "vds" -ErrorAction Stop
            Add-Log "Sanal Disk hizmeti başlatıldı, 2 saniye bekleniyor..." -Level "SUCCESS"
            Start-Sleep -Seconds 2
        }
    }
    catch { Add-Log "Sanal Disk hizmeti başlatılamadı: $($_.Exception.Message)" -Level "ERROR"; Write-Host "HATA: ISO bağlama için gerekli olan Sanal Disk hizmeti başlatılamadı." -ForegroundColor Red; return }

    $mountResult = $null
    try {
        $mountResult = Mount-DiskImage -ImagePath $templateIsoPath -PassThru -ErrorAction Stop; $driveLetter = ($mountResult | Get-Volume).DriveLetter; $sourcePath = "${driveLetter}:\"; if (Get-Command robocopy -ErrorAction SilentlyContinue) { Write-HostSilent "Hızlı kopyalama için robocopy kullanılıyor. Lütfen canlı ilerlemeyi takip edin..." "Cyan"; $robocopyArgs = @($sourcePath, $tempWorkingDir, "/E", "/R:1", "/W:1", "/NP", "/TEE"); robocopy @robocopyArgs; if ($LASTEXITCODE -ge 8) { Add-Log "Robocopy ciddi bir hata verdi. Hata Kodu: $LASTEXITCODE" -Level "ERROR"; Write-Host "HATA: Dosya kopyalama sırasında ciddi bir hata oluştu (Robocopy)." -ForegroundColor Red; return } } else { $allFiles = Get-ChildItem -Path $sourcePath -Recurse -File; $totalFiles = $allFiles.Count; $copiedCount = 0; foreach ($file in $allFiles) { $copiedCount++; $destination = $file.FullName.Replace($sourcePath, $tempWorkingDir); New-Item -Path (Split-Path $destination) -ItemType Directory -Force | Out-Null; Copy-Item -Path $file.FullName -Destination $destination -Force; $percent = [math]::Round(($copiedCount / $totalFiles) * 100); Write-Progress -Activity "ISO içeriği kopyalanıyor" -Status "$($file.Name)" -PercentComplete $percent }; Write-Progress -Activity "ISO içeriği kopyalanıyor" -Completed }; Add-Log "Şablon ISO içeriği başarıyla geçici klasöre kopyalandı." -Level "SUCCESS"
    } catch {
        Add-Log "Şablon ISO işlenirken hata oluştu: $($_.Exception.Message)" -Level "ERROR"; Write-Host "HATA: Şablon ISO dosyası bağlanamadı veya okunamadı." -ForegroundColor Red; return
    } finally {
        if ($mountResult) { Dismount-DiskImage -InputObject $mountResult -ErrorAction SilentlyContinue }
    }

    Write-HostSilent "Standart 'install.wim' dosyası özel yedekle değiştiriliyor..." "Cyan"; $targetWim = Join-Path -Path $tempWorkingDir -ChildPath "sources\install.wim"; $targetEsd = Join-Path -Path $tempWorkingDir -ChildPath "sources\install.esd"; if (Test-Path $targetWim) { Remove-Item $targetWim -Force }; if (Test-Path $targetEsd) { Remove-Item $targetEsd -Force }; Copy-Item -Path $customWimPath -Destination $targetWim -Force; Add-Log "Özel WIM dosyası, install.wim olarak sources klasörüne kopyalandı." -Level "SUCCESS"
    $estimatedSize = [math]::Round(((Get-ChildItem $tempWorkingDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB),2); Write-HostSilent "`nOluşturulacak ISO dosyasının tahmini boyutu: $estimatedSize GB" "Cyan"

    Write-HostSilent "`nÖnyüklenebilir ISO dosyası oluşturuluyor. Bu işlem uzun sürebilir..." "Green"; $bootData = "2#p0,e,b`"$($tempWorkingDir)\boot\etfsboot.com`"#pEF,e,b`"$($tempWorkingdir)\efi\microsoft\boot\efisys.bin`""; $arguments = @( "-m", "-o", "-u2", "-udfver102", "-bootdata:$bootData", "-l$newIsoLabel", "`"$tempWorkingDir`"", "`"$newIsoPath`""); Add-Log "oscdimg komutu çalıştırılıyor: $oscdimgExePath $($arguments -join ' ')" -Level "ACTION"

    $process = Start-Process -FilePath $oscdimgExePath -ArgumentList $arguments -Wait -NoNewWindow -PassThru
    $exitCode = $process.ExitCode
    $elapsed = $process.ExitTime - $process.StartTime
    Add-Log "ISO oluşturma süresi: $([math]::Round($elapsed.TotalMinutes, 2)) dakika." -Level "INFO"
    
    if ((Test-Path $newIsoPath) -and ($exitCode -eq 0)) {
        $isoSize = [math]::Round((Get-Item $newIsoPath).Length/1GB, 2); Add-Log "Önyüklenebilir ISO başarıyla oluşturuldu: $newIsoPath" -Level "SUCCESS"; Write-Host "`n[BAŞARILI] ISO dosyası başarıyla oluşturuldu!" -ForegroundColor Green; Write-Host "Dosya: $newIsoPath" -ForegroundColor Cyan; Write-Host "Boyut: $isoSize GB" -ForegroundColor Cyan
    } else {
        Add-Log "oscdimg bir hata verdi. Kod: $exitCode" -Level "ERROR"; Write-Host "`n[HATA] ISO oluşturulurken bir hata oluştu! Hata Kodu: $exitCode" -ForegroundColor Red
    }

    Write-HostSilent "Geçici dosyalar temizleniyor..." "DarkGray"
    if (Test-Path $tempWorkingDir) { Remove-Item -Path $tempWorkingDir -Recurse -Force }
    if ($tempConvertedWim) { Remove-Item $tempConvertedWim -Force -ErrorAction SilentlyContinue }
}

# =====================================================================
#             BÖLÜM 3: UYGULAMA YÜKLEYİCİ (NİHAİ HİBRİT SİSTEM)
# =====================================================================

function Invoke-AppInstaller {
    # Bu fonksiyon içindeki değişkenleri global veya script scope olarak tanımlayalım
    # Böylece Start-AppInstallation fonksiyonu da bunlara erişebilir.
    $script:basePath = Split-Path -Path $PSScriptRoot -Parent
    $script:configFile = Join-Path $script:basePath "Data\Applications.json"
    $script:installersPath = Join-Path $script:basePath "Installers"
    
    Add-Log "Hibrit Uygulama Yükleyici modülü başlatıldı." -Level "ACTION"
    Add-Log "Proje Kök Dizini: $script:basePath" -Level "DEBUG"
    Add-Log "Applications.json Yolu: $script:configFile" -Level "DEBUG"
    Add-Log "Installers Klasör Yolu: $script:installersPath" -Level "DEBUG"

    # --- NİHAİ VE KARARLI KOD BAŞLANGICI ---
    
    # 1. Değişkeni garanti olsun diye boş bir dizi olarak başlat.
    $allApps = @()
    Add-Log "Uygulama listesi okunuyor: $script:configFile" -Level "INFO"

    # 2. Dosyanın varlığını ve içeriğini güvenli bir şekilde kontrol et.
    if (Test-Path $script:configFile) {
        try {
            $jsonContent = Get-Content -Path $script:configFile -Raw -Encoding utf8
            if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
                $parsedJson = $jsonContent | ConvertFrom-Json
                
                # 3. JSON içinde "Applications" anahtarının ve bu anahtarın bir dizi olduğundan emin ol.
                if ($null -ne $parsedJson.Applications -and $parsedJson.Applications -is [System.Array]) {
                    $allApps = $parsedJson.Applications
                    Add-Log "$($allApps.Count) uygulama 'Applications.json' dosyasından başarıyla yüklendi." -Level "SUCCESS"
                } else {
                    Add-Log "HATA: Applications.json dosyası beklenen 'Applications' anahtarını içermiyor veya formatı dizi değil." -Level "ERROR"
                }
            }
        } catch {
            Add-Log "HATA: Applications.json dosyası okunurken veya işlenirken bir hata oluştu: $($_.Exception.Message)" -Level "ERROR"
            Write-Host "HATA: Applications.json dosyası okunamadı veya bozuk." -ForegroundColor Red
        }
    } else {
        Add-Log "UYARI: Applications.json dosyası bulunamadı." -Level "WARN"
    }

    # 4. Yerel (Installers klasörü) uygulamaları tara ve listeye ekle.
    Add-Log "Installers klasörü taranıyor: $script:installersPath" -Level "INFO"
    if (-not (Test-Path $script:installersPath)) { 
        New-Item -Path $script:installersPath -ItemType Directory -Force | Out-Null 
        Add-Log "Installers klasörü oluşturuldu: $script:installersPath" -Level "INFO"
    }
    
    $existingLocalFileNames = $allApps | Where-Object { $_.Source -eq 'local' } | Select-Object -ExpandProperty FileName

    Get-ChildItem -Path $script:installersPath -File -Include "*.exe", "*.msi", "*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notin $existingLocalFileNames) {
            $newEntry = [PSCustomObject]@{
                AppName     = $_.BaseName
                Source      = "local"
                FileName    = $_.Name
                SilentArgs  = if ($_.Extension -eq ".zip") { "" } else { "/S" }
                Available   = $true
            }
            $allApps += $newEntry
            Add-Log "Yeni yerel uygulama bulundu ve listeye eklendi: $($newEntry.AppName)" -Level "INFO"
        }
    }

    # 5. Güncellenen listeyi tekrar dosyaya kaydet.
    Add-Log "Uygulama listesi güncelleniyor ve kaydediliyor..." -Level "INFO"
    try {
        @{ Applications = $allApps } | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $script:configFile -Encoding utf8
    } catch {
        Add-Log "HATA: Güncellenmiş uygulama listesi Applications.json dosyasına kaydedilemedi: $($_.Exception.Message)" -Level "ERROR"
    }
    
    # --- NİHAİ VE KARARLI KOD SONU ---

    # Winget kontrolü
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        Write-Host "HATA: 'winget' bulunamadı. Winget uygulamaları yüklenemez." -ForegroundColor Red; 
        Add-Log "HATA: 'winget' bulunamadı. Winget uygulamaları yüklenemeyecek." -Level "ERROR"; 
    }

    # Kurulum işlemini yönetecek alt fonksiyon (BU ÖNEMLİ KISIM)
    function Start-AppInstallation {
        param($appsToInstall)
        foreach ($app in $appsToInstall) {
            Write-Host "`nKuruluyor: '$($app.AppName)' (Kaynak: $($app.Source))..." -ForegroundColor Green
            Add-Log "Kurulum başlatılıyor: $($app.AppName) (Kaynak: $($app.Source))" -Level "ACTION"

            try {
                if ($app.Source -eq "local") {
                    $installerFile = Join-Path $script:installersPath $app.FileName
                    
                    if (-not (Test-Path $installerFile)) {
                        Write-Host "HATA: Yerel kurulum dosyası bulunamadı: '$installerFile'" -ForegroundColor Red
                        Add-Log "HATA: Yerel kurulum dosyası bulunamadı: '$installerFile'" -Level "ERROR"
                        continue # Bu uygulamayı atla ve bir sonrakine geç
                    }

                    if ($app.FileName.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
                        Write-Host "UYARI: ZIP dosyaları doğrudan katılımsız kurulamaz. Lütfen içeriğini manuel olarak çıkarın ve kurun." -ForegroundColor Yellow
                        Add-Log "UYARI: ZIP dosyası seçildi, manuel işlem gerekli: $($app.AppName) ($installerFile)" -Level "WARNING"
                        continue 
                    }
                    
                    Add-Log "Yerel kurulum (belirtilen parametrelerle): $installerFile $($app.SilentArgs)" -Level "ACTION"
                    try {
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = $installerFile
                        $processInfo.Arguments = $app.SilentArgs
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
                            Add-Log "'$($app.AppName)' kurulumu başarıyla tamamlandı. Çıktı: $output $errorOutput" -Level "SUCCESS" 
                        } else { 
                            Add-Log "UYARI: '$($app.AppName)' kurulumu bir hata koduyla tamamlandı: $($process.ExitCode). Çıktı: $output $errorOutput" -Level "WARNING" 
                        }
                    } catch {
                        Add-Log "HATA: '$($app.AppName)' katılımsız kurulumu başlatılamadı: $($_.Exception.Message)" -Level "ERROR"
                        Write-Host "HATA: '$($app.AppName)' kurulumu başlatılamadı: $($_.Exception.Message)" -ForegroundColor Red
                    }

                } else { # winget uygulamaları
                    Add-Log "Winget kurulumu başlatılıyor: $($app.PackageId)" -Level "ACTION"
                        $arguments = @("install", "--id", $app.PackageId, "--source", "winget", "--silent", "--accept-package-agreements", "--accept-source-agreements")
                    
                    try {
                        $wingetOutput = & winget $arguments *>&1 
                        
                        if ($LASTEXITCODE -eq 0) {
                            Add-Log "'$($app.AppName)' kurulumu başarıyla tamamlandı (Winget). Çıktı: $wingetOutput" -Level "SUCCESS"
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

    # Ana menüye geçiş döngüsü
    while ($true) {
        cls
        Write-Host "--- WinFast Hibrit Uygulama Yükleyici ---" -ForegroundColor Yellow
        Write-Host "Kuruluma hazır uygulamalar:"

        $availableApps = $allApps | Where-Object { $_.Available } | Sort-Object AppName

        if ($availableApps.Count -eq 0) { 
            Write-Host "`nKuruluma uygun hiçbir uygulama bulunamadı." -ForegroundColor Yellow
            Start-Sleep 4
            return 
        }
        
        for ($i = 0; $i -lt $availableApps.Count; $i++) {
            $app = $availableApps[$i]
            $sourceTagColor = if($app.Source -eq "local") {"Green"} else {"Cyan"}
            Write-Host (" {0,2} - {1}" -f ($i + 1), "$($app.AppName) [$($app.Source)]") -ForegroundColor $sourceTagColor
        }
        
        Write-Host "`nT - Tümünü Kur" -ForegroundColor Magenta
        Write-Host "X - Ana Menüye Dön" -ForegroundColor Red
        $choice = Read-Host "`nKurmak istediğiniz uygulamaların numarasını virgülle ayırarak girin (örn: 1,3,5)"

        if ($choice.ToUpper() -eq 'X') { break }
        
        $appsToInstall = @()
        if ($choice.ToUpper() -eq 'T') { 
            $appsToInstall = $availableApps 
        } else { 
            $selectedIndexes = $choice -split ',' | ForEach-Object {
                if ($_ -match '^\s*(\d+)\s*$') {
                    [int]$matches[1] - 1
                }
            }
            
            foreach ($index in $selectedIndexes) {
                if ($index -ge 0 -and $index -lt $availableApps.Count) {
                    $appsToInstall += $availableApps[$index]
                }
            }
        }

        if ($appsToInstall.Count -gt 0) { 
            Start-AppInstallation -appsToInstall $appsToInstall 
        } else {
            Write-Host "Geçersiz seçim veya uygulama bulunamadı. Lütfen tekrar deneyin." -ForegroundColor Yellow
            Start-Sleep 2
        }
    }
}






