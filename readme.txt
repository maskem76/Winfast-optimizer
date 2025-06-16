# WinFast - Windows Optimizasyon ve Uygulama Yönetim Betiği

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/maskem76/Winfast-optimizer?style=flat-square)](https://github.com/maskem76/Winfast-optimizer/releases/latest)
[![GitHub last commit](https://img.shields.io/github/last-commit/maskem76/Winfast-optimizer?style=flat-square)](https://github.com/maskem76/Winfast-optimizer/commits/main)
[![License](https://img.shields.io/github/license/maskem76/Winfast-optimizer?style=flat-square)](https://github.com/maskem76/Winfast-optimizer/blob/main/LICENSE)

## Hakkında

**WinFast**, Windows işletim sisteminizi baştan aşağı optimize etmek, gereksiz yüklerden arındırmak ve uygulama yönetimini kolaylaştırmak için tasarlanmış, güçlü ve interaktif bir PowerShell betiğidir. Performans artışı, sistem kararlılığı ve kullanıcı deneyimi odaklı geliştirilmiştir. Tüm ayarlar ve değişiklikler **tamamen geri alınabilir** özelliktedir.

## Özellikler

* **Derinlemesine Sistem Optimizasyonu:** Telemetriyi kapatma, gizlilik ayarları, ağ gecikmelerini azaltma, görsel efektleri optimize etme, arka plan uygulamalarını yönetme ve daha fazlası.
* **Kapsamlı Yedekleme ve Geri Alma:** Sistem geri yükleme noktası oluşturma, kayıt defteri yedekleme, özel Windows WIM/ESD görüntüsü alma ve yedekten önyüklenebilir ISO oluşturma yeteneği. Yapılan tüm değişiklikler için otomatik geri alma betikleri oluşturulur.
* **Gelişmiş Uygulama Yükleyici (Hibrit Sistem):**
    * **Winget Entegrasyonu:** Windows Paket Yöneticisi (Winget) üzerinden yüzlerce popüler uygulamayı tek tuşla kurma imkanı.
    * **Katılımsız (Yerel) Kurulum Desteği:** Kendi `Installers` klasörünüze eklediğiniz `.exe`, `.msi` veya `.zip` uzantılı katılımsız programları otomatik olarak algılar, menüde listeler ve tek komutla kurar. Parametreleri tahmin etme özelliği sayesinde kolay kullanım sunar.
* **Kişiselleştirme ve Yönetim:** Güç planı optimizasyonları, başlangıç uygulaması yönetimi, sistem temizliği ve çok daha fazlası.
* **Güvenlik Odaklı:** Hassas işlemler için onay ister ve yönetici hakları gerektirir.

## Kurulum ve Kullanım

### Projeyi İndirme

1.  Bu GitHub deposunu bilgisayarınıza indirin. En güncel sürümü edinmek için "Code" butonuna tıklayıp "Download ZIP" seçeneğini kullanabilirsiniz.
2.  İndirdiğiniz ZIP dosyasını bilgisayarınızda istediğiniz bir konuma (örneğin `C:\WinFast` veya masaüstünüzde bir klasöre) çıkarın. Klasör yapısının bozulmadığından emin olun:

    ```
    WinFastProjesi/
    ├── WinFast.ps1
    ├── Data/
    │   └── Applications.json
    ├── Installers/
    ├── Modules/
    │   ├── AppInstaller.psm1
    │   ├── CoreFunctions.ps1
    │   ├── UtilityFunctions.ps1
    │   └── ... (diğer modüller ve NSudo.exe, oscdimg.exe, wimlib-imagex.exe)
    ├── Logs/
    ├── UndoScripts/
    ├── RegistryTweaks.json
    └── ... (diğer dosyalar/klasörler)
    ```

### WinFast'ı Çalıştırma

1.  İndirdiğiniz `WinFastProjesi` klasörüne gidin.
2.  `WinFast.ps1` dosyasına **sağ tıklayın** ve **"PowerShell ile Çalıştır"** seçeneğini seçin.
    * **ÖNEMLİ:** Eğer bu seçenek yoksa veya betik açılıp hemen kapanıyorsa:
        * Windows Arama Çubuğu'na `powershell` yazın.
        * "Windows PowerShell" veya "PowerShell" uygulamasına **sağ tıklayın** ve **"Yönetici olarak çalıştır"** seçeneğini seçin.
        * Açılan PowerShell penceresinde, `WinFast.ps1` dosyanızın bulunduğu klasöre `cd` komutu ile gidin. Örneğin:
            ```powershell
            cd C:\Users\KULLANICI_ADINIZ\Desktop\WiNFaST\ # Kendi yolunuzu buraya yazın
            ```
        * Ardından betiği çalıştırın:
            ```powershell
            .\WinFast.ps1
            ```
3.  Betiğin çalışması için yönetici izinleri gereklidir. Açılan onay penceresine "Evet" deyin.
4.  WinFast'ın ana menüsü ekrana gelecektir.

### Uygulama Yükleyiciyi Kullanma (Özellikle Katılımsız Programlar İçin)

WinFast'ın en kullanışlı özelliklerinden biri olan Hibrit Uygulama Yükleyici'yi kullanmak için:

1.  WinFast ana menüsünden **`6`** numaralı seçeneği seçerek "Uygulama Yükleyici" menüsüne girin.
2.  Bu menü, hem Winget üzerinden kurabileceğiniz uygulamaları hem de `Installers` klasörünüze eklediğiniz yerel (katılımsız) programları listeleyecektir.

#### Katılımsız Programlarınızı Ekleme

WinFast'ın otomatik olarak algılayıp listeleyebilmesi için katılımsız programlarınızı şu adımlarla ekleyin:

1.  **`WinFastProjesi`** ana klasörünüzün içinde bulunan **`Installers`** klasörüne gidin.
2.  Kurmak istediğiniz katılımsız `.exe`, `.msi` veya `.zip` dosyalarını bu klasörün içine kopyalayın.
    * **Örnek:** `7z2405-x64.exe`, `VSCodeUserSetup-x64.exe`, `MyCustomAppSetup.msi`
3.  WinFast'ı tekrar çalıştırın ve 6. Uygulama Yükleyici menüsüne girdiğinizde, `Installers` klasörüne eklediğiniz programların otomatik olarak listede göründüğünü fark edeceksiniz (genellikle `[local]` etiketiyle).
4.  Programları seçerek (örn. `1,5,7` veya `T` ile tümünü) kurulumu başlatabilirsiniz.

**Önemli Notlar:**

* **Katılımsız Parametreler:** WinFast, çoğu `.exe` ve `.msi` dosyası için yaygın katılımsız parametreleri (`/S`, `/quiet`, `-s` vb.) otomatik olarak denemeye çalışır. Ancak bazı özel uygulamalar farklı parametreler gerektirebilir veya katılımsız kurulumu hiç desteklemeyebilir.
* **ZIP Dosyaları:** `.zip` dosyaları listelenir, ancak doğrudan kurulamazlar. WinFast, ZIP dosyası seçildiğinde sizi uyaracaktır, çünkü bunların manuel olarak çıkarılması ve içerisindeki kurulum dosyasının çalıştırılması gerekir.
* **Log Kontrolü:** Kurulumlarda bir sorun yaşarsanız, `WinFastProjesi\Logs` klasöründeki log dosyalarını kontrol ederek detaylı hata mesajlarını görebilirsiniz.

## Katkıda Bulunma

WinFast projesi açık kaynaklıdır ve katkılarınıza açıktır! Her türlü geri bildirim, hata raporu veya kod katkısı memnuniyetle karşılanır.

## Lisans

Bu proje [Lisans Türü - örn: MIT Lisansı] ile lisanslanmıştır. Daha fazla bilgi için [LICENSE](LICENSE) dosyasına bakınız.

---

**Yapılması Gerekenler:**

1.  `SENIN_GITHUB_KULLANICI_ADIN` ve `SENIN_REPO_ADIN` yerlerini kendi GitHub kullanıcı adınız ve projenizin adı ile değiştirin.
2.  `[Lisans Türü - örn: MIT Lisansı]` yerine kullandığınız lisans türünü yazın. Eğer bir lisans dosyanız yoksa (LICENSE.md), onu da oluşturmayı düşünebilirsiniz. MIT Lisansı basit ve yaygın bir seçenektir.
3.  Projenizin `LICENSE` dosyasını da GitHub deponuzda bulundurun.
4.  İsterseniz `Hakkında` ve `Özellikler` bölümlerine projenizin ekran görüntülerini veya kısa GIF'lerini ekleyerek daha görsel hale getirebilirsiniz.

Bu `README.md` dosyası, kullanıcılarınıza projenizi tanıtmak ve nasıl kullanacaklarını açıklamak için iyi bir başlangıç noktası olacaktır.