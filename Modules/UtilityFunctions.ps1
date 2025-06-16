# WinFastProjesi\Modules\UtilityFunctions.ps1
# =====================================================================
#             GENEL YARDIMCI FONKSİYONLAR
# =====================================================================

<#
.SYNOPSIS
    Bir işlemin başarıyla tamamlandığını gösteren log mesajı yazar ve kısa bir süre bekler.
.DESCRIPTION
    Bu fonksiyon, kullanıcının bir işlemin başarıyla bittiğini anlaması için görsel ve metinsel geri bildirim sağlar.
    'SUCCESS' seviyesinde loglama yapar.
.EXAMPLE
    Show-ProcessCompleted
#>
function Show-ProcessCompleted {
    Add-Log "İşlem başarıyla tamamlandı." -Level "SUCCESS"
    Start-Sleep -Seconds 1
}

<#
.SYNOPSIS
    Kullanıcıdan kritik bir işlem için onay ister.
.DESCRIPTION
    Bu fonksiyon, belirli bir eylemi gerçekleştirmeden önce kullanıcıdan yazılı bir onay (EVET veya özel bir kelime) alır.
    Riskli işlemlerde yanlışlıkla onayı engellemek için 'meydan okuma' (challenge) parametresi kullanılabilir.
.PARAMETER Prompt
    Kullanıcıya gösterilecek onay mesajı.
.PARAMETER Challenge
    Kullanıcının girmesi gereken özel kelime (örn: "KAPAT"). Boş bırakılırsa "EVET" beklenir.
.EXAMPLE
    if (Confirm-Action -Prompt "Sistemi kapatmak istediğinize emin misiniz?") { # İşlem... }
.EXAMPLE
    if (Confirm-Action -Prompt "Defender'ı devre dışı bırakılacak!" -Challenge "DEFENDERI_KAPAT") { # İşlem... }
#>
function Confirm-Action {
    param ([string]$Prompt, [string]$Challenge)
    Add-Log -Message "Kullanıcı onayı isteniyor: $Prompt" -Level "ACTION"
    Write-Host $Prompt -ForegroundColor Yellow 

    $confirmationPrompt = "Lütfen devam etmek için"
    if ($Challenge) {
        $confirmationPrompt += " '$Challenge' yazın"
    } else {
        $confirmationPrompt += " 'EVET' yazın"
    }
    
    $confirmation = Read-Host "$confirmationPrompt"
    
    $expectedResponse = if ($Challenge) { $Challenge } else { "EVET" }

    if ($confirmation.ToUpperInvariant() -eq $expectedResponse.ToUpperInvariant()) { 
        Add-Log "Kullanıcı '$expectedResponse' yazarak onayladı." -Level "INFO"
        return $true
    } else {
        Add-Log "Kullanıcı işlemi iptal etti." -Level "WARN"
        Write-Host "İşlem kullanıcı tarafından iptal edildi." -ForegroundColor Red 
        return $false
    }
}

<#
.SYNOPSIS
    Belirtilen JSON dosyasından uygulama veya ayar listelerini okur.
    Hem kök seviyesinde dizi hem de "Applications" veya başka bir anahtar altında dizi olan JSON'ları destekler.
.PARAMETER JsonPath
    Okunacak JSON dosyasının tam yolu.
.PARAMETER RootKey
    JSON'un içindeki listenin kök anahtarı (örn: "Applications", "Tweaks"). Boş bırakılırsa kök dizi aranır.
#>
function Get-WinFastJsonList {
    param(
        [string]$JsonPath,
        [string]$RootKey = "" # Yeni parametre: JSON içindeki listenin ana anahtarı
    )

    Add-Log "JSON dosyası okunuyor: $JsonPath (Kök Anahtar: '$RootKey')" -Level "INFO"

    if (-not (Test-Path $JsonPath)) {
        Add-Log "HATA: JSON dosyası bulunamadı. Boş bir liste döndürülüyor: $JsonPath" -Level "ERROR"
        Write-Host "HATA: Uygulama listesi JSON dosyası bulunamadı: '$JsonPath'" -ForegroundColor Red
        return @() # Dosya yoksa boş bir dizi döndür
    }

    try {
        $content = Get-Content -Path $JsonPath -Raw -Encoding utf8
        Add-Log "DEBUG: JSON dosyasının ham içeriği okundu (uzunluk: $($content.Length))." -Level "DEBUG"
        # >>> ÖNEMLİ HATA AYIKLAMA: Ham JSON içeriğini doğrudan loga bas <<<<<<
        Add-Log "DEBUG: Ham JSON İçeriği (İlk 500 Karakter):`n$($content.Substring(0, [System.Math]::Min(500, $content.Length)))" -Level "DEBUG"
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            Add-Log "UYARI: JSON dosyası boş veya sadece boşluk karakterleri içeriyor. Boş liste döndürülüyor: $JsonPath" -Level "WARNING"
            Write-Host "UYARI: Uygulama listesi JSON dosyası boş." -ForegroundColor Yellow
            return @()
        }

        $jsonParsed = $null
        try {
            $jsonParsed = $content | ConvertFrom-Json -ErrorAction Stop
            Add-Log "DEBUG: JSON içeriği ConvertFrom-Json ile objeye dönüştürüldü. Obje türü: $($jsonParsed.GetType().Name)." -Level "DEBUG"
        } catch {
            Add-Log "KRİTİK HATA: ConvertFrom-Json sırasında hata oluştu: $($_.Exception.Message). Ham içerik uzunluğu: $($content.Length)." -Level "ERROR"
            Write-Host "KRİTİK HATA: JSON dosyası işlenemiyor (format hatası): $($_.Exception.Message)" -ForegroundColor Red
            return @()
        }

        if ([string]::IsNullOrEmpty($RootKey)) { # Kök anahtar belirtilmediyse (doğrudan dizi bekleniyorsa)
            if ($jsonParsed -is [System.Array]) {
                Add-Log "BİLGİ: JSON kök seviyesinde bir dizi olarak algılandı. Dizi boyutu: $($jsonParsed.Count)." -Level "INFO"
                return $jsonParsed
            } else {
                Add-Log "HATA: RootKey belirtilmedi ancak JSON kök seviyesinde dizi değil. Obje türü: $($jsonParsed.GetType().Name). Boş liste döndürülüyor." -Level "ERROR"
                Write-Host "HATA: JSON dosyası beklenen formatta değil (kök dizi beklenirken)." -ForegroundColor Red
                return @()
            }
        }
        else { # Kök anahtar belirtildiyse
            if ($jsonParsed -is [System.Management.Automation.PSObject] -and $jsonParsed | Get-Member -MemberType Property -Name $RootKey -ErrorAction SilentlyContinue) {
                $targetProperty = $jsonParsed.$RootKey
                if ($targetProperty -is [System.Array]) {
                    Add-Log "BİLGİ: JSON '$RootKey' anahtarı altında bir dizi olarak algılandı. Dizi boyutu: $($targetProperty.Count)." -Level "INFO"
                    return $targetProperty
                } else {
                    Add-Log "HATA: '$RootKey' özelliği bulundu ancak bir dizi değil. Tipi: $($targetProperty.GetType().Name). Boş liste döndürülüyor." -Level "ERROR"
                    Write-Host "HATA: JSON dosyasındaki '$RootKey' bölümü hatalı formatta (dizi değil)." -ForegroundColor Red
                    return @()
                }
            } else {
                Add-Log "HATA: JSON beklenilen '$RootKey' anahtarını içermiyor veya beklenmedik formatta. Obje türü: $($jsonParsed.GetType().Name)." -Level "ERROR"
                Write-Host "HATA: Uygulama listesi JSON dosyası beklenmedik bir formatta veya '$RootKey' anahtarı eksik." -ForegroundColor Red
                return @()
            }
        }
    } catch {
        Add-Log "KRİTİK HATA: JSON dosyası okunurken genel bir hata oluştu: $($_.Exception.Message). Boş bir liste döndürülüyor." -Level "ERROR"
        Write-Host "KRİTİK HATA: Uygulama listesi JSON dosyası işlenirken genel hata: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

<#
.SYNOPSIS
    Belirtilen listeyi belirtilen JSON dosyasına belirli bir kök anahtar altında yazar.
.PARAMETER DataList
    Yazılacak veri objelerinin listesi (dizi).
.PARAMETER JsonPath
    Yazılacak JSON dosyasının tam yolu.
.PARAMETER RootKey
    JSON'a yazılırken listenin sarılacağı kök anahtar (örn: "Applications", "Tweaks"). Boş bırakılırsa doğrudan dizi olarak yazılır.
#>
function Set-WinFastJsonList {
    param(
        [array]$DataList,
        [string]$JsonPath,
        [string]$RootKey = "" # Yeni parametre: JSON'a yazılacak kök anahtar
    )
    try {
        $contentToWrite = $DataList
        if (-not ([string]::IsNullOrEmpty($RootKey))) {
            $contentToWrite = @{ $RootKey = $DataList }
        }
        
        $contentToWrite | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $JsonPath -Encoding utf8
        Add-Log "Liste JSON dosyasına başarıyla kaydedildi: $JsonPath (Kök Anahtar: '$RootKey')" -Level "SUCCESS"
        return $true
    } catch {
        Add-Log "HATA: Liste JSON dosyasına kaydedilemedi: $JsonPath - Hata: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "UYARI: Liste kaydedilemedi! Bir sorun oluştu." -ForegroundColor Yellow
        return $false
    }
}