# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

### Eklendi
- **Aşama 1.0/1.1 (`servers/` veri katmanı, geriye uyumlu):** menü artık `servers/<ad>/server.env` (genel anahtarlar `IP`, `USER`, `PORT`, `KEY`, `OS`)
  klasörlerinden de kurulur; sunucu başına üretilmiş bash dosyası gerekmez. **Eski `sistem/Modules/<ad>/.env` biçimi aynen çalışmaya devam eder**
  (taşıma sonraki adımdır). Tek erişim katmanı `srv_get/srv_set` biçimi korur. Aynı adlı eski modül varsa yeni biçim kazanır.
- `servers/` içindeki hiçbir dosya `source` edilmez (güvenlik testleri); gizli klasörler, `._*` ve geçersiz adlar yok sayılır.
- Güncelleyici `servers/` klasörüne asla dokunmaz (arşivde olsa bile); release paketine `servers/` dahil edilmez.
- **Aşama 1.2 (taşıma):** `./start.sh --migrate [--dry-run] [--yes]` ve etkileşimli açılışta (yalnızca terminalde, onaysız asla) teklif.
  Eski `sistem/Modules/<ad>/` → `servers/<ad>/`: ayarlar genel anahtarlara çevrilir, key'ler kopyalanır ve **bayt bayt doğrulanır**,
  izinler 600/700, üretilmiş modül dosyaları taşınmaz. **Hiçbir şey silinmez:** eski klasörler `servers/.migrated-<tarih>/` altına alınır;
  hata olursa o sunucunun eski klasörü olduğu gibi kalır, yarım klasör bırakılmaz. İdempotent. Keychain'e dokunulmaz (passphrase'ler aynen geçerli).
- **Aşama 1.3 (yeni biçime yazma):** `ModuleGenerator.sh`, `ImportSSHConfig.sh` ve menüdeki "Yeni sunucu ekle / içe aktar" artık
  `servers/<ad>/server.env` yazar (genel anahtarlar; **sunucu başına üretilmiş bash dosyası yok**, `.env.example` yok).
  `ModuleManager.sh`: `list` yeni ve eski biçimi (etiketle), `remove` ikisini de, `rename` yeni biçimi (klasör + key dosyaları; eski
  biçim için "önce `--migrate`" der) yönetir. Aynı ad hem `servers/` hem eski `Modules/`'te varsa oluşturma/içe aktarma reddedilir.
- **CI'a macOS işi:** `macos-latest` (Apple Silicon arm64, macOS 26.6.2) üzerinde macOS'un kendi bash 3.2'siyle ShellCheck + tüm testler. Bu sırada bulunan
  bir test aracı sorunu (bash 3.2 + UTF-8 yereli, Türkçe test adlarını yanlış kodluyor) `LC_ALL=C` ile giderildi. Keychain izin penceresi ve Terminal
  açma otomatik sınanmaz (testler sahte `security` kullanır).
- **Aşama 1.4 (sadeleşme):** gönderilen `sistem/Modules/example/` modülü kaldırıldı; yerine `sistem/templates/server.env.example` şablonu geldi
  (menüde artık boş bir "EXAMPLE" girdisi çıkmaz; sunucu eklemek için "Yeni sunucu ekle"). Güncelleyici sadeleşti: kod (`sistem/*.sh`, `Helpers`,
  `templates`) bütünüyle değişir; **`sistem/Modules/` (henüz taşınmamış eski sunucular) ve `servers/` asla silinmez/ezilmez**. Eski sürümlerden kalan,
  hiç yapılandırılmamış `example` şablonu güncellemede güvenle temizlenir (içinde `.env`/key/başka dosya varsa dokunulmaz). Taşıma, `.env`'i olan
  `example`'ı da (gerçek sunucu olarak) taşır. Eski `Modules/` klasörü yoksa artık uyarı verilmez.

### Belge
- Tasarım kararları işlendi: durum göstergesi varsayılan açık, `⚙️ Ayarlar` paneli (5 ayar, `sshpocket.conf`), `q` geri, fzf USB'ye gömülür (yedekli), klasik port knocking için pre-connect kancası (`docs/ui-design.md`, `docs/components-design.md` §6.7).
- `docs/ui-design.md`: arayüz ilkeleri, fzf dağıtım politikası, Apple Silicon doğrulama listesi ve teknoloji alternatifleri (tasarım, kod yok).
- README: "Test edilen ortamlar" tablosu. Yalnızca Intel + macOS 15.7.9'da denendi; Apple Silicon ve daha yeni macOS **denenmedi**.

### Belge
- `docs/components-design.md`: `servers/` veri ayrımı ve bileşen modeli için tasarım (henüz uygulanmadı); linux-hardening PR sırası incelemeyle güncellendi (A → 0a → 0b → 0c → B → D → C).
- Tasarım belgesi, linux-hardening'in gerçek `component.yml`'ine hizalandı (issue #2): `invoke.append` nesne listesi, `inventory_group`, `outputs`, `hardening_scan_dir`, principal=ad alanı.
- Tasarım belgesi, linux-hardening v0.1.0'ın geri alma güvenlik ağına hizalandı (issue #3): `rollback_status/disarm/now`, `hardening_rollback_*` değişkenleri, arayüz notları.

### Eklendi
- Dependabot yapılandırması (aylık, yalnızca GitHub Actions bağımlılıkları).

## [2.2.0] - 2026-10-08

### Eklendi
- **İmzalı güncelleme:** `./start.sh --update` / `--check-update` ve menüde "Güncelle". Yalnızca bakımcının imza
  anahtarıyla imzalı (`ssh-keygen -Y verify`), HTTPS ile inen Release paketini kurar; imza yoksa/anahtar tanımlı
  değilse kapalıdır. Geri sürüme düşmez, tehlikeli arşivleri (`..`, mutlak yol, symlink) reddeder, kullanıcı
  verisini korur, yedek alır ve hata olursa geri yükler.
- `scripts/release.sh` (imzalı paket üretir ve yayından önce doğrular) ve `RELEASING.md` (bakımcı rehberi).
- `.gitattributes` ile release paketine `test/`, `scripts/`, `.github/` girmez.
- Depo hijyeni testleri: `release_signers` biçimi ve repoda özel anahtar/sır dosyası bulunmaması.

> Güncelleyici bu sürümle gelir; v2.1.0 ve öncesi kopyalar bir kez elle güncellenmelidir.

## [2.1.0] - 2026-10-08

> İlk yayın. `2.0.0` hiç yayınlanmadığı için bu sürüm, aşağıdaki `2.0.0` bölümündeki her şeyi de içerir.

### Eklendi
- Sürüm tek yerde (`VERSION`); `sistem/Main.sh --version` / `./start.sh --version` sürümü yazar.
- Uçtan uca testler (`test/e2e/`): Docker'da yerel Ubuntu `sshd` ile `ssh-copy-id`, elle ekleme komutu, root reddi ve durum göstergesi gerçek sunucuya karşı denenir.
- `ssh-copy-id` başarısız olursa olası nedenler ve sunucuda çalıştırılacak **tek satırlık elle ekleme komutu** gösterilir
  (komut tekrar çalıştırılabilir, mevcut key'leri korur). Kullanıcı `root` ise Ubuntu/Debian uyarısı verilir.
- Modül menüsünde **Bilgileri güncelle** (IP/kullanıcı/port/key yolu) ve **Keychain passphrase'ini güncelle/sil**.
  Passphrase kaydedildikten sonra key açılarak doğrulanır. Ayar bozuk veya key eksikken de bu seçenekler çalışır.
- Ana menüde yerleşik eylemler: yeni sunucu ekle, `~/.ssh/config`'ten içe aktar, sunucuları yönet.
  Eklenen/silinen modüller yeniden başlatmadan menüye yansır.

### Düzeltildi
- `--auto` modu artık yerleşik eylemleri atlayıp ilk sunucuyu çalıştırır.

## [2.0.0] - 2026-10-06

> İç dönüm noktası; etiketlenmedi ve yayınlanmadı. İlk yayın: 2.1.0.

### Eklendi
- `~/.ssh/config` içe aktarma (`ImportSSHConfig.sh`); private key'ler kopyalanmaz, `<ÖNEK>_KEY` ile referanslanır.
- `ModuleManager.sh`: `list`, `remove`, `rename`.
- Menüde durum göstergesi (`SSHPOCKET_STATUS=1`): 🟢 / 🔴 / ⚪.
- Public key'i sunucuya gönderme (`ssh-copy-id` akışı), modül menüsünden ve generator'dan.
- `<ÖNEK>_KEY` ile modül klasörü dışındaki mevcut key'i kullanma.
- `start.command` (Finder'dan çift tıkla başlatma).
- 53 Bats testi; GitHub Actions'ta ShellCheck + Bats.
- README (TR/EN), CONTRIBUTING, SECURITY, ROADMAP, issue/PR şablonları.

### Değişti
- Passphrase artık düz metin `.env`'de değil, macOS Keychain'de; `SSH_ASKPASS` ile geçici dosyasız aktarılır.
- Üç kopya modül tek ortak çalıştırıcıya (`Helpers/SSHModule.sh`) indirildi.
- `.env` ayrıştırma saf bash ile yeniden yazıldı (eval yok); satır sonu yorumları desteklenir.
- Host key ilk bağlantıda kullanıcıya sorulur (`accept-new` kaldırıldı); `ssh -v` varsayılan değil.
- `autorun.sh` kaldırıldı (macOS desteklemez); yerine `start.sh`.

### Düzeltildi
- IP/kullanıcı/port doğrulaması; kullanıcı adı `-` ile başlayamaz (ssh seçenek enjeksiyonu).
- Menü, girdi bittiğinde (EOF) sonsuz döngüye giriyordu.
- Generator'daki macOS'ta çalışmayan `sed \U` ve üzerine yazma davranışı.

### Kaldırıldı
- TOTP gizli anahtarları ve parolaların `.env` içinde tutulması.

[Unreleased]: https://github.com/syhgorath/sshpocket/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/syhgorath/sshpocket/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/syhgorath/sshpocket/releases/tag/v2.1.0
