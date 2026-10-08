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

### Güncelleme kontrolü (`--update`) — sunucu denemesi ve ilk release'ten sonra
Otomatik değil, kullanıcı başlatır ("Güncelle" menüsü veya `./start.sh --update`):
- Yalnızca bu reponun GitHub Release'leri, yalnızca HTTPS; yeni sürümse değişiklik listesini gösterip onay ister.
- **İmzalı sürüm:** release arşivi `ssh-keygen -Y sign` ile imzalanır, kurulu kopyadaki gömülü public key ile
  `ssh-keygen -Y verify` doğrular. Yalnızca checksum yetmez (hesap ele geçirilirse ikisi birden değişir).
- Kullanıcı verisine (`Modules/` altındaki modüller, `.env`, key'ler) dokunmaz; atomik değiştirir, yedek alır, hata olursa geri döner.
- Sürüm düşürmeyi (downgrade) reddeder; açılışta otomatik ağ çağrısı yapmaz.
- Önkoşullar: `VERSION` dosyası, `v2.0.0` etiketi/release, imza anahtarı, CI'da imzalı release üretimi.
- İdeal olarak kod ve kullanıcı verisinin klasör olarak ayrılması (Homebrew paketi için de gerekli).

### Dağıtım
- Homebrew formülü / kurulum betiği.
- Demo GIF'i.

## Tamamlananlar
Bkz. [CHANGELOG.md](CHANGELOG.md).
