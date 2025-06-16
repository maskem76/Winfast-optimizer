#region Optimizasyon Fonksiyonları
<#
.SYNOPSIS
    Windows telemetri ve gizlilik ayarlarını devre dışı bırakır.
#>
function Disable-TelemetryAndPrivacySettings {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Telemetri ve Gizlilik ayarları uygulanacak. Bu, Microsoft'a veri gönderimini kısıtlar.")) {
        Generate-AndApplyTweaks -Category "TelemetryAndPrivacy"
        Set-ServiceState -ServiceName "DiagTrack"
        Set-ServiceState -ServiceName "dmwappushservice"
    }
}

<#
.SYNOPSIS
    Microsoft Defender'ı devre dışı bırakır.
#>
function Disable-WindowsDefender {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "UYARI: Bu işlem sisteminizi RİSKE ATAR! Alternatif bir antivirüs yazılımınız yoksa devam etmeyin." -Challenge "DEFENDERI_KAPAT")) {
        Generate-AndApplyTweaks -Category "WindowsDefender"
        Set-ServiceState -ServiceName "WinDefend"
        Set-ServiceState -ServiceName "WdNisSvc"
        Set-ServiceState -ServiceName "SecurityHealthService"
    }
}

<#
.SYNOPSIS
    Microsoft Edge tarayıcısını devre dışı bırakmaya çalışır.
#>
function Disable-MicrosoftEdge {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Microsoft Edge devre dışı bırakılmaya çalışılacak. Bu, bazı Windows özelliklerini etkileyebilir.")) {
        Add-Log "Bilgi: Bu işlem, Windows güncellemelerinin Edge'i yeniden yüklemesini engellemeyebilir." -Level "INFO"
        Generate-AndApplyTweaks -Category "MicrosoftEdge"
        Set-ServiceState -ServiceName "edgeupdate"
        Set-ServiceState -ServiceName "edgeupdatem"
    }
}

<#
.SYNOPSIS
    Windows Update optimizasyonları uygular (güncellemeleri erteler).
#>
function Optimize-WindowsUpdates {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "UYARI: Güncellemeleri ertelemek sisteminizi güvenlik açıklarına maruz bırakabilir." -Challenge "GUNCELLEMEYI DURDUR")) {
        Generate-AndApplyTweaks -Category "WindowsUpdates"
        Set-ServiceState -ServiceName "wuauserv" -StartupType "Manual"
        Set-ServiceState -ServiceName "DoSvc" -StartupType "Manual"
    }
}

<#
.SYNOPSIS
    Windows Update'i tamamen devre dışı bırakır.
#>
function Disable-UpdatesCompletely {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "ÇOK RİSKLİ! Bu işlem Windows Update'i tamamen durdurur ve güvenlik açıklarına yol açar!" -Challenge "GUNCELLEMELERI TAMAMEN KAPAT")) {
        Generate-AndApplyTweaks -Category "Updates_CompleteDisable"
        Add-Log "Windows Update ile ilgili tüm servisler durduruluyor ve devre dışı bırakılıyor..." -Level "ACTION"
        Set-ServiceState -ServiceName "wuauserv" -StartupType Disabled -StopService $true
        Set-ServiceState -ServiceName "DoSvc" -StartupType Disabled -StopService $true
        Set-ServiceState -ServiceName "bits" -StartupType Disabled -StopService $true
        Set-ServiceState -ServiceName "UsoSvc" -StartupType Disabled -StopService $true
        Add-Log "Güncelleme Orkestratörü zamanlanmış görevleri aranıyor ve siliniyor..." -Level "ACTION"
        try {
            $updateOrchestratorTasks = Get-ScheduledTask | Where-Object { $_.TaskPath -like '\Microsoft\Windows\UpdateOrchestrator\*' }
            if ($updateOrchestratorTasks) {
                foreach ($task in $updateOrchestratorTasks) {
                    Add-Log "Zamanlanmış görev siliniyor: $($task.TaskName) (Yol: $($task.TaskPath))" -Level "ACTION"
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                }
                Add-Log "Tüm Güncelleme Orkestratörü görevleri başarıyla kaldırıldı." -Level "SUCCESS"
            } else {
                Add-Log "Güncelleme Orkestratörü görevleri bulunamadı veya zaten yok." -Level "INFO"
            }
        } catch {
            Add-Log "Güncelleme Orkestratörü görevleri kontrol edilirken/silinirken hata oluştu: $($_.Exception.Message)" -Level "ERROR"
        }
        Add-Log "Windows Update ve ilgili bileşenleri tamamen devre dışı bırakma işlemi tamamlandı." -Level "SUCCESS"
        Write-Host "`nUYARI: Windows Update tamamen devre dışı bırakıldı." -ForegroundColor Red
        Write-Host "Değişikliklerin tam olarak uygulanması için bilgisayarınızı yeniden başlatmanız önerilir." -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Genel sistem performans ayarlarını optimize eder.
#>
function Optimize-SystemPerformance {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Genel sistem performans ayarları uygulanacak.")) { 
        Generate-AndApplyTweaks -Category "SystemPerformance"
        $systemDriveLetter = $env:SystemDrive.Trim(":")
        $partition = Get-Partition -DriveLetter $systemDriveLetter -ErrorAction SilentlyContinue
        if($partition) {
            $diskNumber = $partition.DiskNumber
            $systemDisk = Get-PhysicalDisk -DeviceNumber $diskNumber -ErrorAction SilentlyContinue
            if ($systemDisk.MediaType -eq "SSD") { 
                Add-Log "Sistem diski SSD olarak tespit edildi, Hazırda Bekleme kapatılıyor ve SysMain hizmeti devre dışı bırakılıyor." -Level "INFO" 
                powercfg.exe /hibernate off
                Set-ServiceState -ServiceName "SysMain" 
            }
        }
    } 
}

<#
.SYNOPSIS
    Windows Dosya Gezgini ve arayüz ayarlarını optimize eder.
#>
function Optimize-ExplorerSettings {
    param([switch]$Force)
    Generate-AndApplyTweaks -Category "ExplorerSettings"
    Add-Log "Arayüz ayarlarının tam uygulanması için Explorer yeniden başlatılıyor." -Level "INFO"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    Windows Arama ayarlarını optimize eder.
#>
function Optimize-SearchSettings {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Arama ayarları optimize edilecek.")) {
        Generate-AndApplyTweaks -Category "SearchSettings"
    }
}

<#
.SYNOPSIS
    Genel ağ optimizasyonları uygular (gecikme düşürme odaklı).
#>
function Optimize-Network {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Ağ optimizasyonları (gecikme düşürme) uygulanacak.")) {
        Generate-AndApplyTweaks -Category "AdvancedNetworkTweaks"
    }
}

<#
.SYNOPSIS
    Giriş aygıtı (fare/klavye) optimizasyonları uygular.
#>
function Optimize-InputDevices {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Giriş aygıtı (fare/klavye) optimizasyonları uygulanacak.")) {
        Generate-AndApplyTweaks -Category "Input_Optimizations"
    }
}

<#
.SYNOPSIS
    Oyunlar için Multimedya Sınıf Zamanlama Hizmeti (MMCSS) profillerini optimize eder.
#>
function Optimize-MMCSS {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Oyunlar için Multimedya (MMCSS) profilleri optimize edilecek.")) {
        Generate-AndApplyTweaks -Category "MMCSS_Profiles"
    }
}

<#
.SYNOPSIS
    Windows görsel efektlerini performans için optimize eder (çoğunu kapatır).
#>
function Optimize-VisualEffects {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Görsel efektleri kapatarak performansı artırmak istediğinize emin misiniz?")) {
        Write-Host "Görsel efekt optimizasyonları uygulanacak. Bu, Windows'un görünümünü basitleştirebilir." -ForegroundColor Cyan
        Generate-AndApplyTweaks -Category "VisualEffects"
    }
}

<#
.SYNOPSIS
    Windows Oyun Modu (Game Mode) ve Oyun Çubuğu ayarlarını optimize eder.
#>
function Optimize-GameMode {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Windows Oyun Modu ve Oyun Çubuğu ayarları optimize edilecek. Bu, arka plan kayıt ve bildirimleri kapatabilir.")) {
        Generate-AndApplyTweaks -Category "GameMode"
    }
}

<#
.SYNOPSIS
    Windows Çekirdek Yalıtımını (Bellek Bütünlüğü) devre dışı bırakır.
#>
function Disable-CoreIsolation {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "UYARI: Bu işlem sisteminizi RİSKE ATAR! Alternatif bir antivirüs yazılımınız yoksa devam etmeyin." -Challenge "KAPAT")) {
        Generate-AndApplyTweaks -Category "CoreIsolation"
    }
}

<#
.SYNOPSIS
    Gereksiz arka plan uygulamalarına erişimi ve etkinliklerini devre dışı bırakır.
#>
function Disable-BackgroundApps {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Gereksiz arka plan uygulamaları ve etkinlikleri devre dışı bırakılacak. Bu, sistem kaynaklarını serbest bırakabilir.")) {
        Generate-AndApplyTweaks -Category "BackgroundApps"
    }
}

<#
.SYNOPSIS
    Multi-Plane Overlay (MPO) özelliğini devre dışı bırakır.
#>
function Disable-MPO {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Multi-Plane Overlay (MPO) devre dışı bırakılacak. Bu, oyunlarda titreme ve takılmaları azaltabilir.")) {
        Generate-AndApplyTweaks -Category "MPO_Optimization"
    }
}

<#
.SYNOPSIS
    CS2 (Counter-Strike 2) için önerilen Steam Başlatma Seçeneklerini ve oyun içi ayarları görüntüler.
#>
function Show-CS2Recommendations {
    Add-Log "CS2 İçin Önerilen Ayarlar ve Başlatma Seçenekleri" -Level "ACTION"
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "CS2 Steam Başlatma Seçenekleri (Steam > Kütüphane > CS2 > Özellikler > Başlatma Seçenekleri):" -ForegroundColor Yellow
    Write-Host "  -nojoy -fullscreen -novid +exec autoexec.cfg" -ForegroundColor White
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Add-Log "CS2 önerileri görüntülendi." -Level "INFO"
}

<#
.SYNOPSIS
    Windows olay günlüklerini devre dışı bırakır.
#>
function Disable-EventLogging {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "ÇOK RİSKLİ! Windows olay günlüklerini tamamen kapatmak istediğinize emin misiniz? Bu, sistem sorunlarını teşhis etmeyi zorlaştırabilir!" -Challenge "OLAYLOGKAPAT")) {
        Add-Log "Windows Olay Günlükleri kapatılıyor..." -Level "ACTION"
        $eventLogsToDisable = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.IsEnabled -eq $true -and $_.LogType -eq 'Operational' -and $_.LogName -notlike 'Microsoft-Windows-WindowsFirewall*' -and $_.LogName -notlike 'Security' }
        
        foreach ($log in $eventLogsToDisable) {
            Add-Log "Olay günlüğü kapatılıyor: $($log.LogName)" -Level "INFO"
            try {
                wevtutil.exe sl "$($log.LogName)" /enabled:false
                Add-Log "Olay günlüğü başarıyla kapatıldı: $($log.LogName)" -Level "SUCCESS"
            } catch {
                Add-Log "Olay günlüğü kapatılamadı: $($log.LogName). Hata: $($_.Exception.Message)" -Level "WARN"
            }
        }
    }
}

<#
.SYNOPSIS
    Yandex güncelleme görevlerini, servislerini ve dosyasını kalıcı olarak devre dışı bırakır.
#>
function Disable-YandexUpdates {
    param([switch]$Force)
    if ($Force -or (Confirm-Action -Prompt "Yandex güncelleme görevleri, servisleri devre dışı bırakılacak ve güncelleme dosyası kalıcı olarak yeniden adlandırılacak.")) {
        Add-Log "Yandex güncelleme mekanizmaları kalıcı olarak devre dışı bırakılıyor..." -Level "ACTION"
        Add-Log "Yandex ile ilgili zamanlanmış görevler aranıyor ve siliniyor..." -Level "INFO"
        try {
            $yandexTasks = Get-ScheduledTask | Where-Object { ($_.TaskPath -like '\Yandex\*' -or $_.TaskName -like '*Yandex*') -and $_.TaskName -like '*Update*' }
            if ($yandexTasks) {
                foreach ($task in $yandexTasks) {
                    Add-Log "Zamanlanmış görev siliniyor: $($task.TaskName) (Yol: $($task.TaskPath))" -Level "ACTION"
                    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                }
                Add-Log "Yandex Görev Zamanlayıcı görevleri başarıyla kaldırıldı." -Level "SUCCESS"
            } else {
                Add-Log "Yandex güncelleme görevi bulunamadı." -Level "INFO"
            }
        } catch { Add-Log "Yandex Görev Zamanlayıcı görevleri kontrol edilirken bir hata oluştu: $($_.Exception.Message)" -Level "WARN" }
        
        Add-Log "Yandex ile ilgili servisler aranıyor ve devre dışı bırakılıyor..." -Level "INFO"
        $yandexServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { ($_.DisplayName -like "*Yandex*" -or $_.Name -like "*Yandex*") -and ($_.Name -like "*update*" -or $_.Name -like "*service*" -or $_.Name -like "*browser*") }
        foreach ($service in $yandexServices) {
            Add-Log "Servis devre dışı bırakılıyor: $($service.Name) ($($service.DisplayName))" -Level "ACTION"
            Set-ServiceState -ServiceName $service.Name -StartupType Disabled -StopService $true
        }

        Add-Log "Yandex güncelleme dosyaları engelleniyor..." -Level "INFO"
        $yandexBasePaths = @((Join-Path $env:ProgramFiles "Yandex"), (Join-Path ${env:ProgramFiles(x86)} "Yandex"), (Join-Path $env:LOCALAPPDATA "Yandex"))
        $renamed = $false
        foreach ($basePath in $yandexBasePaths) {
            if (Test-Path $basePath) {
                $updateExecutables = Get-ChildItem -Path $basePath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*update*" -or $_.Name -like "*updater*" -or $_.Name -like "*service*" }
                foreach ($exeFile in $updateExecutables) {
                    $originalPath = $exeFile.FullName; $disabledPath = $originalPath -replace '\.exe$', '_disabled.exe'
                    if (Test-Path $disabledPath) { Add-Log "Yandex güncelleme dosyası zaten devre dışı bırakılmış: $originalPath" -Level "INFO"; $renamed = $true; continue }
                    if (Test-Path $originalPath) {
                        try {
                            Add-Log "Yandex güncelleme dosyası yeniden adlandırılıyor: $originalPath" -Level "ACTION"
                            Rename-Item -Path $originalPath -NewName (Split-Path $disabledPath -Leaf) -Force -ErrorAction Stop
                            Add-Log "Yandex güncelleme dosyası başarıyla yeniden adlandırıldı: $originalPath" -Level "SUCCESS"; $renamed = $true
                        } catch { Add-Log "Yandex güncelleme dosyası yeniden adlandırılamadı: $originalPath. Hata: $($_.Exception.Message)" -Level "ERROR" }
                    }
                }
            }
        }
        if (-not $renamed) { Add-Log "Yandex güncelleme dosyası bilinen konumlarda bulunamadı veya hiçbiri yeniden adlandırılamadı." -Level "WARN" }
        Add-Log "Yandex güncelleme mekanizmalarını devre dışı bırakma işlemi tamamlandı." -Level "SUCCESS"
    }
}

<#
.SYNOPSIS
    Gelişmiş ağ ayarlarını kullanıcıya tek tek sorarak interaktif olarak uygular.
#>
function Apply-InteractiveAdvancedNetworkTweaks {
    Add-Log "Gelişmiş Ağ Ayarları (İNTERAKTİF) modülü başlatıldı." -Level "ACTION"
    Write-Host "--- UYARI: GELİŞMİŞ VE RİSKLİ AĞ AYARLARI ---" -ForegroundColor Red
    Write-Host "Bu bölümdeki ayarlar ağ bağlantınızı, gecikmenizi ve bant genişliğinizi etkileyebilir." -ForegroundColor Yellow
    if (-not (Confirm-Action -Prompt "Devam etmek ve ayarları tek tek gözden geçirmek istediğinize emin misiniz?")) { Add-Log "Kullanıcı Gelişmiş Ağ Ayarlarını iptal etti." -Level "INFO"; return }
    $jsonPath = $Global:JsonSettingsFile
    if (-not (Test-Path $jsonPath)) { Add-Log "JSON dosyası bulunamadı: $jsonPath" -Level "ERROR"; return }
    $config = Get-Content -Path $jsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    $tweaks = $config.PSObject.Properties['AdvancedNetworkTweaks'].Value
    if (-not $tweaks) { Add-Log "JSON'da 'AdvancedNetworkTweaks' kategorisi bulunamadı." -Level "WARN"; return }
    Generate-UndoScript -Category "AdvancedNetworkTweaks"
    foreach ($tweak in $tweaks) {
        cls
        Write-Host "Sıradaki Ayar: $($tweak.Name)" -ForegroundColor Cyan
        Write-Host "Uygulanacak Değer: $($tweak.Value)" -ForegroundColor Cyan
        Write-Host "Kayıt Defteri Yolu: $($tweak.Path)" -ForegroundColor DarkGray
        $description = switch ($tweak.Name) {
            "EnablePMTUDiscovery" { "Ağ yolundaki maksimum paket boyutunu (MTU) otomatik keşfetmeyi devre dışı bırakır. Bazı ağlarda gecikmeyi azaltabilir." }
            "EnableDeadGWDetect"  { "Çalışmayan ağ geçitlerini (gateway) tespit etme özelliğini kapatır. Normalde performansı artırır." }
            "MaxUserPort"         { "Sistemin kullanabileceği maksimum port sayısını belirler. Çok sayıda bağlantı açan uygulamalar için iyidir." }
            "Start"               { if ($tweak.Path -like '*Ndu*') { "Ağ Veri Kullanımı (NDU) hizmetini kapatır. Bazı oyunlarda ani gecikme (stutter) sorunlarını çözebilir." } }
            default               { "Bu ayar için açıklama bulunamadı." }
        }
        Write-Host "Açıklama: $description" -ForegroundColor Green
        $choice = Read-Host "`nBu ayarı uygulamak istiyor musunuz? [E]vet / [H]ayır / [T]ümünü Atla"
        if ($choice.ToUpper() -eq 'E') {
            Add-Log "Kullanıcı '$($tweak.Name)' ayarını uygulamayı seçti." -Level "INFO"
            Set-RegistryValue -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Type $tweak.Type
        } elseif ($choice.ToUpper() -eq 'T') {
            Add-Log "Kullanıcı kalan tüm ayarları atlamayı seçti." -Level "INFO"; break
        } else { Add-Log "Kullanıcı '$($tweak.Name)' ayarını atladı." -Level "INFO" }
    }
    Write-Host "`nİnteraktif ağ optimizasyonu tamamlandı." -ForegroundColor Green
}

function Invoke-AutomaticOptimization {
    Add-Log "Otomatik Optimizasyon Modu başlatıldı." -Level "ACTION"
    Write-Host "--- OTOMATİK OPTİMİZASYON MODU ---" -ForegroundColor Yellow
    Write-Host "Bu mod, aşağıdaki TAVSİYE EDİLEN ayarları sizin için otomatik olarak uygulayacaktır:" -ForegroundColor Cyan
    Write-Host @"
    - Genel Sistem Temizliği
    - Telemetri ve Gizlilik Ayarları
    - Arama Ayarları Optimizasyonları
    - Genel Sistem Performans Optimizasyonları
    - Dosya Gezgini ve Arayüz Optimizasyonları
    - Ağ Optimizasyonları
    - Giriş Aygıtı Optimizasyonları (Fare/Klavye)
    - Multimedya Önceliklendirme (MMCSS)
    - Görsel Efekt Optimizasyonları
    - Arka Plan Uygulamalarını Kapatma
"@ -ForegroundColor DarkCyan

    if (Confirm-Action -Prompt "Yukarıdaki tüm ayarların uygulanmasını onaylıyor musunuz? Bu işlem geri alınabilir." -Challenge "OTOMATIK") {
        Add-Log "Kullanıcı Otomatik Optimizasyonu onayladı. İşlemler başlıyor..." -Level "INFO"
        Add-Log "Adım 1/10: Genel Sistem Temizliği yapılıyor..." -Level "ACTION"; Perform-GeneralCleanup
        Add-Log "Adım 2/10: Telemetri ve Gizlilik ayarları uygulanıyor..." -Level "ACTION"; Disable-TelemetryAndPrivacySettings -Force
        Add-Log "Adım 3/10: Arama ayarları optimize ediliyor..." -Level "ACTION"; Optimize-SearchSettings -Force
        Add-Log "Adım 4/10: Genel Sistem Performansı optimize ediliyor..." -Level "ACTION"; Optimize-SystemPerformance -Force
        Add-Log "Adım 5/10: Dosya Gezgini ayarları optimize ediliyor..." -Level "ACTION"; Optimize-ExplorerSettings -Force
        Add-Log "Adım 6/10: Ağ ayarları optimize ediliyor..." -Level "ACTION"; Optimize-Network -Force
        Add-Log "Adım 7/10: Giriş Aygıtları optimize ediliyor..." -Level "ACTION"; Optimize-InputDevices -Force
        Add-Log "Adım 8/10: MMCSS profilleri optimize ediliyor..." -Level "ACTION"; Optimize-MMCSS -Force
        Add-Log "Adım 9/10: Görsel Efektler optimize ediliyor..." -Level "ACTION"; Optimize-VisualEffects -Force
        Add-Log "Adım 10/10: Arka Plan Uygulamaları devre dışı bırakılıyor..." -Level "ACTION"; Disable-BackgroundApps -Force
        Write-Host "`nOtomatik Optimizasyon başarıyla tamamlandı!" -ForegroundColor Green
        Add-Log "Tüm otomatik optimizasyon adımları tamamlandı." -Level "SUCCESS"
    } else {
        Add-Log "Kullanıcı Otomatik Optimizasyonu iptal etti." -Level "WARN"
    }
}

function Remove-PhotoViewer {
    if (Confirm-Action -Prompt "Windows Fotoğraf Görüntüleyici'nin kayıt defteri anahtarları silinecek." -Challenge "FOTOGRAF") {
        Generate-AndApplyTweaks -Category "LegacyComponents_Remove"
    }
}

#endregion

# --- YENİ EKLENEN DONANIM OPTİMİZASYONLARI ---

#region Donanım Optimizasyonları

<#
.SYNOPSIS
    Kullanıcının RAM miktarına göre bellek optimizasyonları uygular.
#>
function Manage-MemoryOptimizations {
    Add-Log "Bellek (RAM) Optimizasyon modülü başlatıldı." -Level "ACTION"
    $ramSize = Read-Host "Lütfen sisteminizdeki RAM miktarını GB olarak girin (örn: 8, 16, 32)"
    if ($ramSize -match '^\d+$') {
        $ramBytes = [int64]$ramSize * 1024 * 1024 * 1024
        $thresholdKB = [int64]$ramBytes / 1024
        Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $thresholdKB -Type "DWord"
        Add-Log "SvcHostSplitThresholdInKB değeri $ramSize GB RAM için ayarlandı." -Level "SUCCESS"
        if ([int]$ramSize -ge 16) {
            Add-Log "16 GB veya daha fazla RAM algılandı, LargeSystemCache etkinleştiriliyor." -Level "INFO"
            Generate-AndApplyTweaks -Category "MemoryHigh"
        } else {
            Add-Log "16 GB'den az RAM algılandı, LargeSystemCache devre dışı bırakılıyor." -Level "INFO"
            Generate-AndApplyTweaks -Category "MemoryLow"
        }
    } else {
        Add-Log "Geçersiz RAM boyutu girişi: $ramSize" -Level "WARN"
    }
}

<#
.SYNOPSIS
    SSD veya HDD için depolama optimizasyonları uygular.
#>
function Manage-StorageOptimizations {
    Add-Log "Depolama Optimizasyonları modülü başlatıldı." -Level "ACTION"
    try {
        $systemDriveLetter = $env:SystemDrive.Trim(":")
        $partition = Get-Partition -DriveLetter $systemDriveLetter -ErrorAction Stop
        $diskNumber = $partition.DiskNumber
        $systemDisk = Get-PhysicalDisk -DeviceNumber $diskNumber -ErrorAction Stop
        $diskType = $systemDisk.MediaType
        $defragService = Get-Service -Name "defragsvc" -ErrorAction SilentlyContinue
        if ($defragService -and $defragService.Status -ne 'Running') {
            Add-Log "Sürücü İyileştirme hizmeti (defragsvc) çalışmıyor. Başlatılıyor..." -Level "WARN"
            try {
                Set-Service -Name "defragsvc" -StartupType Manual -ErrorAction Stop
                Start-Service -Name "defragsvc" -ErrorAction Stop
                Add-Log "Sürücü İyileştirme hizmeti başarıyla başlatıldı." -Level "SUCCESS"
            } catch {
                Add-Log "HATA: Sürücü İyileştirme hizmeti başlatılamadı: $($_.Exception.Message)" -Level "ERROR"
                Write-Host "UYARI: Disk optimizasyonu (TRIM/Defrag) yapılamadı çünkü ilgili hizmet başlatılamıyor." -ForegroundColor Yellow
                return
            }
        }
        if ($diskType -eq "SSD") {
            if (Confirm-Action -Prompt "Ana sistem diskiniz SSD olarak algılandı. SSD optimizasyonları uygulansın mı?") {
                Generate-AndApplyTweaks -Category "StorageSsd"
                Add-Log "SSD sürücü için TRIM komutu çalıştırılıyor..." -Level "ACTION"
                Optimize-Volume -DriveLetter $systemDriveLetter -ReTrim -Verbose
            }
        } elseif ($diskType -eq "HDD") {
            if (Confirm-Action -Prompt "Ana sistem diskiniz HDD olarak algılandı. HDD optimizasyonları uygulansın mı?") {
                Generate-AndApplyTweaks -Category "StorageHdd"
                Add-Log "HDD sürücü için birleştirme (defrag) çalıştırılıyor..." -Level "ACTION"
                Optimize-Volume -DriveLetter $systemDriveLetter -Defrag -Verbose
            }
        } else {
             Add-Log "Sistem diski türü belirlenemedi: $diskType" -Level "WARN"
        }
    } catch {
        Add-Log "Depolama türü algılanırken hata oluştu: $($_.Exception.Message)" -Level "ERROR"
    }
}

<#
.SYNOPSIS
    Ekran kartı markasına göre GPU optimizasyonları uygular.
#>
function Manage-GpuOptimizations {
    while ($true) {
        cls
        Write-Host "--- GPU Optimizasyonları ---" -ForegroundColor Yellow
        Write-Host "Lütfen ekran kartı markanızı seçin:" -ForegroundColor Cyan
        Write-Host "1. NVIDIA"; Write-Host "2. AMD"; Write-Host "3. Intel"
        Write-Host "X. Ana Menüye Dön" -ForegroundColor Red
        $choice = Read-Host "`nSeçiminiz"
        switch ($choice) {
            "1" { if (Confirm-Action -Prompt "NVIDIA optimizasyonları uygulanacak.") { Generate-AndApplyTweaks -Category "GpuNvidia" }; break }
            "2" { if (Confirm-Action -Prompt "AMD optimizasyonları uygulanacak.") { Generate-AndApplyTweaks -Category "GpuAmd" }; break }
            "3" { if (Confirm-Action -Prompt "Intel Dahili Grafik optimizasyonları uygulanacak.") { Generate-AndApplyTweaks -Category "GpuIntel" }; break }
            "X" { return }
            default { Add-Log "Geçersiz GPU seçimi: $choice" -Level "WARN" }
        }
    }
}

<#
.SYNOPSIS
    Sanal Bellek (Pagefile) ayarlarını RAM miktarına göre otomatik olarak yapılandırır. (REGISTRY METODU - NİHAİ DÜZELTME v5)
#>
function Manage-VirtualMemory {
    if (-not (Confirm-Action -Prompt "Sanal Bellek (Pagefile) ayarları RAM miktarınıza göre otomatik olarak yapılandırılacak. Bu işlem yeniden başlatma gerektirir.")) { return }

    Add-Log "Sanal Bellek (Pagefile) ayarları optimize ediliyor..." -Level "INFO"
    try {
        # Otomatik yönetimi devre dışı bırak
        wmic computersystem where name="%COMPUTERNAME%" set AutomaticManagedPagefile=false | Out-Null
        Add-Log "Otomatik Sanal Bellek yönetimi devre dışı bırakıldı." -Level "SUCCESS"

        # Mevcut pagefile girdisini Kayıt Defteri'nden temizle
        Add-Log "Mevcut Sanal Bellek ayarları Kayıt Defteri'nden temizleniyor..." -Level "DEBUG"
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -ErrorAction SilentlyContinue
        
        # RAM boyutuna göre yeni boyutu hesapla
        $ramGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $pageSize = [uint32]([math]::Round($ramGB * 1.5 * 1024))
        Add-Log "Toplam RAM: $($ramGB) GB. Ayarlanacak Pagefile Boyutu: $($pageSize) MB." -Level "INFO"

        # Yeni değeri doğrudan Kayıt Defteri'ne yaz
        $pageFilePath = "$($env:SystemDrive)\pagefile.sys"
        $regValue = "$pageFilePath $pageSize $pageSize"
        
        Add-Log "Sanal Bellek Kayıt Defteri'ne yazılıyor: $regValue" -Level "ACTION"
        Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value $regValue -Type "MultiString"

        Write-Host "Sanal Bellek ayarları güncellendi. Değişikliklerin tam olarak uygulanması için bilgisayarınızı yeniden başlatmanız GEREKİR." -ForegroundColor Green
        Add-Log "Sanal Bellek işlemi başarıyla tamamlandı, yeniden başlatma bekleniyor." -Level "SUCCESS"

    } catch {
        Add-Log "Sanal Bellek ayarlanırken bir hata oluştu: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "HATA: Sanal bellek ayarlanamadı. Lütfen yönetici haklarıyla çalıştığınızdan emin olun." -ForegroundColor Red
    }
}


<#
.SYNOPSIS
    Gecikme azaltmak için belirli sistem aygıtlarını devre dışı bırakır.
#>
function Disable-SpecificDevices {
    if (Confirm-Action -Prompt "UYARI: Bu işlem HPET ve bazı sanal sistem aygıtlarını devre dışı bırakacaktır. Bu, bazı durumlarda performansı artırabilir ancak nadiren de olsa sistem kararlılığını etkileyebilir. Ne yaptığınızdan emin değilseniz devam ETMEYİN." -Challenge "AYGIT") {
        Add-Log "Belirli sistem aygıtları devre dışı bırakılıyor..." -Level "ACTION"
        $devicePatterns = @( "Yüksek duyarlıklı olay süreölçeri", "Microsoft Sanal Sürücü Listeleyicisi", "NDIS Sanal Ağ Bağdaştırıcısı Numaralandırıcısı", "Remote Desktop Device Redirector Bus" )
        foreach ($pattern in $devicePatterns) {
            try {
                $devices = Get-PnpDevice -FriendlyName "*$pattern*" -Status OK -ErrorAction SilentlyContinue
                if ($devices) {
                    foreach($device in $devices){
                        Add-Log "'$($device.FriendlyName)' aygıtı bulundu ve devre dışı bırakılıyor..." -Level "INFO"
                        Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
                        Add-Log "'$($device.FriendlyName)' aygıtı başarıyla devre dışı bırakıldı." -Level "SUCCESS"
                    }
                } else {
                    Add-Log "'$pattern' ile eşleşen etkin bir aygıt bulunamadı veya zaten devre dışı." -Level "WARN"
                }
            } catch {
                 Add-Log "'$pattern' aygıtı işlenirken HATA oluştu: $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
}

<#
.SYNOPSIS
    Modules klasöründeki Nvidia Profile Inspector (NVPI) profillerini (.nip) listeleyerek seçilen profili içe aktarır.
#>
function Import-NvidiaProfile {
    Add-Log "NVIDIA Profil Yükleme modülü başlatıldı." -Level "ACTION"
    $modulesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
    $nvpiExePath = Join-Path -Path $modulesDir -ChildPath "nvidiaProfileInspector.exe"
    if (-not (Test-Path $nvpiExePath)) {
        Write-Host "HATA: 'nvidiaProfileInspector.exe' dosyası '$modulesDir' klasöründe bulunamadı." -ForegroundColor Red; return
    }
    $nipFiles = Get-ChildItem -Path $modulesDir -Filter "*.nip"
    if ($nipFiles.Count -eq 0) {
        Write-Host "HATA: '$modulesDir' klasöründe içe aktarılacak bir .nip profili bulunamadı." -ForegroundColor Red; return
    }
    $descriptions = @{ "20 ve 10 serisi.nip" = "(NVIDIA 1000 ve 2000 serisi kartlar için genel optimizasyonlar)"; "30 ve 40 serisi.nip" = "(NVIDIA 3000 ve 4000 serisi kartlar için genel optimizasyonlar)"; "CS2.nip" = "(Counter-Strike 2 için özel oyun ayarları)" }
    cls
    Write-Host "--- İçe Aktarılacak NVIDIA Profilini Seçin ---" -ForegroundColor Yellow
    for ($i = 0; $i -lt $nipFiles.Count; $i++) {
        $file = $nipFiles[$i]; $description = $descriptions[$file.Name]
        $line = " {0,2} - {1,-25} {2}" -f ($i + 1), $file.Name, $description; Write-Host $line -ForegroundColor DarkCyan
    }
    $choice = Read-Host "`nLütfen uygulamak istediğiniz profilin numarasını girin"
    if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $nipFiles.Count)) {
        $selectedIndex = [int]$choice - 1; $selectedNipFile = $nipFiles[$selectedIndex]; $nipFilePath = $selectedNipFile.FullName
        if (Confirm-Action -Prompt "UYARI: Bu işlem, '$($selectedNipFile.Name)' profilini içe aktaracak ve mevcut NVIDIA 3D ayarlarınızın ÜZERİNE YAZACAKTIR." -Challenge "NVIDIA") {
            Add-Log "'$($selectedNipFile.Name)' profili içe aktarılıyor..." -Level "ACTION"
            try {
                $arguments = "-import `"$nipFilePath`""
                Start-Process -FilePath $nvpiExePath -ArgumentList $arguments -Wait -Verb RunAs
                Add-Log "Profil başarıyla içe aktarıldı." -Level "SUCCESS"
            } catch { Add-Log "Profil içe aktarılırken hata oluştu: $_" -Level "ERROR" }
        }
    } else { Write-Host "Geçersiz seçim." -ForegroundColor Red; Add-Log "Geçersiz profil seçimi: $choice" -Level "WARN" }
}
#endregion
