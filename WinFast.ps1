#Requires -RunAsAdministrator
#Requires -Modules Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility, Microsoft.PowerShell.Diagnostics

<#
.SYNOPSIS
    Windows'u güvenli, interaktif ve GERİ ALINABİLİR şekilde optimize etmek için tasarlanmış profesyonel ve tam özellikli PowerShell betiği.

.NOTES
      Ad: WinFast Optimizasyon Betiği (Nihai Sürüm - v13.1)
 Yapımcı: Levent Buğdaycı & Gemini
   Tarih: 16 Haziran 2025
   Sürüm: 13.1 (Nihai Menü ve Fonksiyon Düzeltmeleri)

   UYARI: Bu betik sisteminizde köklü değişiklikler yapar. Lütfen her adımdaki uyarıları dikkatlice okuyun ve yedekleme seçeneklerini kullanın.
#>

#region Global Değişkenler ve Kurulum
try {
    function Add-Log { param([string]$Message, [string]$Level = "INFO"); $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] - $Message"; $colorMap = @{ INFO = "Gray"; WARN = "Yellow"; ERROR = "Red"; ACTION = "Magenta"; SUCCESS = "Green"; DEBUG = "DarkGray" }; $consoleColor = if ($colorMap.ContainsKey($Level)) { $colorMap[$Level] } else { "White" }; Write-Host $logEntry -ForegroundColor $consoleColor -ErrorAction SilentlyContinue; if ($Global:LogFile) { try { Add-Content -Path $Global:LogFile -Value $logEntry -Encoding utf8 -ErrorAction SilentlyContinue } catch { Write-Host "UYARI: Log dosyasına yazılırken hata: $($_.Exception.Message)" -ForegroundColor DarkYellow -ErrorAction SilentlyContinue } } }
    $Global:LogFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Logs"; $Global:UndoFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "UndoScripts"; $Global:JsonSettingsFile = Join-Path -Path $PSScriptRoot -ChildPath "RegistryTweaks.json"; $Global:TempUndoServiceActions = @(); @($Global:LogFolderPath, $Global:UndoFolderPath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory -Force | Out-Null } }; $Global:LogFile = Join-Path -Path $Global:LogFolderPath -ChildPath "WinFast_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"; "Log dosyası oluşturuldu: $Global:LogFile" | Out-File -FilePath $Global:LogFile -Encoding utf8
} catch { Write-Host "HATA: Gerekli klasörler oluşturulamadı." -ForegroundColor Red; Exit 1 }
#endregion

#region Modül Yükleme
Add-Log "Modüller yükleniyor..." -Level "INFO"
try {
    . (Join-Path $PSScriptRoot "Modules\UtilityFunctions.ps1")
    . (Join-Path $PSScriptRoot "Modules\CoreFunctions.ps1")
    . (Join-Path $PSScriptRoot "Tools\SystemTools.ps1")
    . (Join-Path $PSScriptRoot "Optimizations\Optimizations.ps1")
    Add-Log "Tüm modüller başarıyla yüklendi." -Level "SUCCESS"
} catch { Write-Host "HATA: Modüller yüklenirken sorun oluştu: $($_.Exception.Message)" -ForegroundColor Red; Add-Log "Modül yükleme hatası: $_" -Level "ERROR"; Exit 1 }
#endregion

Add-Log "Betiğin çalıştırılması yönetici haklarıyla başlatıldı. Sürüm: 13.1" -Level "INFO"

#region Ana Menü ve Döngü
function Display-MainMenu {
    cls
    Write-Host "WinFast Optimizasyon Betiği v13.1 (Nihai Kararlı Sürüm)" -ForegroundColor Green
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "Log Dosyası: $($Global:LogFile.Split('\')[-1])" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    
    Write-Host "Yedekleme & Geri Alma" -ForegroundColor Yellow
    Write-Host " 1. Sistem Geri Yükleme Noktası Oluştur" -ForegroundColor Magenta
    Write-Host " 2. Kayıt Defteri Tam Yedeklemesi Yap" -ForegroundColor Magenta
    Write-Host " 3. Yapılan Değişiklikleri Geri Al (Undo)" -ForegroundColor Cyan
    Write-Host " 4. Kurulu Windows'un WIM/ESD Görüntüsünü Al" -ForegroundColor Magenta
    Write-Host " 5. Yedekten Önyüklenebilir ISO Oluştur" -ForegroundColor Magenta
    
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "Kurulum, Temizlik & Yönetim" -ForegroundColor Yellow
    Write-Host " 6. Uygulama Yükleyici (Installers Klasörü)" -ForegroundColor Cyan
    Write-Host " 7. Genel Sistem Temizliği" -ForegroundColor Green
    Write-Host " 8. Genişletilmiş Sistem Temizliği (Gölge Kopyalar, DISM)" -ForegroundColor Red
    Write-Host " 9. Uygulama Kaldırma (Debloat)" -ForegroundColor Red
    Write-Host "10. Ağ Testi ve DNS Ayarları" -ForegroundColor Green
    Write-Host "11. Güç Planı Optimizasyonları" -ForegroundColor Green
    Write-Host "12. Başlangıç Uygulamalarını Yönet" -ForegroundColor Green
    Write-Host "13. Sistem Bilgilerini Görüntüle" -ForegroundColor Green
    Write-Host "14. Kişisel Arayüz Ayarları" -ForegroundColor Green

    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "Otomatik & Genel Optimizasyonlar" -ForegroundColor Yellow
    Write-Host " A. Tavsiye Edilen Optimizasyonları Otomatik Uygula" -ForegroundColor Green
    Write-Host "15. Telemetri ve Gizlilik Ayarlarını Kapat" -ForegroundColor Green
    Write-Host "16. Arama Ayarları Optimizasyonları" -ForegroundColor Green
    Write-Host "17. Genel Sistem Performans Optimizasyonları" -ForegroundColor Green
    Write-Host "18. Dosya Gezgini ve Arayüz Optimizasyonları" -ForegroundColor Green
    Write-Host "19. Ağ Optimizasyonları (Gecikme Düşmanı)" -ForegroundColor Green
    Write-Host "20. Giriş Aygıtı Optimizasyonları (Input Lag Düşmanı)" -ForegroundColor Green
    Write-Host "21. Multimedya Önceliklendirme (MMCSS)" -ForegroundColor Green
    Write-Host "22. Görsel Efektleri Optimize Et" -ForegroundColor Green
    Write-Host "23. Oyun Modu ve Oyun Çubuğu Ayarları" -ForegroundColor Green
    Write-Host "24. Arka Plan Uygulamalarını Devre Dışı Bırak" -ForegroundColor Green
    
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "Donanım Optimizasyonları" -ForegroundColor Yellow
    Write-Host "25. GPU Optimizasyonları (NVIDIA/AMD/Intel)" -ForegroundColor Magenta
    Write-Host "26. Depolama Optimizasyonları (SSD/HDD)" -ForegroundColor Magenta
    Write-Host "27. Bellek (RAM) Optimizasyonları" -ForegroundColor Magenta
    
    Write-Host "--------------------------------------------------------" -ForegroundColor Green
    Write-Host "Uzman & Riskli İşlemler" -ForegroundColor Red
    Write-Host "28. Çekirdek Yalıtımını (Bellek Bütünlüğü) Devre Dışı Bırak" -ForegroundColor Red
    Write-Host "29. MPO (Multi-Plane Overlay) Devre Dışı Bırak" -ForegroundColor Red
    Write-Host "30. CS2'ye Özel Tavsiyeler (Manuel Uygulama)" -ForegroundColor Red
    Write-Host "31. Gelişmiş Ağ Ayarları (İNTERAKTİF)" -ForegroundColor Red
    Write-Host "32. Microsoft Edge'i Kapat" -ForegroundColor Red
    Write-Host "33. Microsoft Defender'ı Kapat" -ForegroundColor Red
    Write-Host "34. Windows Update Optimizasyonları" -ForegroundColor Red
    Write-Host "35. Windows Güncellemelerini TAMAMEN KAPAT" -ForegroundColor Red
    Write-Host "36. Windows Olay Günlüklerini TAMAMEN KAPAT" -ForegroundColor Red
    Write-Host "37. Yandex Güncellemelerini Kapat" -ForegroundColor Red
    Write-Host "38. Gelişmiş Servis Yönetimi (İNTERAKTİF)" -ForegroundColor Red
    Write-Host "39. Microsoft Dışı Servisleri Yönet (İNTERAKTİF)" -ForegroundColor Red
    Write-Host "40. Windows Özelliklerini Kaldır (İNTERAKTİF)" -ForegroundColor Red
    Write-Host "41. Windows Fotoğraf Görüntüleyici'yi Kaldır" -ForegroundColor Red
    Write-Host "42. Windows Arama'yı Tamamen Kaldır (Cortana)" -ForegroundColor Red
    Write-Host "43. NVIDIA Profili İçe Aktar (NVPI)" -ForegroundColor Red
    Write-Host "44. Belirli Sistem Aygıtlarını Kapat (HPET vb.)" -ForegroundColor Red
    Write-Host "45. Sanal Belleği Otomatik Ayarla (Pagefile)" -ForegroundColor Red
    Write-Host "46. Kayıt Defteri Temizleyici (İNTERAKTİF)" -ForegroundColor Red
    Write-Host " X. Çıkış" -ForegroundColor Red
}

function Display-CleanupMenu {
    cls
    Write-Host "--- Sistem Temizliği Alt Menüsü ---" -ForegroundColor Yellow
    Write-Host "1. Hızlı Genel Temizlik (Önerilen)" -ForegroundColor Cyan
    Write-Host "2. Derin Dosya Temizliği (Tüm C:/D: Taranır - YAVAŞ!)" -ForegroundColor Magenta
    Write-Host "X. Ana Menüye Dön" -ForegroundColor Red
    $subChoice = Read-Host "`nLütfen yapmak istediğiniz temizlik türünü seçin"
    switch ($subChoice.ToUpper()) {
        "1" { Perform-GeneralCleanup }
        "2" { Perform-DeepFileScan }
        "X" { return }
        default { Add-Log "Geçersiz alt menü seçimi: $subChoice" -Level "WARN" }
    }
}

$continueScript = $true
while ($continueScript) {
    Display-MainMenu
    $choice = Read-Host "`nLütfen yapmak istediğiniz işlemi seçin"

    switch ($choice.ToUpper()) {
        "A"  { Invoke-AutomaticOptimization }
        "1"  { New-SystemRestorePoint }
        "2"  { Backup-Registry }
        "3"  { Restore-TweaksFromUndoFile }
        "4"  { Invoke-WindowsBackup }
        "5"  { Invoke-CreateBootableISO }
        "6"  { Invoke-AppInstaller -ProjectRootPath $PSScriptRoot }
        "7"  { Display-CleanupMenu }
        "8"  { Perform-ExtendedCleanup }
        "9"  { Manage-AppxPackages }
        "10" { Manage-DNS }
        "11" { Manage-PowerPlan }
        "12" { Manage-StartupApps }
        "13" { Display-SystemInfo }
        "14" { Manage-PersonalPresets }
        "15" { Disable-TelemetryAndPrivacySettings }
        "16" { Optimize-SearchSettings }
        "17" { Optimize-SystemPerformance }
        "18" { Optimize-ExplorerSettings }
        "19" { Optimize-Network }
        "20" { Optimize-InputDevices }
        "21" { Optimize-MMCSS } 
        "22" { Optimize-VisualEffects } 
        "23" { Optimize-GameMode } 
        "24" { Disable-BackgroundApps } 
        "25" { Manage-GpuOptimizations }
        "26" { Manage-StorageOptimizations }
        "27" { Manage-MemoryOptimizations }
        "28" { Disable-CoreIsolation } 
        "29" { Disable-MPO } 
        "30" { Show-CS2Recommendations } 
        "31" { Apply-InteractiveAdvancedNetworkTweaks } 
        "32" { Disable-MicrosoftEdge } 
        "33" { Disable-WindowsDefender } 
        "34" { Optimize-WindowsUpdates } 
        "35" { Disable-UpdatesCompletely } 
        "36" { Disable-EventLogging }
        "37" { Disable-YandexUpdates }
        "38" { Manage-AdvancedServices }
        "39" { Manage-NonMsServices }
        "40" { Remove-WindowsFeatures }
        "41" { Remove-PhotoViewer }
        "42" { Remove-WindowsSearch }
        "43" { Import-NvidiaProfile }
        "44" { Disable-SpecificDevices }
        "45" { Manage-VirtualMemory }
        "46" { Invoke-RegistryCleanup }
        "X"  { $continueScript = $false }
        default { Add-Log "Kullanıcı geçersiz bir menü seçimi yaptı: $choice" -Level "WARN" }
    }
    
    if ($continueScript) {
        Show-ProcessCompleted
        Write-Host "`nAna menüye dönmek için bir tuşa basın..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

Add-Log "Betiğin çalışması normal bir şekilde sona erdi." -Level "INFO"
Write-Host "Optimizasyon betiği sona erdi. İyi günler!" -ForegroundColor Green
