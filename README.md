# sshpocket

macOS için, USB bellekten (veya herhangi bir klasörden) çalışan, modüler bir SSH bağlantı menüsü.
Her sunucu bir *modüldür*; modül klasörünü eklediğinizde menüde kendiliğinden görünür.

> **Durum: ham / erken aşama (v2.0.0).** 🛠️
> Bu, kişisel bir HomeLab aracından çıkan bir proje. [Claude](https://claude.com/claude-code) ile
> elden geçirildi ve ilk hâline göre epey toparlandı, ama hâlâ geliştirilecek çok yeri var:
> pürüzler, eksik testler ve yazılmamış özellikler olabilir. Sorunlar projenin hamlığından
> kaynaklanır; bunun için kimseye kızmayın 😄 — issue ve PR'larla yardım etmeniz çok makbule geçer.
> Yalnızca macOS'ta denendi. Kendi sunucularınızda kullanmadan önce kodu okuyun;
> kullanım sorumluluğu size aittir (bkz. [LICENSE](LICENSE)).

## Hızlı başlangıç

```bash
./start.sh                      # menüyü başlat
bash sistem/ModuleGenerator.sh  # yeni sunucu modülü oluştur
```

Generator size IP/kullanıcı/port sorar, isterseniz ed25519 anahtar üretir ve
passphrase'i **macOS Keychain**'e kaydeder.

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
- `.env` yalnızca IP, kullanıcı ve port içerir. Gizli bilgi **içermemelidir**.
- TOTP/2FA gizli anahtarlarını bu klasörde **saklamayın**; telefondaki uygulamada tutun.
- `.env`, `id_ed25519*` ve `usb_logs/` `.gitignore` ile dışarıda tutulur.
- IP/kullanıcı/port değerleri komut çalıştırılmadan önce doğrulanır.
- Sunucu host key'i ilk bağlantıda size sorulur (otomatik kabul yoktur).
- Özel anahtarınızı USB'de taşıyorsanız USB'yi (FileVault benzeri) şifreleyin.

## Yapı

```
start.sh                 giriş noktası
sistem/Main.sh           menü döngüsü
sistem/Autoload.sh       Modules/ altını otomatik yükler
sistem/Helpers/          Log, Menu, kayıt, SSH, eject yardımcıları
sistem/Modules/<ad>/     her sunucu için: <Ad>Module.sh, .env, id_ed25519_<ad>
```

Not: macOS, USB takılınca script'i otomatik çalıştırmaz; `start.sh`'i elle başlatın.

## Lisans

MIT, bkz. [LICENSE](LICENSE).
