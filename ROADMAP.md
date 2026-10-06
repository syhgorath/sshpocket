# Yol haritası / Roadmap

Sıra bağlayıcı değildir; fikir ve PR'lara açıktır.

## Planlanan

### Taşınabilirlik (Linux)
Şu an yalnızca macOS: `security` (Keychain), `osascript` (Terminal), `diskutil` (eject) kullanılıyor.
- Gizli bilgi deposu soyutlaması: macOS Keychain / `secret-tool` (libsecret) / `pass`.
- Terminal açma soyutlaması: `osascript` / `gnome-terminal` / `x-terminal-emulator` / aynı pencere.
- Eject soyutlaması: `diskutil` / `udisksctl`.
- CI'da Linux üzerinde de tüm testlerin çalışması (Bats testleri zaten Linux'ta koşuyor; sahte komutlar eklenecek).

### Güvenlik
- Hardware key desteği (YubiKey, `ed25519-sk`).
- Log'larda IP/kullanıcı yazmayı kapatma seçeneği.
- USB şifreleme rehberi.

### Kullanışlılık
- Menüde arama / kısayol tuşları.
- ProxyJump/bastion, SSH tüneli, `scp`/`sftp` kısayolları.
- Arayüz metinlerinin çevirisi (i18n); şu an Türkçe.
- `~/.ssh/config`'te `Include` desteği.

### Dağıtım
- Homebrew formülü / kurulum betiği.
- Demo GIF'i.

## Tamamlananlar
Bkz. [CHANGELOG.md](CHANGELOG.md).
