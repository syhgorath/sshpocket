# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

### Belge
- `docs/components-design.md`: `servers/` veri ayrımı ve bileşen modeli için tasarım (henüz uygulanmadı).

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
