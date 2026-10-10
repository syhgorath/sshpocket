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
| 2 | Bileşen **içeriği ve kilitleri USB'de** (`components/`), **venv bir önbellektir** ve Mac'te üretilir (`~/.cache/sshpocket/venv/<ortam-kimliği>`); isteğe bağlı USB'de wheelhouse | Bilgisayar kaybolsa bile her şey USB'de kalır; venv taşınamaz (mutlak yol, mimari, exFAT'ta symlink yok) ama her makinede yeniden üretilebilir |
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
├── servers/                 KULLANICI VERİSİ: git'e girmez, hiçbir zaman çalıştırılmaz (source edilmez)
│   └── <ad>/
│       ├── server.env       IP=  USER=  PORT=  KEY=(ops.)  OS=(ops.)
│       ├── id_ed25519_<ad>[.pub]
│       └── hardening.env    (ops.) bileşen değişkenleri
└── components/              BİLEŞENLER (USB'de kalır; exFAT'ta symlink olmadığı için `current` düz metin dosyasıdır)
    ├── linux-hardening/
    │   ├── 0.1.0/           imzası doğrulanmış içerik (component.yml, playbook'lar, requirements.txt)
    │   └── current          tek satır: "0.1.0"
    └── .wheelhouse/<platform>/    (ops.) çevrimdışı Python paket önbelleği, hash'li

~/.cache/sshpocket/venv/<ortam-kimliği>/      (Mac'te; silinebilir, otomatik yeniden üretilir)
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
requires:
  control:                   # KONTROL makinesi (sshpocket'ın çalıştığı Mac)
    python: ">=3.12"         # ansible-core==2.21.5 Requires-Python ile DOĞRULANMIŞ
    packages: [ansible-core]
  target:                    # HEDEF sunucu (ayrı bir gereksinim; kontrol makinesiyle karıştırılmaz)
    python: ">=3.8"          # ansible modülleri için; bileşen sahibi belirler
profiles:                    # status: supported | planned
  - { id: ubuntu-26.04, status: supported }   # eşleme: ubuntu-26.04 <-> hardening_supported_os {Ubuntu: ["26.04"]}
  - { id: rpi,          status: planned }
  - { id: proxmox,      status: planned }
actions:
  audit:   { cmd: "ansible-playbook playbooks/audit.yml",                 effects: [installs-package] , requires_sudo: true }
  preview: { cmd: "ansible-playbook playbooks/harden.yml --check --diff", effects: [],                  requires_sudo: true }
  apply:   { cmd: "ansible-playbook playbooks/harden.yml",               effects: [changes-config],    requires_sudo: true, requires: [preview] }
vars:                        # sshpocket'ın doldurup/onaylatabileceği değişkenler
  - hardening_ssh_allow_from # NOT: ssh_port bilerek yok (bkz. 0b: şu an yalnızca ufw'ye uygulanıyor)
invoke:                      # sshpocket'ın komuta EKLEDİKLERİ (bileşen bunları kendi cmd'sine yazmaz)
  append: ["-i <geçici inventory>", "--limit <sunucu>", "--ask-become-pass", "-e @<geçici değişkenler>"]
```
- `effects`: `[]` (salt okunur) | `installs-package` | `changes-config`. sshpocket menüde etkiyi açıkça gösterir.
- `requires` (ön koşul eylemler) beyandır; **zorlamayı sshpocket yapar** (önizleme başarılı olmadan `apply` açılmaz).
- sshpocket bileşenin **içini bilmez**; yalnızca sözleşmeyi ve eylemleri çalıştırır.

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
- **İmza ad alanı:** bileşenler `sshpocket-component` ad alanıyla imzalanır (çekirdek: `sshpocket-release`). Ayrı ad alanı bilerek seçildi:
  bir bileşen imzası çekirdek güncellemesi olarak yeniden oynatılamaz. Doğrulayıcı güvenilen anahtarı `release_signers`'tan değil
  `components.lock`'taki `signers` alanından okur; bu, **sshpocket tarafında ayrı (Aşama 2) bir değişikliktir**.
- Paket: bileşenin GitHub Release varlığı `<id>-<sürüm>.tar.gz` + `.tar.gz.sig` (bugünkü güncelleyiciyle aynı kurallar:
  yalnızca HTTPS, `ssh-keygen -Y verify`, `..`/mutlak yol/symlink reddi, içindeki `component.yml` sürümü etiketle aynı,
  geri sürüme düşmeme).
- Sürümlü klasöre açılır, `current` bağlantısı atomik değişir, **eski sürüm kalır** (geri alma).
- **Her çalıştırmadan önce** dosya özetleri yeniden doğrulanır (kurulumdan sonra değiştirilmiş playbook çalışmaz).
- **Venv bir önbellektir.** Ortam kimliği = `sha256(requirements.txt) + Python sürümü + platform`. Kimlikte venv varsa ve
  sağlık kontrolü geçerse (python çalışıyor, `ansible-playbook --version`) **yeniden kullanılır**; yoksa/bozuksa kurulur.
  Python/gereksinim/makine değişince kimlik değişir, aynı makinede değişmeyince hiçbir şey kurulmaz.
- **Yorumlayıcı seçimi:** `python3`'ü körü körüne almaz. `component.yml`'deki `requires.python` aralığına uyan ilkini arar
  (`python3.14`, `python3.13`, `python3.12`, `python3`). macOS'un `/usr/bin/python3`'ü (3.9) yeni `ansible-core` için eski olabilir.
- **Kurulum:** yalnızca venv'in içine; `pip install --require-hashes --only-binary :all:` (kaynak paket derlemesi yok).
  Önce USB wheelhouse'u (`--no-index --find-links`), yoksa internet; inen paketler isteğe bağlı wheelhouse'a kopyalanır.
- `requirements.txt` **hash'li** olmalı (linux-hardening PR kalemi).

### 6.3b Ön koşul denetimi: `./start.sh --doctor`
`ssh`/`ssh-keygen`/`ssh-copy-id`, uygun Python (sürüm aralığı), `venv`+`ensurepip`, disk alanı, internet; ✅/❌ ve düzeltme önerisiyle.
Hardening/Araçlar ilk açıldığında otomatik çalışır. **Politika:** eksik olanı söyler ve **onay ister**; Homebrew varsa
`brew install python@3.x` önerir/çalıştırır; **Homebrew'u kendisi kurmaz, `sudo` kullanmaz, sisteme global `pip` yapmaz.**
Command Line Tools gerekiyorsa yönlendirir (grafik arayüzlüdür).

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

**Entegrasyon notları (linux-hardening `main` incelemesinden, 2026-10-10):**
- **Çalışma dizini:** `ansible.cfg` (`become = True`, `roles_path = roles`, `inventory`) bileşen klasöründen okunur. sshpocket komutu
  bileşen klasöründen (ya da `ANSIBLE_CONFIG` ile) çalıştırmak zorundadır; aksi halde `become` sessizce kapanır.
- **Grup adı:** `hosts: ubuntu` sabit olduğundan, sshpocket geçici inventory'de sunucuyu `ubuntu` grubuna koyar (PR-B beklemeden çalışır).
- **Anahtar agent'ta olmalı:** `hardening_verify_access` yeni bağlantıyı `BatchMode=yes` + `-i <key> -o IdentitiesOnly=yes` ile açar.
  Passphrase'li key agent'ta yoksa doğrulama başarısız sayılır ve gereksiz geri alma tetiklenir; sshpocket çalıştırmadan önce
  key'in agent'ta olduğunu doğrular (`ssh-add -l`).
- **Port:** 0b'ye kadar `PORT != 22` olan sunucu için hardening reddedilir.
- **`ansible_python_interpreter`** hedef sunucunun Python'udur; kontrol makinesinin Python'u buraya yazılmaz.
- **Tarama çıktısı:** D'ye kadar `scans/` bileşen klasörüne (USB) yazılır; bu hassas veridir, entegrasyon D'den önce açılmaz.

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
Bu depo aktif geliştirme yeri değil; değişiklikler PR ile gelir. **Sıra:** A → 0a → 0b → 0c → B → D → C
(sözleşme en sonda: önceki PR'ların gerçeğini tarif etmeli). Her PR'da `--check --diff` temiz ve ikinci çalıştırmada
`changed=0` aranır; gerçek test için bir Ubuntu 26.04 test VM'i gerekir.

| PR | Değişiklik | Neden |
|---|---|---|
| **A** | `hardening_ssh_allow_from` varsayılanı kaldır, boşsa dur; kontrol makinesi IP'si listede değilse dur; `ansible_user == root` ise dur; `authorized_keys` gerçek home'a göre; SSH/ufw sonrası yeni bağlantı testi + geri alma | `10.0.0.0/8` varsayılanı ve root, erişimi keser |
| **0a** | `hardening_*` varsayılanlarını `inventory/group_vars/all.yml`'den **rol `defaults/main.yml`**'ye taşı | `-i /tmp/x.yml` verilince `group_vars` yüklenmez, değişkenler tanımsız kalır, roller düşer |
| **0b** | `hardening_ssh_port` yalnızca ufw'ye uygulanıyor, sshd'ye değil → ya sshd'ye de uygula (Ubuntu'da `ssh.socket` varsa `Port` yetmez) ya da değişkeni kaldır ve ufw'nin **sshd'nin gerçekten dinlediği portu** (`sshd -T`) kullanmasını sağla | Uyumsuz port = kilitlenme. **sshpocket bu değişkeni arayüze koymaz** |
| **0c** | `--check`, temiz sunucuda `fail2ban` handler'ı yüzünden `failed=1` veriyor → düzelt | "Güvenli önizleme" iddiası doğru olsun |
| **B** | Grup adı: `hosts: "hardening:ubuntu"` (geçişi **kırmadan**); `KbdInteractiveAuthentication` değişkeni, açılırsa `AuthenticationMethods publickey,keyboard-interactive` zorunlu + uyarı (`UsePAM yes` ile parola girişini geri açabilir); `AllowTcpForwarding` **string** (`no\|local\|remote\|yes`, varsayılan `no`; ProxyJump için `local` yeter) | Esneklik, güvenliği sessizce düşürmeden |
| **D** | `audit` özet çıktısı (`summary.json`; rapordaki karşılıkları açıkça eşle) + `hardening_scan_dir` (izin 700; USB'ye değil kullanıcı klasörüne) + `--check`'te `fetch` davranışı (`check_mode: false` ya da atla). `audit.yml` zaten idempotent değil (zaman damgalı klasör); beklenen | `lynis-report.dat` hostname, paket, kullanıcı adı içerir; USB'ye yazılmamalı |
| **C** | VERSION, CHANGELOG, `component.yml` (yukarıdaki şema), **`pip-compile --generate-hashes`** ile hash'li `requirements.txt` (Python 3.14 ile test), imzalı paket üretim notu (`sshpocket-component` ad alanı), profil eşleme betiği (`ubuntu-26.04 ↔ Ubuntu/26.04`) | Sözleşme gerçeği tarif etsin |

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
- **Python/Ansible kurulumu:** karar → `--doctor` denetler, onayla `brew install python@3.x` yapabilir (Homebrew'u kurmaz); venv kurulumu sshpocket'ındır.
- **Canlı test erişimi:** PR serisi gerçek bir test VM'i ister. Başka bir (otomatik) oturumun VM'e erişimi, VM'in kendi key'i/agent'ı ile
  yapılmalı; `sudo` parolasını yalnızca kullanıcı yazar. Yalnızca test VM'i, önce snapshot.
- **Bilgisayar kaybı senaryosu:** key dosyaları ve bileşenler USB'de kalır, ama **passphrase'ler Keychain'de (Mac'te)**. Parola yöneticisinde de saklanmalı;
  USB tek hata noktasıdır (şifreli yedek önerilir).
- **sudo parolasını menü oturumu boyunca hatırlama:** risk/kolaylık dengesi; başta her eylemde bir kez sorulur.
- **Proxmox/rpi profilleri:** farklı güvenlik duvarı, `ip_forward`, SD kart, küme portları; ayrı rol gerektirir (linux-hardening'in kararı).
- **Üçüncü taraf bileşen** desteği bilinçli olarak yok; yalnızca kilitteki, imzalı bileşenler.
- Windows desteği kapsam dışı.

## 12. Kapsam dışı
Otomatik (kullanıcı onaysız) güncelleme, venv'i USB'de kalıcı tutmak (önbellek olarak Mac'te üretilir), Python'u USB'ye gömmek (ileride isteğe bağlı), sudo parolasını saklama, Ansible'ı sshpocket'a gömmek.
