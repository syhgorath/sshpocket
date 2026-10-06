# sshpocket

[![ci](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml/badge.svg)](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

🇹🇷 Türkçe · 🇬🇧 [English](README.en.md)

macOS için, USB bellekten (veya herhangi bir klasörden) çalışan, modüler bir SSH bağlantı menüsü.
Her sunucu bir *modüldür*; modül klasörünü eklediğinizde menüde kendiliğinden görünür.

> **Durum: ham / erken aşama (v2.0.0).** 🛠️
> Bu, kişisel bir HomeLab aracından çıkan bir proje. [Claude](https://claude.com/claude-code) ile
> elden geçirildi ve ilk hâline göre epey toparlandı, ama hâlâ geliştirilecek çok yeri var:
> pürüzler, eksik testler ve yazılmamış özellikler olabilir. Sorunlar projenin hamlığından
> kaynaklanır; bunun için kimseye kızmayın 😄 — issue ve PR'larla yardım etmeniz çok makbule geçer.
> Yalnızca macOS'ta denendi. Kendi sunucularınızda kullanmadan önce kodu okuyun;
> kullanım sorumluluğu size aittir (bkz. [LICENSE](LICENSE)).

> **Otomatik başlamaz.** macOS, Linux ve modern Windows USB takılınca script çalıştırmaz (güvenlik gereği).
> Elle başlatın: `./start.sh` ya da Finder'da `start.command` dosyasına çift tıklayın.

## Hızlı başlangıç

```bash
./start.sh                          # menüyü başlat
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
- **Durum göstergesi:** `SSHPOCKET_STATUS=1 ./start.sh` menüde 🟢 (port açık) / 🔴 (erişilemiyor) / ⚪ (ayar yok)
  gösterir. Sunucular paralel kontrol edilir.
- **Modül yönetimi:** `ModuleManager.sh list | remove <ad> | rename <eski> <yeni>`.
- **Aynı sunucuya birden çok kullanıcı/key:** her biri ayrı bir modül olur (örn. `web_root`, `web_deploy`).
- 53 otomatik test (Bats) + ShellCheck, her push'ta CI'da çalışır.

## Key'i sunucuya gönderme

Modül menüsünden **2) Public key'i sunucuya gönder** seçeneği (veya generator'ın son adımı)
`ssh-copy-id` çalıştırır:

- Key sunucuda zaten yetkiliyse bunu söyler ve bir şey yapmaz.
- Değilse `ssh-copy-id` önce agent'taki/varsayılan key'leri, olmazsa **parolayı** dener.
  İsterseniz giriş için başka bir key dosyası yolu da verebilirsiniz.
- Parola yalnızca `ssh`'ın kendi isteminde girilir; script'e hiç uğramaz.
- Sunucuda `PasswordAuthentication no` yapmak **bilerek otomatik değildir.** Key ile girişin
  çalıştığını gördükten sonra elle yapın, yoksa kendinizi dışarıda bırakabilirsiniz.

## Güvenlik modeli

- **Passphrase diske yazılmaz.** Keychain'de durur (`USBMonitor_<ÖNEK>_Passphrase`),
  `ssh-add`'e `SSH_ASKPASS` ile doğrudan aktarılır.
- `.env` yalnızca IP, kullanıcı, port (ve ops. key yolu) içerir. Gizli bilgi **içermemelidir**.
- TOTP/2FA gizli anahtarlarını bu klasörde **saklamayın**; telefondaki uygulamada tutun.
- `.env`, `id_ed25519*` ve `usb_logs/` `.gitignore` ile dışarıda tutulur.
- IP/kullanıcı/port değerleri komut çalıştırılmadan önce doğrulanır (kullanıcı `-` ile başlayamaz).
- Sunucu host key'i ilk bağlantıda size sorulur (otomatik kabul yoktur).
- Özel anahtarınızı USB'de taşıyorsanız USB'yi (APFS şifreli birim) şifreleyin.
- Güvenlik açığı bildirimi için: [SECURITY.md](SECURITY.md).

## Yapı

```
start.sh / start.command   giriş noktaları
sistem/Main.sh             menü döngüsü
sistem/Autoload.sh         Modules/ altını otomatik yükler
sistem/ModuleGenerator.sh  yeni modül (+ key üretimi, Keychain, ssh-copy-id)
sistem/ImportSSHConfig.sh  ~/.ssh/config içe aktarma
sistem/ModuleManager.sh    list / remove / rename
sistem/Helpers/            Log, Menu, kayıt, doğrulama, SSH, eject yardımcıları
sistem/Modules/<ad>/       her sunucu için: <Ad>Module.sh, .env, id_ed25519_<ad>
test/                      Bats testleri (bats test)
```

## Geliştirme

```bash
brew install shellcheck bats-core
shellcheck -x -s bash start.sh start.command sistem/*.sh sistem/Helpers/*.sh sistem/Modules/*/*.sh
bats test
```

Katkı için [CONTRIBUTING.md](CONTRIBUTING.md), planlananlar için [ROADMAP.md](ROADMAP.md).

## Lisans

MIT, bkz. [LICENSE](LICENSE).
