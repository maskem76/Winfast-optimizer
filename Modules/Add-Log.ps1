<#
.SYNOPSIS
    Belirtilen mesajı konsola yazdırır ve log dosyasına kaydeder.
.DESCRIPTION
    Bu fonksiyon, betiğin çalışması sırasında oluşan olayları, uyarıları, hataları ve başarı mesajlarını
    hem PowerShell konsolunda renklendirilmiş olarak gösterir hem de belirtilen global log dosyasına yazar.
    Bu, hata ayıklama ve betik aktivitesini izleme için kritik öneme sahiptir.
.PARAMETER Message
    Loglanacak metin mesajı.
.PARAMETER Level
    Log seviyesi (INFO, WARN, ERROR, ACTION, SUCCESS, DEBUG).
    Varsayılan değer 'INFO'dur.
.EXAMPLE
    Add-Log "İşlem başlatıldı." -Level "ACTION"
.EXAMPLE
    Add-Log "Hata oluştu: Dosya bulunamadı." -Level "ERROR"
.NOTES
    Log dosyası, betiğin çalıştığı klasördeki 'Logs' dizininde bulunur.
#>
function Add-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, ACTION, SUCCESS, DEBUG
    )
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] - $Message"

    $colorMap = @{
        INFO    = "Gray";
        WARN    = "Yellow";
        ERROR   = "Red";
        ACTION  = "Magenta";
        SUCCESS = "Green"; 
        DEBUG   = "DarkGray" 
    }

    $consoleColor = if ($colorMap.ContainsKey($Level)) { $colorMap[$Level] } else { "White" }

    Write-Host $logEntry -ForegroundColor $consoleColor -ErrorAction SilentlyContinue

    if ($Global:LogFile) {
        try {
            Add-Content -Path $Global:LogFile -Value $logEntry -Encoding utf8 -ErrorAction SilentlyContinue
        } catch {
            Write-Host "UYARI: Log dosyasına yazılırken hata: $($_.Exception.Message)" -ForegroundColor DarkYellow -ErrorAction SilentlyContinue
        }
    }
}