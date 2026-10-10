# Tasarım: `servers/` veri ayrımı ve bileşen (component) modeli

> **Durum: TASARIM, henüz uygulanmadı.** Kararlar 2026-10-10'da alındı. Uygulama, bir haftalık deneme
> süresinden sonra, aşağıdaki aşamalarla ve her aşama ayrı sürüm/PR olarak yapılacak.

## 1. Neden
- Kod (`sistem/`) ile kullanıcı verisi (sunucular, key'ler) aynı klasörde: güncelleme, yedekleme ve taşıma
  ("Modules'a dokunma") bu yüzden karmaşık.
- Her sunucu için **bash modül dosyası üretiyoruz**, oysa tek gerçek bilgi `.env`. Üretilmiş kod, "rigit" hissin bir kaynağı.
- `Autoload`, kullanıcı klasörlerindeki tüm `.sh` dosyalarını **çalıştırıyor**. Veri klasörü hiç çalıştırılmamalı.
- Sunucu sertleştirme (linux-hardening) ve ileride Docker/web sunucusu kurma gibi işleri **ayrı repolardan**,
  birbirine karışmadan, tek menüden yönetmek istiyoruz.

## 2. Alınan kararlar

| # | Karar | Gerekçe |
|---|---|---|
| 1 | Bileşenler, **sshpocket sürümüyle sabitlenir** (`components.lock`) + yeni imzalı sürüm varsa **bilgilendirir**, onayla kurar | Birlikte test edilmiş sürümler; sunucularda kök yetkisiyle çalışan kod denetimsiz değişmez |
| 2 | Bileşenler **Mac'te** durur (`~/.local/share/sshpocket/components/`); USB'ye taşınmaz (isteğe bağlı `SSHPOCKET_COMPONENTS_DIR`) | venv taşınamaz (mutlak yol, mimari), USB yavaş/izinsiz/kaybolabilir |
| 3 | Bileşen paketleri **aynı imza anahtarıyla** imzalanır; kilit dosyasında bileşen başına `signers` alanı vardır | Tek bakımcı için basit; ileride ayrı anahtar kod değişmeden eklenir |
| 4 | Kök dizinde **`servers/`** klasörü: kullanıcı verisi buraya | `sistem/` tamamen kod olur; yedeklenecek tek klasör |
| 5 | Sunucu ayarında **genel anahtar adları**: `IP`, `USER`, `PORT`, `KEY`, `OS` | `UBUNTUTEST_IP` gibi önekler üretilmiş koda bağlıydı |
| 6 | Sunucu başına **üretilmiş bash dosyası kaldırılır**; uygulama `servers/` klasörünü tarayıp menüyü kendisi kurar | Daha az kod, daha az enjeksiyon yüzeyi |
| 7 | Sunucu menüsüne **🛡️ Hardening** ve **🧰 Araçlar** (Docker kur, web sunucusu kur…) eklenir; hepsi ayrı repo | Çekirdek ince kalır |

## 3. Dizin düzeni

```
sshpocket/
├── start.sh, start.command, VERSION, components.lock, ...
├── sistem/                  UYGULAMA KODU: güncelleyici bütünüyle değiştirir; kullanıcı verisi içermez
│   ├── Main.sh, Update.sh, Helpers/, ...
│   └── release_signers
└── servers/                 KULLANICI VERİSİ: git'e girmez, hiçbir zaman çalıştırılmaz (source edilmez)
    └── <ad>/
        ├── server.env       IP=  USER=  PORT=  KEY=(ops.)  OS=(ops.)
        ├── id_ed25519_<ad>[.pub]
        └── hardening.env    (ops.) bileşen değişkenleri

~/.local/share/sshpocket/                     (Mac'te, USB'de değil)
└── components/
    └── linux-hardening/
        ├── 0.1.0/           imzası doğrulanmış paket içeriği
        ├── current -> 0.1.0
        └── .venv/           yalnızca bu Mac'te geçerli çalışma ortamı
```

- Sunucu adı kuralı değişmez: `^[a-z][a-z0-9_]*$`. Klasör adı = kimlik.
- Keychain hesabı **aynı kalır**: `USBMonitor_<AD_BÜYÜK>_Passphrase` (servis `USBMonitor`). Passphrase'ler yeniden girilmez.
- `.gitignore`: `servers/*` (yalnızca `servers/.gitkeep` ve `servers/README.md` izlenir). `example` artık sunucu değil,
  `sistem/templates/server.env.example`.

## 4. Uygulama davranışı
- Menü, `servers/*/server.env` dosyalarından kurulur. **Veri klasöründen hiçbir dosya `source` edilmez.**
  `server.env`, bugünkü güvenli ayrıştırıcıyla (satır okuma, `eval` yok) okunur ve her değer doğrulanır
  (`ssh_validate_target`).
- Tek, genel `ssh_module_run <ad>`; sunucu başına fonksiyon/dosya yok.
- `Autoload` yalnızca `sistem/` altındaki yardımcıları yükler.
- Gizli/AppleDouble dosyalar (`._*`, `.DS_Store`) yine yok sayılır; testle güvence altında kalacak.

## 5. Geçiş (migration)
Sürüm N → N+1, otomatik ve geri alınabilir:
1. İlk çalıştırmada `sistem/Modules/<ad>/` (ve `example` dışındaki her klasör) bulunursa **deneme çıktısı** gösterilir, onay istenir.
2. Yeni biçime çevrilir: `servers/<ad>/server.env` (`<ÖNEK>_IP` → `IP`, … `<ÖNEK>_KEY` → `KEY`), key dosyaları taşınır.
   Üretilmiş `<Ad>Module.sh` dosyaları **taşınmaz**.
3. Doğrulama: ayrıştırılan değerler eski/yeni aynı mı, key dosyaları var mı. Başarılıysa eski klasör
   `sistem/Modules.migrated-<tarih>/` olarak **silinmeden** kenara alınır.
4. İdempotent: ikinci çalıştırmada yapacak bir şey yok. Hata olursa hiçbir şey silinmez.
5. **Geriye uyumluluk okuyucusu:** `server.env` içinde eski `<ÖNEK>_IP=` biçimi görülürse okunur (uyarıyla).
6. Güncelleyici (yeni sürüm), `sistem/`'i bütünüyle değiştirmeden **önce** eski `Modules/`'i bu geçişle `servers/`'a alır;
   kullanıcı verisi hiçbir noktada silinmez.

## 6. Bileşen (component) modeli

### 6.1 Sözleşme: `component.yml` (bileşen reposunun kökünde)
```yaml
id: linux-hardening
version: 0.1.0               # etiketle aynı olmalı (v0.1.0)
sshpocket_api: 1             # sözleşme sürümü; uyumsuzsa sshpocket reddeder
requires: [python3, ansible-core]
profiles:                    # sshpocket menüsünde seçenek; status: supported | planned
  - { id: ubuntu-26.04, status: supported }
  - { id: rpi,          status: planned }
  - { id: proxmox,      status: planned }
actions:                     # sshpocket yalnızca bunları ve sırasını bilir
  audit:   { cmd: "ansible-playbook playbooks/audit.yml",                 mutates: false }
  preview: { cmd: "ansible-playbook playbooks/harden.yml --check --diff", mutates: false }
  apply:   { cmd: "ansible-playbook playbooks/harden.yml",               mutates: true, requires: [preview] }
vars:                        # sshpocket'ın doldurup/onaylatabileceği değişkenler
  - hardening_ssh_allow_from
  - hardening_ssh_port
```
sshpocket bileşenin **içini bilmez**; yalnızca sözleşmeyi ve eylemleri çalıştırır.

### 6.2 Kilit dosyası: `components.lock` (sshpocket reposunda, imzalı sürümle gelir)
```yaml
components:
  linux-hardening:
    repo: syhgorath/linux-hardening
    version: 0.1.0
    sha256: <paket özeti>
    signers: "sshpocket-release namespaces=\"sshpocket-component\" ssh-ed25519 AAAA..."
```
- Yeni bileşen eklemek = kilit dosyasına satır (imzalı sshpocket sürümü) → bilinçli güven kararı.
  Kilit dosyasında olmayan bileşen **çalıştırılmaz**.

### 6.3 Kurulum ve doğrulama
- Paket: bileşenin GitHub Release varlığı `<id>-<sürüm>.tar.gz` + `.tar.gz.sig` (bugünkü güncelleyiciyle aynı kurallar:
  yalnızca HTTPS, `ssh-keygen -Y verify`, `..`/mutlak yol/symlink reddi, içindeki `component.yml` sürümü etiketle aynı,
  geri sürüme düşmeme).
- Sürümlü klasöre açılır, `current` bağlantısı atomik değişir, **eski sürüm kalır** (geri alma).
- **Her çalıştırmadan önce** dosya özetleri yeniden doğrulanır (kurulumdan sonra değiştirilmiş playbook çalışmaz).
- Çalışma ortamı (venv) gereksinim dosyasının özeti değişirse yeniden kurulur; sürümler sabitlenir (`requirements.txt`).

### 6.4 Güncelleme akışı
`./start.sh --update`:
1. Çekirdek (bugünkü imzalı akış) + gerekirse geçiş.
2. Yeni `components.lock` okunur; kurulu sürüm kilitle eşleşmiyorsa bileşen imzalı paketten kurulur.
3. İsteğe bağlı **bilgilendirme:** bileşen reposunda kilitten **daha yeni imzalı** bir sürüm varsa "0.2.0 var, değişiklikler
   şunlar; kurulsun mu?" diye sorulur. Onay olmadan kilit sürümü kalır.

### 6.5 Sunucuya çalıştırma (Ansible bileşeni için)
- sshpocket, sunucu ayarlarından **geçici inventory** üretir (`ansible_host/user/port/private_key_file`; izin 600; iş
  bitince silinir) ve bileşeni onunla çalıştırır. Passphrase zaten Keychain→`ssh-agent` ile yüklüdür.
- **sudo parolası** `--ask-become-pass` ile Ansible'ın kendi isteminden alınır: bir çalıştırma boyunca bir kez, diske
  veya komut satırına yazılmaz, Keychain'e kaydedilmez. (Menü oturumu boyunca hatırlama: ayrı risk değerlendirmesi, sonra.)
- `SSH_CONNECTION`: sshpocket, sunucuya bağlanıp kontrol makinesinin sunucudan görünen IP'sini bulur ve
  `hardening_ssh_allow_from` için **öneri** olarak gösterir; kullanıcı onaylar.
- Host key doğrulaması kapatılmaz (`host_key_checking = True`); sunucuya daha önce sshpocket ile bağlanılmış olmalı.

### 6.6 Güvenlik kapıları (sshpocket tarafı)
- `mutates: true` eylem, aynı oturumda ilgili **önizleme başarıyla çalışmadan** açılmaz.
- Uygulamadan önce özet gösterilir (sunucu, profil, bileşen sürümü, `allow_from`, port) ve **onay yazdırılır**.
- Kullanıcı `root` ise hardening reddedilir (erişim kaybı riski). Algılanan OS, seçili profille uyuşmuyorsa durur.
- Profil `planned` ise menüde pasif ("yakında").
- Her uygulamanın kaydı (tarih, sunucu, bileşen+sürüm, sonuç) `servers/<ad>/` altında, **gizli bilgi içermeden** tutulur.

## 7. Menü
```
<ad>
 1) Bağlan
 2) Public key'i sunucuya gönder
 3) Bilgileri güncelle
 4) Keychain passphrase'i
 5) 🛡️ Hardening      → Denetle / Önizle / Uygula / Tekrar denetle ve karşılaştır
 6) 🧰 Araçlar        → profile uyan bileşen eylemleri (Docker kur, Web sunucusu kur, …)
```
Ana menü: sunucular + Yeni sunucu / İçe aktar / Yönet / Güncelle (bugünkü gibi).

## 8. linux-hardening için istenecek değişiklikler (PR listesi)
Bu depo aktif geliştirme yeri değil; değişiklikler PR ile gelir. Öncelik sırası:

| # | Değişiklik | Neden |
|---|---|---|
| 1 | **Etiketli, imzalı sürüm** (`v0.1.0`, `.tar.gz` + `.sig`) | Kök yetkisiyle çalışan kod; sabitlenebilir olmalı |
| 2 | **`component.yml`** (profiller, eylemler, değişkenler, `sshpocket_api`) | Sözleşme |
| 3 | `hosts: ubuntu` → **genel grup** (`hardening`) | rpi/proxmox profilleri ve üretilmiş inventory için |
| 4 | `hardening_ssh_allow_from` **varsayılanı kaldır**, boşsa dur + ön kontrolde kontrol makinesi IP'sinin listede olduğunu doğrula | `10.0.0.0/8` varsayılanı başka ağlarda kilitlenme yaratır |
| 5 | Ön kontrol: `ansible_user == root` ise dur; `authorized_keys` yolu kullanıcının gerçek home'una göre | root kapanır / yanlış yol |
| 6 | `KbdInteractiveAuthentication` değişkene çevrilsin (varsayılan `no`) | TOTP/2FA ile çakışma |
| 7 | `AllowTcpForwarding` değişkene çevrilsin (varsayılan `no`) | Tünel/ProxyJump kullananlar için |
| 8 | SSH/ufw değişikliğinden sonra **yeni bağlantı testi** (`wait_for_connection`) ve başarısızsa geri alma bloğu | Kilitlenme koruması |
| 9 | `audit.yml` için özet çıktı (hardening index) | Menüde "öncesi → sonrası" göstermek |

## 9. Aşamalar ve kabul ölçütleri

| Aşama | İçerik | Bittiğinde |
|---|---|---|
| 0 | Bu belge | Kararlar kayıtlı |
| 1 | **Veri ayrımı:** `servers/`, genel `server.env`, tek genel çalıştırıcı, geçiş, `Autoload` veri klasörünü yüklemez, güncelleyici basitleşir | Eski kurulum otomatik taşınır; testler: geçiş (deneme/gerçek/idempotent/hata), gizli dosyalar, güncelleyici |
| 2 | **Bileşen yükleyici:** `component.yml`, `components.lock`, imzalı kurulum, sürümlü klasör, hash yeniden doğrulama, `--update` entegrasyonu | Sahte bileşenle uçtan uca testler (imza/replay/arşiv saldırıları dahil) |
| 3 | **Hardening bileşeni:** inventory üretimi, menü, güvenlik kapıları, `SSH_CONNECTION` önerisi | Proxmox VM üzerinde gerçek deneme |
| 4 | **Araçlar:** ilk bileşen (örn. Docker kur) | Aynı sözleşmeyle ikinci bileşen kodsuz eklenir |

Her aşama ayrı sürüm; geri uyumluluk ve geçiş testleri aşama 1'in bir parçasıdır.

## 10. Test stratejisi
- Çekirdek: mevcut Bats stili; `ansible-playbook` yerine **sahte komut** (üretilen inventory/değişken/argümanlar ve kapılar doğrulanır).
- Geçiş: gerçek `servers/` ve eski `Modules/` düzeniyle, yan etkisiz geçici klasörlerde.
- Bileşen kurulumu: güncelleyicideki saldırı senaryoları bileşen paketleri için de (sahte imza, `..`, symlink, eski sürüm, sürüm uyuşmazlığı).
- Docker e2e `sshd` yalnızca bağlantı/anahtar akışları için; hardening (ufw, sysctl, auditd) gerçek VM'de elle.

## 11. Riskler ve açık noktalar
- **Python/Ansible kurulumu:** macOS'ta Python yalnızca Command Line Tools ile gelir; kurulumu sshpocket mı yapar, yoksa
  yalnızca denetleyip yönlendirir mi? (Aşama 3'te karar.)
- **sudo parolasını menü oturumu boyunca hatırlama:** risk/kolaylık dengesi; başta her eylemde bir kez sorulur.
- **Proxmox/rpi profilleri:** farklı güvenlik duvarı, `ip_forward`, SD kart, küme portları; ayrı rol gerektirir (linux-hardening'in kararı).
- **Üçüncü taraf bileşen** desteği bilinçli olarak yok; yalnızca kilitteki, imzalı bileşenler.
- Windows desteği kapsam dışı.

## 12. Kapsam dışı
Otomatik (kullanıcı onaysız) güncelleme, bileşenleri USB'den çalıştırma, sudo parolasını saklama, Ansible'ı sshpocket'a gömmek.
