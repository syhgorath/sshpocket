# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

### Eklendi
- Ana menüde yerleşik eylemler: yeni sunucu ekle, `~/.ssh/config`'ten içe aktar, sunucuları yönet.
  Eklenen/silinen modüller yeniden başlatmadan menüye yansır.

### Düzeltildi
- `--auto` modu artık yerleşik eylemleri atlayıp ilk sunucuyu çalıştırır.

## [2.0.0] - 2026-10-06

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
