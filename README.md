# sshpocket

[![ci](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml/badge.svg)](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

🇹🇷 Türkçe · 🇬🇧 [English](README.en.md)

macOS için, USB bellekten (veya herhangi bir klasörden) çalışan, modüler bir SSH bağlantı menüsü.
Her sunucu bir *modüldür*; modül klasörünü eklediğinizde menüde kendiliğinden görünür.

> **Durum: ham / erken aşama.** 🛠️
> Bu, kişisel bir HomeLab aracından çıkan bir proje. [Claude](https://claude.com/claude-code) ile
> elden geçirildi ve ilk hâline göre epey toparlandı, ama hâlâ geliştirilecek çok yeri var:
> pürüzler, eksik testler ve yazılmamış özellikler olabilir. Sorunlar projenin hamlığından
> kaynaklanır; bunun için kimseye kızmayın 😄 — issue ve PR'larla yardım etmeniz çok makbule geçer.
> Yalnızca macOS'ta denendi. Kendi sunucularınızda kullanmadan önce kodu okuyun;
> kullanım sorumluluğu size aittir (bkz. [LICENSE](LICENSE)).

> **Otomatik başlamaz.** macOS, Linux ve modern Windows USB takılınca script çalıştırmaz (güvenlik gereği).
> Elle başlatın: `./start.sh` ya da Finder'da `start.command` dosyasına çift tıklayın.

## Test edilen ortamlar

| Ortam | Durum |
|---|---|
| **Intel Mac (x86_64), macOS 15.7.9, bash 3.2.57, OpenSSH 9.9p2** | ✅ Geliştirildi ve elle denendi |
| **Apple Silicon (arm64), macOS 26.6.2, bash 3.2.57, OpenSSH 10.3p1 (GitHub Actions)** | ✅ **Otomatik testler** (Bats + ShellCheck, her PR'da). ⚠️ Elle/gerçek denenmedi: Keychain izin penceresi, Terminal açma, `start.command` çift tıklama |
| Ubuntu 24.04 (yalnızca CI: ShellCheck + Bats testleri) | ✅ otomatik |
| Linux üzerinde kullanım (Keychain/`osascript`/`diskutil` yok) | ❌ Desteklenmiyor |
| Hedef sunucu: Ubuntu 26.04.1 (linux-hardening, tek test VM'i) | ✅ sınırlı; rpi/Proxmox profilleri denenmedi |

Apple Silicon'da veya yeni macOS'ta bir sorun görürseniz lütfen issue açın (macOS sürümü, `uname -m` ve `bash --version` çıktısıyla).

## Hızlı başlangıç

```bash
./start.sh                          # menüyü başlat
```

Ana menüden her şey yapılır: sunucuya bağlanma, **➕ Yeni sunucu ekle**,
**📥 ~/.ssh/config'ten içe aktar** ve **🛠️ Sunucuları yönet** (listele/sil/yeniden adlandır).
Aynı işler komut satırından da çalışır:

```bash
bash sistem/ModuleGenerator.sh      # yeni sunucu modülü oluştur
bash sistem/ImportSSHConfig.sh      # ~/.ssh/config'teki sunucuları içe aktar
bash sistem/ModuleManager.sh list   # modülleri listele (remove / rename de var)
```

Generator size IP/kullanıcı/port sorar, isterseniz ed25519 anahtar üretir ve
passphrase'i **macOS Keychain**'e kaydeder.

## Özellikler

- **Modüler:** her sunucu bir klasör; menü kendiliğinden oluşur.
- **Keychain:** passphrase diske yazılmaz.
- **Key'i sunucuya gönderme:** menüden veya generator'dan `ssh-copy-id` (aşağıya bakın).
- **`~/.ssh/config` içe aktarma:** mevcut sunucularınızı tek komutla modüle çevirir. Private key'ler
  **kopyalanmaz**; `IdentityFile` yolu modülün `.env`'ine `<ÖNEK>_KEY` olarak yazılır.
- **Mevcut key kullanımı:** `.env`'e `<ÖNEK>_KEY=/yol/key` yazın (örn. `~/.ssh/id_ed25519`).
- **Durum göstergesi:** menüde 🟢 (port açık) / 🔴 (erişilemiyor) / ⚪ (ayar yok) gösterilir; sunucular paralel kontrol edilir.
  **⚙️ Ayarlar**'dan kapatılabilir/süresi değiştirilebilir (`sshpocket.conf`; ortam değişkeni `SSHPOCKET_STATUS=0|1` önceliklidir).
- **Port knocking (istemci):** sunucu menüsünden **Knock ayarları**; dizi Keychain'de, bağlanmadan önce otomatik gönderilir, durumda 🔒. Sunucu tarafı kurulumu ayrı pakettir.
- **Ok tuşlu menü:** ↑↓ gez · Enter aç · `←`/`q` geri; numara yazmak da çalışır. Sorun olursa ⚙️ Ayarlar'dan `UI=numbers`.
- **Modül menüsü:** Bağlan · Key'i sunucuya gönder · **Bilgileri güncelle** (IP/kullanıcı/port/key yolu) ·
  **Keychain passphrase'ini güncelle/sil** (kayıttan sonra key'i açarak doğrular). Ayar bozuk veya key eksikken de
  güncelleme seçenekleri kullanılabilir.
- **Modül yönetimi:** `ModuleManager.sh list | remove <ad> | rename <eski> <yeni>`.
- **Aynı sunucuya birden çok kullanıcı/key:** her biri ayrı bir modül olur (örn. `web_root`, `web_deploy`).
- **Ayarlar ve ok tuşlu menü:** ⚙️ Ayarlar (`sshpocket.conf`); ↑↓ gez, Enter aç, `q`/`←` geri; sorun olursa `UI=numbers`.
- **`./start.sh --doctor`:** ön koşul denetimi (ssh araçları, Python aralığı, venv, disk, ağ); yalnızca okur, hiçbir şey kurmaz.
- **Paketler (altyapı):** imzalı, kilitli (`components.lock`) paketlerin güvenli kurulumu: `./start.sh --components list|sync|check-new`.
  Kilit dosyası şu an boştur; ilk paket (linux-hardening) hazır olunca eklenecek. Standart: [docs/package-standard.md](docs/package-standard.md).
- Otomatik testler (Bats, bash 5 ve macOS bash 3.2) + ShellCheck her PR'da CI'da çalışır.

## Key'i sunucuya gönderme

Modül menüsünden **2) Public key'i sunucuya gönder** seçeneği (veya generator'ın son adımı)
`ssh-copy-id` çalıştırır:

- Key sunucuda zaten yetkiliyse bunu söyler ve bir şey yapmaz.
- Değilse `ssh-copy-id` önce agent'taki/varsayılan key'leri, olmazsa **parolayı** dener.
  İsterseniz giriş için başka bir key dosyası yolu da verebilirsiniz.
- Parola yalnızca `ssh`'ın kendi isteminde girilir; script'e hiç uğramaz.
- Sunucuda `PasswordAuthentication no` yapmak **bilerek otomatik değildir.** Key ile girişin
  çalıştığını gördükten sonra elle yapın, yoksa kendinizi dışarıda bırakabilirsiniz.

## Eski düzenden taşıma (v3 öncesi → `servers/`)

Eski `sistem/Modules/<ad>/` sunucularınız **otomatik** taşınır; dışa/içe aktarma gerekmez.

```bash
./start.sh --migrate --dry-run   # önce ne olacağını gör (hiçbir şey değişmez)
./start.sh --migrate             # onay isteyip taşır
```

Key'ler kopyalanıp doğrulanır, eski klasörler **silinmez** (`servers/.migrated-<tarih>/`). Keychain'deki passphrase'ler aynen geçerlidir.
Doğruladıktan sonra o klasörü (key kopyaları içerir) kendiniz silin.

## Güncelleme

Otomatik değildir; siz başlatırsınız:

```bash
./start.sh --check-update   # yalnızca bakar (yeni sürüm varsa çıkış kodu 10)
./start.sh --update         # indir → imzayı doğrula → notları göster → onaylarsanız kur
```

ya da ana menüden **⬆️ Güncellemeleri kontrol et / güncelle**.

- Paket yalnızca bu reponun GitHub Release'lerinden, HTTPS ile inen ve **bakımcının imza anahtarıyla imzalı** olan
  dosyadır (`ssh-keygen -Y verify`). Doğrulanamazsa hiçbir şey açılmaz/kurulmaz. İmza anahtarı tanımlı değilse
  güncelleme **kapalıdır**.
- Modülleriniz, `.env` ve key'leriniz korunur. Kurmadan önce kodun yedeği (`.update-backup/`, gizli dosya
  içermez) alınır; hata olursa geri yüklenir.
- Geri sürüme düşmez; `..`, mutlak yol veya symlink içeren paketleri reddeder.
- USB yazma korumalıysa güncelleme yapılamaz (bilerek).
- Not: güncelleyici `v2.2.0` ile gelir; daha eski kopyalar bir kez elle güncellenmelidir.

## Güvenlik modeli

- **Passphrase diske yazılmaz.** Keychain'de durur (`USBMonitor_<ÖNEK>_Passphrase`),
  `ssh-add`'e `SSH_ASKPASS` ile doğrudan aktarılır.
- `.env` yalnızca IP, kullanıcı, port (ve ops. key yolu) içerir. Gizli bilgi **içermemelidir**.
- TOTP/2FA gizli anahtarlarını bu klasörde **saklamayın**; telefondaki uygulamada tutun.
- `.env`, `id_ed25519*` ve `usb_logs/` `.gitignore` ile dışarıda tutulur.
- Güncellemeler imzalıdır ve elle başlatılır (yukarıya bakın).
- IP/kullanıcı/port değerleri komut çalıştırılmadan önce doğrulanır (kullanıcı `-` ile başlayamaz).
- Sunucu host key'i ilk bağlantıda size sorulur (otomatik kabul yoktur).
- Özel anahtarınızı USB'de taşıyorsanız USB'yi (APFS şifreli birim) şifreleyin.
- Güvenlik açığı bildirimi için: [SECURITY.md](SECURITY.md).

## Yapı

```
start.sh / start.command   giriş noktaları
sistem/Main.sh             menü döngüsü
sistem/Autoload.sh         eski sistem/Modules/ altını yükler (taşınana kadar)
sistem/ModuleGenerator.sh  yeni modül (+ key üretimi, Keychain, ssh-copy-id)
sistem/ImportSSHConfig.sh  ~/.ssh/config içe aktarma
sistem/ModuleManager.sh    list / remove / rename
sistem/Helpers/            Log, Menu/UI, kayıt, doğrulama, SSH, Keychain, ayarlar, güncelleme, paket (Components*) yardımcıları
components.lock            paket kilit dosyası (imzalı sürümle gelir); kurulu paketler: components/
servers/<ad>/              her sunucu için: server.env, id_ed25519_<ad>   (eski: sistem/Modules/<ad>/ → ./start.sh --migrate)
sistem/templates/          server.env.example şablonu
test/                      Bats testleri (bats test)
```

## Geliştirme

```bash
brew install shellcheck bats-core
shellcheck -x -s bash start.sh start.command sistem/*.sh sistem/Helpers/*.sh
bats test
```

Katkı için [CONTRIBUTING.md](CONTRIBUTING.md), planlananlar için [ROADMAP.md](ROADMAP.md).

## Lisans

MIT, bkz. [LICENSE](LICENSE).
