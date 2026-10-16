# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

### Eklendi
- **Sunucu menüsünde paket değişkenleri (menü 2b/n):** paket eylem listesinin başında **Hazırlık** bloğu (zorunlu değişken eksikse ❌ ve eylemler ⛔ kapalı) ve
  `📝 Değişkenler` ekranı: değer/varsayılan/otomatik gösterimi, kaydetmeden önce doğrulama, `warn_if` için onay, `-` ile silme. `list[cidr]` değişkenler için **ağ
  editörü**: bu bilgisayarın adresinden öneri (ağ / tahmini /24 / yalnızca bu adres), isteğe bağlı sunucudan sorgu (salt okunur ssh), elle ekleme/silme/temizleme; listede
  tek ağ varsa *'başka bir ağdan bağlanırsanız SSH kapalı olur'* uyarısı. Hiçbir şey otomatik yazılmaz.

### Eklendi
- **Paket değişkenleri için kütüphane (menü 2a/n; henüz menüde görünmez):** `ComponentsVars.sh` ve `component_run.py describe|check|net-*`: değişken açıklama/doğrulama
  (çalıştırmadakiyle aynı doğrulayıcı), `servers/<ad>/<paket>.vars` okuma/yazma (yorumlar korunur, izin 600, atomik), eksik zorunlu değişken listesi ve
  **erişim ağı önerisi** (yerel arayüzden adres/önek; nokta-nokta tünelde /24 'tahmini' etiketlenir; isteğe bağlı sabit, salt okunur `SSH_CONNECTION` sorgusu).

### Eklendi
- **Sunucu menüsünde `🛡️ Paketler` (Aşama 3, menü 1/n):** yeni biçimli bir sunucuda kurulu paket varsa sunucu menüsüne girdi eklenir: paket seç → eylem seç
  (etiket: 🔍 salt okunur / ✏️ değişiklik yapar / ☠️ yıkıcı, ön koşul `(önce: preview)`, ilk uyarı açıklamada) → eylem `--components run` zincirinde, tüm
  kapılar ve onaylarla çalışır. Paket yoksa ya da sunucu eski biçimliyse girdi görünmez.

### Değişti
- **Sudo parolası istemi artık açıklanıyor:** eylem `--ask-become-pass` ile çalışacaksa, Ansible'ın `BECOME password:` istemi öncesinde bunun sunucudaki sudo
  parolası olduğu, sudo parola istemiyorsa (NOPASSWD) yalnızca Enter'a basılacağı ve parolanın sshpocket'e/günlüğe yazılmadığı belirtilir.

### Düzeltildi
- **`--components run` gerçek çalıştırmada `comp_prepare: command not found` veriyordu:** `Main.sh` `ComponentsManifest.sh`'ı yüklemiyordu (testler işlevi
  sahtelediği için fark edilmemişti). Dosya yüklendi; gerçek `Main.sh` yolunu doğrulayan iki test eklendi.

### Eklendi
- **`./start.sh --components run <paket> <eylem> <sunucu>`:** kurulu paketin bir eylemini sunucuda çalıştırır. Sunucu bilgisi `servers/<ad>/server.env`'den,
  paket değişkenleri `servers/<ad>/<paket>.vars`'tan okunur. İşletim sistemi profili sabit, salt okunur bir `ssh ... cat /etc/os-release` ile algılanır
  (host key doğrulaması kapatılmaz, parola sorulmaz; çıktı hiçbir zaman çalıştırılmaz). Python ortamı yoksa **onayla** kurulur (PyPI'dan ~10 MB, hash'li
  wheel; `~/.cache/sshpocket`). Ardından yürütücünün kapıları, onayları ve kaydı uygulanır; sudo parolasını Ansible kendi isteminden alır. Sonuç
  `servers/<ad>/components.log` dosyasına (tarih|paket|sürüm|eylem|ok/fail, gizli bilgi yok) işlenir.

### Eklendi
- **Paket çalıştırma, 3. parça (yürütücü; henüz CLI/menüye bağlı değil, gerçek sunucuya dokunulmaz):** `ComponentsExec.sh` tek giriş noktası
  `comp_exec_action`: kapılar → değişkenler (`outputs.dir_var` her zaman kullanıcı klasörüne yönlendirilir) → onay → çalıştırma → sonuç → kayıt.
  `ansible-playbook` venv'den, paket kökünde, `ANSIBLE_HOST_KEY_CHECKING=True` zorlanarak çalışır; geçici inventory/değişken dosyaları Ctrl-C/TERM dahil
  her çıkışta silinir; çıktı kullanıcı klasörüne (izin 600) günlüklenir. `SSHPOCKET_RESULT` satırı (düz/yaml/json çıktıda) önek, anahtar ve değer
  denetimiyle ayrıştırılır. Bildirim doğrulayıcısı `outputs` alanını okur; paketteki `prefix` sshpocket'in türettiğiyle uyuşmazsa paket reddedilir.

### Düzeltildi
- **`components/` (kurulu paketler) `.gitignore`'a eklendi:** `--components sync` ile açılan paket klasörü yanlışlıkla commit'lenebiliyordu.

### Eklendi
- **Paket çalıştırma, 2. parça (çalıştırma öncesi kapılar; yerel, sunucuya dokunmaz):** `ComponentsGates.sh`: root ile değiştirici eylem reddi,
  host key tanınıyor mu, anahtar ssh-agent'ta mı (gerekirse eklenir), profil `supported` mı, `requires` eylemleri taze (30 dk) ve başarılı mı
  (`~/.local/share/sshpocket/<paket>/<sunucu>/results`, dizin 0700, dosya 0600), `confirm` onayı (yes-no, sunucu adını yazma; girdi yoksa ret) ve
  `warn_if` onayı. Bildirim bilgisine paket uyarı metinleri (`action.<ad>.warning`) eklendi.

### Eklendi
- **Paket çalıştırma, 1. parça (girdi üreteçleri; henüz hiçbir şey çalıştırmaz, sunucuya dokunmaz):** `ComponentsRun.sh` ve `component_run.py`:
  paket değişkenlerinin doğrulanması (tür, aralık, zorunlu, `warn_if`; `servers/<ad>/<paket>.vars` + çalıştırıcının zorladığı `--set` değerleri),
  izin 600'lü geçici inventory ve değişken dosyası, kabuk dizgesi/eval olmadan argüman dizisi (`-i`/`--limit`/`-e` çalıştırıcıya aittir, pakette
  geçerse reddedilir; `invoke.append`'deki yinelenenler atlanır).

### Eklendi
- **İlk gerçek paket kilitlendi:** `components.lock` artık `linux-hardening 0.2.0` (imzalı, paket standardı v1 uyumlu; sha256 `2886b610…f38a`) girdisini taşır.
  Kurulum/çalıştırma menüsü henüz yok; `--components list|sync|check-new` ile görülür.

## [3.5.2] - 2026-10-16

### Düzeltildi
- **Keychain'deki passphrase yanlışken bağlantı ekranı sonsuza kadar takılıyordu:** `ssh-add`, askpass boş cevap verene kadar yeniden dener; askpass her seferinde
  aynı yanlış passphrase'i döndürdüğü için "SSH key agent'a ekleniyor" satırında %100 CPU ile sonsuz döngü oluşuyordu. `askpass.sh` artık yalnızca ilk
  çağrıda passphrase döndürür (`ASKPASS_STATE`), sonrakilerde boş satır verir; `ssh-add` birkaç saniyede vazgeçer.

### Eklendi
- **Yanlış kayıtlı passphrase'te yeniden sorma:** key agent'a eklenemezse (agent'a ulaşılabiliyorsa) "Kayıtlı passphrase yanlış olabilir. Yeniden girip
  Keychain'e kaydedeyim mi? [e/H]" diye sorulur; `e` ise passphrase güvenli istemle (komut satırında görünmez) Keychain'e yazılır ve en çok 3 kez denenir.
  Girdi yoksa takılmaz.

## [3.5.1] - 2026-10-12

### Değişti
- **Belgeler güncellendi:** README'ye **Gereksinimler** bölümü (hangi araçlar macOS ile gelir; fzf ve Python isteğe bağlı); eskimiş `.env` anlatımı
  (`servers/<ad>/server.env`, `sshpocket.conf`); tekrarlanan menü/fzf maddeleri birleştirildi; knock istemci tarafı ve `UI` değerleri anlatıldı;
  `docs/ui-design.md` uygulama durumuyla güncellendi.

### Düzeltildi
- **Ok tuşlu menüde listenin satırları her tuşta çoğalıyordu (3.5.0):** menü açıklamaları eklenince, terminal genişliğinden uzun açıklama bir alt satıra
  sarılıyor, imleci geri taşıma sayısı kayıyor ve her ↑/↓'de üst satır kopyalanıyordu. Çizim sırasında otomatik sarma kapatılır (uzun satırlar
  sağ kenarda kırpılır), çıkışta ve Ctrl-C'de yeniden açılır. 60/80/100 sütunlu gerçek pty testi eklendi.
- **fzf, Finder'dan açılınca (start.command) bulunamıyordu:** PATH'te yoksa `/opt/homebrew/bin` ve `/usr/local/bin` da aranır.

## [3.5.0] - 2026-10-12

### Düzeltildi
- **`check-new` ön sürümleri (pre-release) göremiyordu:** depoda kararlı "latest" yoksa (linux-hardening şu an yalnızca ön sürümlü) GitHub API'deki en yeni
  yayına bakılır (yine yalnızca bilgi; kurulmaz).
- **`--doctor` yeni Mac'te "geliştirici araçlarını kurun" penceresini açabiliyordu:** macOS'ta Command Line Tools yoksa `/usr/bin/python3` gerçek
  Python değil bir saplamadır ve çalıştırılınca kurulum penceresi açar. Saplama artık çalıştırılmadan atlanır ve doktor nedenini söyler.
- **Menüden "Geri" ile dönünce gereksiz "Devam etmek için Enter" soruluyordu:** sunucu menüsü, ⚙️ Ayarlar ve Sunucuları yönet'ten geri dönünce
  artık doğrudan ana menüye dönülür. Okunacak çıktısı olan işlemlerden (bağlanma sonucu, ekleme, silme, güncelleme) sonra duraklama korunur.

### Eklendi
- **Bakımcı aracı `scripts/lock-component.sh`:** bir paket sürümünü `components.lock`'a güvenle yazar: paketi ve imzayı HTTPS ile indirir, arşivi denetler,
  imzayı (`sshpocket-component`) doğrular, `component.json`'u şemaya göre doğrular (kurulamayacak paket kilide **yazılmaz**), sha256'yı hesaplar.
  `--write` yoksa yalnızca gösterir. `comp_get` pipefail altında 141 ile düşmesin diye tüm girdiyi okur.
- **CI'da sabit sürüm ShellCheck:** `scripts/ci-install-shellcheck.sh` (v0.11.0, indirilen arşivin sha256'sı doğrulanmazsa kurulmaz); yerel ve CI
  aynı sürümü kullanır, "yerelde yeşil, CI'da kırmızı" farkı kapanır.
- **fzf desteği (isteğe bağlı):** sistemde `fzf` kuruluysa (`brew install fzf`) tüm seçim menüleri fzf ile açılır: yazarak arama, **önizleme penceresinde
  seçili seçeneğin açıklaması**, `←`/Esc geri. fzf yoksa ya da terminal değilse (boru/test) kendi ok tuşlu seçicimiz, o da yoksa numaralı menü kullanılır.
  Açıklama metni fzf komut satırına girmez (dosyadan okunur). ⚙️ Ayarlar → menü stili: `auto` | `fzf` | `arrows` | `numbers`.
- **Menü açıklamaları:** ana menü, sunucu menüsü, Ayarlar, Sunucuları yönet ve Keychain menülerinde her seçeneğin kısa açıklaması; fzf yoksa ok tuşlu
  seçicinin alt satırında gösterilir. `./start.sh --doctor` fzf'i isteğe bağlı olarak denetler (kurmaz).

### Düzeltildi
- **Sunucu silinince Keychain'deki knock dizisi yetim kalıyordu:** artık sunucuyla birlikte silinir; yeniden adlandırmada eski adla duran knock
  dizisi için "Knock ayarları ile yeniden girin" uyarısı gösterilir.
- **Knock ayarları açıklamasız ve bağışlamazdı:** tek yanlış girişte "Geçersiz protokol" deyip menüden çıkıyordu. Artık knocking'in ne olduğu, her
  alanın (protokol, bekleme, dizi) ne anlama geldiği ve örnek değerler gösterilir; yanlış girişte **neden** geçersiz olduğu söylenip yeniden sorulur
  (3 deneme), büyük/küçük harf fark etmez, Enter = varsayılan. macOS'un diziyi iki kez isteyebileceği belirtilir.

## [3.4.0] - 2026-10-12

### Eklendi
- **Klasik port knocking (istemci tarafı):** sunucu menüsüne **5) Knock ayarları**. `server.env`'e `KNOCK=keychain`, `KNOCK_PROTO` (tcp|udp),
  `KNOCK_DELAY_MS`; **knock dizisi düz metin dosyada tutulmaz**, Keychain'de (`USBMonitor_<ÖNEK>_Knock`). Bağlan ve key gönderme, bağlantıdan
  önce diziyi otomatik gönderir (bash `/dev/tcp|udp`: portlar hiçbir sürecin komut satırında görünmez; takılmaz, en çok ~1 sn/vuruş).
  Durum göstergesi knock **göndermez**; knock'lı sunucuda port kapalıysa **🔒** gösterir. Keychain/ayar bozuksa bağlantı denenmez.
  Sunucu tarafı (knockd) ayrı bir pakettir; bu sürümde yoktur. Klasik knocking şifreli değildir (taramalardan saklanma katmanıdır).

## [3.3.0] - 2026-10-12

> **Paket altyapısı geldi.** `components.lock` şimdilik **boştur**; ilk paket (linux-hardening) hazır olunca eklenecek. Altyapı, paket kurulumunu
> imzalı, kilitli ve doğrulanabilir yapar (bkz. [docs/package-standard.md](docs/package-standard.md)). Mevcut sunucu/bağlantı davranışı değişmedi.

### Eklendi
- **Paket kilit dosyası ve imza doğrulama (Aşama 2.0):** `components.lock` (şimdilik boş) ve `sistem/Helpers/Components.sh`: katı ayrıştırıcı
  (bilinmeyen/yinelenen anahtar, bozuk değer = hata; dosya `source` edilmez), arşiv sha256'sı kilitle aynı olmalı, imza `sshpocket-component`
  ad alanıyla doğrulanır (çekirdek `sshpocket-release` imzası yeniden oynatılamaz). Kilitte olmayan paket reddedilir.
- **Paketin güvenli kurulumu (Aşama 2.1):** `sistem/Helpers/ComponentsInstall.sh`: HTTPS indirme (boyut sınırlı), arşiv denetimi (`..`, mutlak yol,
  farklı kök, symlink/hardlink/aygıt reddi), `component.json` kimlik+sürüm eşleşmesi, `components/<id>/<sürüm>/` + `current` (düz metin),
  eski sürüm kalır, geri sürüme düşülmez, kurulum özetleri her çalıştırmadan önce yeniden doğrulanabilir.
- **Bildirim okuma ve sözleşme doğrulama (Aşama 2.2):** `component.json` (`python3 -I` + stdlib `json`) tam şema denetimi:
  `sshpocket_api`, `runner`, profiller, eylemler (`cmd`'de kabuk meta karakteri yok, `effects`, `requires` döngüsüz), değişkenler, `invoke.append`;
  bilinmeyen zorunlu özellik ve daha yeni `sshpocket_api` reddedilir. Etkin `confirm`: paket yalnızca sıkılaştırabilir (`destructive` →
  sunucu adı yazdırma). `comp_prepare` kurulu paketi bütünlükle doğrular ve bilgiyi verir.
- **`./start.sh --doctor` ve venv önbelleği (Aşama 2.3):** `--doctor` ön koşulları denetler (ssh araçları, `nc`, Keychain, Python aralığı,
  `venv`/`ensurepip`, disk, ağ); **yalnızca okur ve çözüm komutunu gösterir, Homebrew/pip/sudo çalıştırmaz.** Paket bağımlılıkları için
  `ComponentsVenv.sh`: aralığa uyan Python seçimi, yalnızca hash'li `requirements.txt` (`-r/-e/--index-url` reddedilir),
  `~/.cache/sshpocket/venv/<paket>-<ortam-kimliği>` önbelleği, `pip --require-hashes --only-binary :all:` yalnızca venv içine; aynı ortam
  kimliğinde sağlıklı venv varsa hiçbir şey kurulmaz.
- **Paket yönetimi komutları (Aşama 2.4a):** `./start.sh --components list` (kilit ↔ kurulu durumu, ağsız), `sync [--yes]` (eksik/eski paketi
  kilitteki sürümle, imza doğrulayarak, onayla kurar; bozulmuş kurulumu silmeden `<sürüm>.bozuk-<tarih>` olarak kenara alıp yeniden kurar),
  `check-new` (kilitten daha yeni yayın var mı: **yalnızca bilgi**, kurulmaz; yeni sürüm yeni sshpocket sürümüyle gelir).
  `--update` başarılıysa **yeni kodla** paketler kilide göre eşitlenir; menüde kilitte paket varsa **📦 Paketler** girdisi görünür.

### Değişti
- Ok tuşlu seçim artık ⚙️ Ayarlar, **Sunucuları yönet** ve Keychain passphrase menülerinde de çalışır (başlıkla birlikte); `UI=numbers` ile
  hepsi numaralıya döner.

## [3.2.0] - 2026-10-11

### Eklendi
- **Ekran cilası (1/2):** her ekranda başlık + ekmek kırıntısı (`Ana menü › ubuntutest`) ve alttaki tuş ipucu satırı; sunucu satırlarında
  `kullanıcı@ip[:port]` özeti. Renk yalnızca terminalde ve `NO_COLOR` tanımsızsa; boru/test çıktısı düz metindir.
- **Ok tuşlu seçim (ekran cilası 2/2):** ana menü ve sunucu menüsünde ↑↓ (veya `j`/`k`) ile gez, Enter ile aç, `←`/`q`/`0`/Esc ile geri.
  Numara yazıp Enter de çalışır (iki haneli dahil, Backspace ile düzeltilir). Saf bash; terminal değilse (boru, betik, test) eski
  numaralı menü kullanılır. ⚙️ Ayarlar'a `UI` eklendi (`auto` | `numbers` | `arrows`): ok tuşları sorun çıkarırsa `numbers` yapın
  (ya da `SSHPOCKET_UI=numbers`). İmleç her çıkışta (Ctrl-C dahil) geri açılır.

## [3.1.1] - 2026-10-11

### Düzeltildi
- **Ana menüye dönerken takılma:** macOS `nc -w` bağlantı beklemesini sınırlamadığından kapalı/erişilemeyen sunucuda durum kontrolü
  ~75 sn sürebiliyordu (durum göstergesi 3.1.0'da varsayılan açık olunca belirgin oldu). Kontrol artık süre dolunca öldürülür
  (⚙️ Ayarlar'daki süre, 1-5 sn); bağlanmadan önceki port kontrolü en çok 5 sn bekler.

## [3.1.0] - 2026-10-11

### Eklendi
- **⚙️ Ayarlar** (ana menü): `sshpocket.conf` (kökte, gitignore'lu; güncellemede korunur). Şimdilik iki ayar: durum göstergesi (`STATUS`) ve
  durum kontrol süresi (`STATUS_TIMEOUT`, 1-5 sn). Öncelik: ortam değişkeni (`SSHPOCKET_STATUS` vb.) > dosya > varsayılan.
  Dosya `source` edilmez; yalnızca bilinen anahtarlar okunur, değerler doğrulanır.

### Değişti
- **Durum göstergesi (🟢/🔴/⚪) artık varsayılan AÇIK** (Finder'dan `start.command` ile açınca da görünür). Kapatmak için ⚙️ Ayarlar
  veya `SSHPOCKET_STATUS=0`.
- **`q` = geri/çıkış:** ana menüde `q` çıkış yapar (0 ile aynı); alt menülerde `0) Geri (q)` ipucu gösterilir.

## [3.0.0] - 2026-10-11

> **Veri düzeni değişti (büyük sürüm).** Sunucular artık `servers/<ad>/server.env` altında; eski `sistem/Modules/<ad>/` sunucularınız
> **otomatik taşınır** (`./start.sh --migrate`, önce `--dry-run`). Eski sürümler yeni düzeni okuyamaz; geri dönmek isterseniz
> `servers/.migrated-<tarih>/` altındaki eski klasörleri `sistem/Modules/` altına geri koyun. Keychain'deki passphrase'ler aynen geçerlidir.

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

[Unreleased]: https://github.com/syhgorath/sshpocket/compare/v3.5.1...HEAD
[3.5.1]: https://github.com/syhgorath/sshpocket/compare/v3.5.0...v3.5.1
[3.5.0]: https://github.com/syhgorath/sshpocket/compare/v3.4.0...v3.5.0
[3.4.0]: https://github.com/syhgorath/sshpocket/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/syhgorath/sshpocket/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/syhgorath/sshpocket/compare/v3.1.1...v3.2.0
[3.1.1]: https://github.com/syhgorath/sshpocket/compare/v3.1.0...v3.1.1
[3.1.0]: https://github.com/syhgorath/sshpocket/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/syhgorath/sshpocket/compare/v2.2.0...v3.0.0
[2.2.0]: https://github.com/syhgorath/sshpocket/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/syhgorath/sshpocket/releases/tag/v2.1.0
