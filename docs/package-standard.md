# sshpocket paket standardı (v1)

> **Durum: v1 KABUL EDİLDİ (kararlar §13), henüz uygulanmadı.** Amaç, "sshpocket'ın içinde çalışacak bir paket nasıl olmalı?" sorusunu
> **bir kez, yazılı** cevaplamak; yükleyici (Aşama 2) ve menü (Aşama 3) bu belgeye göre yazılır.
> Ayrıntılı gerekçeler ve bileşen modelinin tamamı için bkz. [components-design.md](components-design.md);
> bu belge onun **paket yazarına dönük, normatif** özetidir. Çelişki olursa bu belge (onaylandıktan sonra) kazanır.

## 1. Fikir

Bir **paket**, sshpocket'a şunu söyleyen imzalı bir arşivdir: *"Ben şuyum, şu sunuculara uyarım, şu eylemleri yaparım,
şu değişkenleri alırım, şunlara ihtiyacım var."* sshpocket de pakete şunu söyler: *"Şu sunucuya, şu bağlantı bilgisiyle,
şu onaylardan sonra."* sshpocket paketin **içini bilmez**; yalnızca bildirimi doğrular, kapıları uygular ve eylemi çalıştırır.

Hedef (kabul ölçütü): **ikinci bir paket (örn. "Docker kur") sshpocket kodunda hiçbir değişiklik yapmadan**, yalnızca
kilit dosyasına bir satır eklenerek menüye gelir.

## 2. Terimler

| Terim | Anlamı |
|---|---|
| **Paket** | Bu standarda uyan, imzalı, sürümlü arşiv (bugünkü adıyla "bileşen"). |
| **Bildirim** | Paketin kökündeki `component.json` (makine-okunur kaynak). `component.yml` isteğe bağlı insan-okunur kaynaktır. |
| **Eylem** | Bildirimde tanımlı, menüden tetiklenen tek iş (audit, preview, apply, …). |
| **Kilit dosyası** | sshpocket reposundaki `components.lock`: hangi paket, hangi sürüm, hangi özet, hangi imzacı. |
| **Kontrol makinesi** | sshpocket'ın çalıştığı Mac. |
| **Hedef** | Eylemin uygulandığı sunucu. |

## 3. Paket biçimi

- **Dosya adı:** `<id>-<sürüm>.tar.gz` ve yanında `<id>-<sürüm>.tar.gz.sig`; GitHub Release varlığı, etiket `v<sürüm>`.
- **Arşiv kökü:** tek dizin `<id>-<sürüm>/`; bildirim `<id>-<sürüm>/component.json`.
- **İmza:** `ssh-keygen -Y sign`, ad alanı **`sshpocket-component`** (çekirdek güncellemesi `sshpocket-release`; ad alanları
  bilerek ayrı, bir paket imzası çekirdek güncellemesi olarak yeniden oynatılamaz).
- **Doğrulama (sshpocket yapar):** yalnızca HTTPS; imza `components.lock`'taki `signers` ile; sha256 kilitle aynı; arşivde
  `..`, mutlak yol, symlink/hardlink ve kök dizin dışı içerik yok; `component.json`'daki `id`/`version` dosya adı ve etiketle aynı;
  kurulu sürümden **eski sürüm kurulmaz**.
- **Kurulum yeri:** `components/<id>/<sürüm>/`, etkin sürüm `components/<id>/current` (düz metin dosyası; exFAT'ta symlink yok).
  Eski sürüm kalır. **Her çalıştırmadan önce** dosya özetleri yeniden doğrulanır.
- **İçerik kuralları:** paket, kullanıcı verisi (key, parola, sunucu bilgisi) **içermez**; sshpocket de pakete bunları dosya
  olarak teslim etmez (bkz. §7).

## 4. Bildirim: `component.json`

Alan tablosu (`*` zorunlu):

| Alan | Tür | Açıklama |
|---|---|---|
| `id` * | string `^[a-z][a-z0-9-]*$` | Paket kimliği; kilit dosyası ve klasör adıyla aynı |
| `version` * | semver | Etiket ve dosya adıyla aynı |
| `sshpocket_api` * | tamsayı | Bu belgenin sürümü (şimdi `1`); sshpocket desteklemiyorsa reddeder |
| `name`, `description` | string | Menüde gösterilir |
| `runner` * | `ansible` \| `script` | Eylemin nasıl çalıştırılacağı (§7) |
| `requires.control` | nesne | `python` aralığı, gerekli paketler (hash'li `requirements.txt`) |
| `requires.target` | nesne | Hedefte gereken asgari yazılım (örn. `python >=3.9`) |
| `profiles[]` * | `{id, status}` | `supported` \| `planned`; profil, algılanan OS ile eşleşmezse eylem açılmaz |
| `actions` * | nesne | §5 |
| `vars[]` | nesne listesi | §6 |
| `inventory_group` | string | Yalnızca `ansible` runner: hedefin konacağı grup |
| `invoke.append[]` | nesne listesi | `cmd`'ye eklenecek argümanlar (§7) |

Örnek (kısaltılmış):
```json
{
  "id": "linux-hardening", "version": "0.1.0", "sshpocket_api": 1,
  "name": "Linux sertleştirme", "runner": "ansible",
  "requires": { "control": { "python": ">=3.12" }, "target": { "python": ">=3.9" } },
  "profiles": [ { "id": "ubuntu-26.04", "status": "supported" } ],
  "inventory_group": "hardening",
  "actions": {
    "preview": { "cmd": "ansible-playbook playbooks/harden.yml --check --diff", "effects": [], "requires_sudo": true },
    "apply":   { "cmd": "ansible-playbook playbooks/harden.yml", "effects": ["installs-package", "changes-config"],
                 "requires_sudo": true, "requires": ["preview"] }
  }
}
```

## 5. Eylem modeli

| Alan | Anlamı |
|---|---|
| `cmd` * | Paket köküne göre çalıştırılacak komut; sshpocket kabuğa **dizge olarak vermez**, sözcüklere ayırıp doğrudan çalıştırır |
| `effects` * | `[]` salt okunur · `installs-package` · `changes-config` · `destructive` (birden çok olabilir; menü **hepsini** gösterir) |
| `requires_sudo` | sudo parolası gerekir; Ansible'ın kendi isteminden alınır (diske/komut satırına/Keychain'e yazılmaz) |
| `requires[]` | Ön koşul eylemler; **zorlamayı sshpocket yapar** (önizleme başarılı olmadan `apply` açılmaz) |
| `confirm` | `none` \| `yes-no` \| `type-server-name` (yıkıcı/geri dönüşü zor işler için sunucu adı yazdırılır) |
| `interactive` | Kullanıcıdan istem bekler; sshpocket gizli/sessiz çalıştırmaz, terminali devreder |
| `outputs` | Çıktı sözleşmesi (§8) |
| `set` | Eylem düzeyi **sabit değişkenler** (nesne, en çok 8): `{"hardening_pve_apply": true}`. Bu eylem çalışırken sshpocket bu değerleri kullanıcının `.vars` değerinin **üstüne yazar**. Yalnızca `vars`'ta tanımlı **bool, int (min/max içinde), enum, string, path** değişkenler ve türüne uygun değerler olabilir; liste olamaz ve `outputs.dir_var` değişkeni ezilemez. Amaç: aynı playbook'un güvenli ve gerçek koşu eylemleri kullanıcı ayarından bağımsız olsun (örn. `*_preview` eylemi `…_apply=false`'u, `*_apply` eylemi `true`'yu zorlar; aksi halde kullanıcının `.vars`'ındaki `true` yüzünden "önizleme" gerçek koşuya dönüşür). `warn_if` yine zorlanan değere uygulanır |
| `warnings[]` | Menüde gösterilecek açık notlar (örn. "önizleme firewall değişikliğini göstermez") |

Kurallar: `effects` boş olmayan eylem onaysız çalışmaz; `destructive` ve `changes-config` en az `yes-no`, geri alınamayanlar
`type-server-name` ister; paket bunu **gevşetemez**, yalnızca sıkılaştırabilir.

## 6. Değişkenler

```json
"vars": [
  { "name": "hardening_ssh_allow_from", "type": "list[cidr]", "required": true,
    "description": "SSH'a izin verilen yönetim ağları" },
  { "name": "hardening_rollback_enabled", "type": "bool", "default": true,
    "warn_if": false, "description": "false = geri alma güvenlik ağı KAPALI" },
  { "name": "hardening_rollback_timeout", "type": "int", "default": 300, "min": 30, "max": 3600 }
]
```
- Türler: `string`, `bool`, `int`, `path`, `cidr`, `list[<tür>]`, `enum` (+ `values`).
- sshpocket değeri **kendisi doğrular** (tür, aralık, `required`); geçersiz değer çalıştırmayı başlatmaz.
- **Gizli değer yoktur:** `secret` türü bu sürümde **yok**. Parola/anahtar paket değişkeni olamaz; sshpocket bunları
  değişken dosyasına yazmaz.
- `warn_if`: değer buna eşitse arayüz uyarı gösterir ve onay ister. Onay yalnızca **değiştiren** eylemlerde ve başka bir eylemin ön koşulu olan eylemlerde (örn. `preview`) sorulur; salt okunur durum/rapor eylemleri (`rollback_status`) sormaz. **Varsayılanı `warn_if`'e eşit olan değişken her çalıştırmada uyarı tetikler**: varsayılandan sapmayı yakalamak için `warn_if`'i varsayılanın TERSİ yapın.
- `required: true`: değişken zorunludur; eksikse **değiştiren eylemler ve başka bir eylemin ön koşulu olan eylemler** (örn. `preview`) çalışmaz. Salt okunur durum eylemleri (örn. `rollback_status`) zorunlu değişken olmadan da çalışır (verilen değerler yine doğrulanır). Bir değişkeni zorunlu yapan paket, bu eylemlerin onu kullandığından emin olmalıdır.
- Değerler kullanıcı klasöründe geçici, izni 600 olan bir değişken dosyasıyla verilir, iş bitince silinir.

## 7. Çalıştırma sözleşmesi

sshpocket pakete **bağlamı** şöyle verir:

| Runner | Bağlam |
|---|---|
| `ansible` | Geçici inventory (`inventory_group`; `ansible_host/user/port/private_key_file`; izin 600, iş bitince silinir), `-e @<değişken dosyası>`, çalışma dizini = paket kökü (`ansible.cfg` oradan okunur) |
| `script` | Ortam değişkenleri: `SSHPOCKET_HOST`, `SSHPOCKET_USER`, `SSHPOCKET_PORT`, `SSHPOCKET_KEY`, `SSHPOCKET_SERVER` (ad), `SSHPOCKET_VARS_FILE`, `SSHPOCKET_OUT_DIR` |

Her iki runner için ortak kurallar:
- **Parola/passphrase asla verilmez.** Passphrase Keychain→`ssh-agent`'tadır; sudo parolası yalnızca `interactive` istemle girilir.
- Host key doğrulaması **kapatılmaz**; sunucuya daha önce sshpocket ile bağlanılmış olmalı.
- Anahtarın agent'ta olduğu çalıştırmadan önce doğrulanır (`ssh-add -l`).
- Root kullanıcıyla mutating eylem reddedilir; algılanan OS, seçili profille uyuşmuyorsa durulur.
- Çıkış kodu: `0` başarı; sıfırdan farklı = başarısız. sshpocket çıktıyı kullanıcıya olduğu gibi gösterir.

## 8. Çıktı ve veri konumu

- **Hassas çıktı USB'ye yazılmaz.** Çıktı klasörü kullanıcı klasörüdür (`~/.local/share/sshpocket/<id>/<sunucu>/`, dizin 0700,
  dosya 0600); paket bunu `outputs.dir_var` ile alır.
- **Makine-okunur sonuç satırı** (log'dan bağımsız, Ansible çıktı biçimine bağlı olmayan tek satır):
  `SSHPOCKET_RESULT <id>.<eylem> key=value key=value …` — anahtarlar bildirimde `outputs.keys` ile **bildirilir**.
- `outputs.summary`: eylemin yazdığı özet dosyası (JSON); sshpocket okuyup gösterir.
- Her uygulamanın kaydı (tarih, sunucu, paket+sürüm, sonuç) `servers/<ad>/` altında, **gizli bilgi içermeden** tutulur.

## 9. Güvenlik kapıları (paketten bağımsız, sshpocket zorunlu tutar)

1. Kilit dosyasında olmayan paket **çalıştırılmaz** (üçüncü taraf paket yok).
2. Eylem, ön koşul eylemi (`requires`) aynı oturumda başarıyla bitmeden açılmaz.
3. Her çalıştırmadan önce paket dosya özetleri yeniden doğrulanır.
4. Uygulamadan önce özet gösterilir (sunucu, profil, paket sürümü, değişkenler) ve `confirm` kuralı uygulanır.
5. Paket, bildirimde bildirmediği bir eylemi menüye ekleyemez; bildirilen `effects` gerçek davranışın **alt kümesi olamaz**
   (paket sahibinin sorumluluğu, kod incelemesiyle denetlenir).
6. Yeni sürüm bildirimi **bilgilendirir**; onay olmadan kilitteki sürüm kalır.

## 10. Sürümleme ve uyumluluk

- Paket sürümü semver. `sshpocket_api` tamsayıdır: **geriye uyumsuz** değişiklikte artar; sshpocket yalnızca bildiği aralığı
  çalıştırır, diğerlerini "bu paket daha yeni bir sshpocket gerektirir" diye reddeder.
- Yeni **isteğe bağlı** alanlar `sshpocket_api`'yi artırmaz; bilinmeyen alanlar yok sayılır, bilinmeyen **zorunlu** davranışlar
  `required_features[]` ile bildirilir ve sshpocket tanımıyorsa reddeder.

## 11. linux-hardening ile uyum (bugünkü durum)

| Standart gereği | linux-hardening v0.1.0 | Yapılacak |
|---|---|---|
| Paket adı, etiket, `.sig`, ad alanı | ✅ | – |
| Arşiv kökü `<id>-<sürüm>/` | ✅ | – |
| `component.json` (makine-okunur) | ❌ yalnızca `component.yml` | **Issue:** paket üretimine YAML'dan türetilmiş `component.json` eklensin (imzalı arşivde) |
| `runner: ansible` alanı | ❌ (örtük) | Issue'ya dahil |
| `effects`, `requires_sudo`, `requires`, `invoke`, `inventory_group` | ✅ | – |
| `confirm`, `warnings[]` | ❌ | Issue'ya dahil (şimdilik sshpocket varsayılanları: yıkıcılarda sunucu adı yazdırma) |
| `vars[]` tür/varsayılan/uyarı | ❌ ad listesi | Mevcut issue [#29](https://github.com/syhgorath/linux-hardening/issues/29) |
| `rollback_status` makine-okunur sonuç satırı | ❌ | Mevcut issue [#28](https://github.com/syhgorath/linux-hardening/issues/28); biçim bu belgenin §8'ine uyarlanmalı |
| Hassas çıktı kullanıcı klasörüne | ✅ (`hardening_scan_dir`) | – |

> Kural: linux-hardening reposunda kod/PR yazılmaz; yukarıdaki farklar **issue** olarak açılır.

## 12. Yeni paket yazma kontrol listesi

- [ ] `component.json` (`sshpocket_api: 1`), her eylem için `effects` ve `requires_sudo` eksiksiz
- [ ] Mutating eylemin salt okunur bir `preview` ön koşulu var; önizlemenin **göstermediği** şeyler `warnings` içinde yazılı
- [ ] Hiçbir değişken parola/anahtar taşımıyor; hassas çıktı `outputs.dir_var` ile kullanıcı klasörüne gidiyor
- [ ] `requirements.txt` hash'li (`pip-compile --generate-hashes`), `--only-binary :all:` ile kurulabiliyor
- [ ] Sürüm üçlüsü tutarlı: `VERSION`, `component.json`, etiket; arşiv kökü `<id>-<sürüm>/`
- [ ] `ssh-keygen -Y sign -n sshpocket-component` ile imzalı; `.sig` yanında
- [ ] Salt okunur olmayan eylemin geri alma/kurtarma yolu belgelenmiş (kapsamı dürüstçe yazılı)
- [ ] sshpocket reposuna **tek satır** (kilit dosyası) ekleyen PR açıldı; başka kod değişikliği gerekmedi

**Otomatik denetim:** bu listenin mekanik kısmını `./start.sh --components validate <kurulu-paket | dizin | <id>-<sürüm>.tar.gz> [--strict]` denetler
(statik: ansible/ssh/ağ çalıştırmaz, paketten hiçbir şey çalıştırmaz; arşiv yalnızca güvenliyse açılır). Çıktı `--doctor` gibi ✅ / ⚠️ / ❌; ❌ varsa çıkış kodu 1,
`--strict` ile uyarılar da hata sayılır; `--unsigned` imzalamadan önceki denetimde `.sig` uyarısını atlar. Paket reposunun CI'ı için `sistem/Helpers/component_validate.py` ve `component_manifest.py` kopyalanıp
`python3 -I component_validate.py <dizin>` çalıştırılabilir.

| Madde | `validate` |
|---|---|
| `component.json` geçerli, `sshpocket_api: 1`, en az bir `supported` profil | ❌ hata |
| Sürüm üçlüsü: `VERSION` = `component.json`; arşiv adı/kökü `<id>-<sürüm>/` | ❌ hata |
| `requirements.txt` var, hepsi `==` sabit ve `--hash=sha256:` içerir; URL/VCS/`-e`/`-r` yok | ❌ hata |
| Her eylemin `cmd`'si `ansible-playbook <var olan, paket içi, göreli playbook>` | ❌ hata |
| Paket içinde sembolik bağ, özel anahtar bloğu, `.env`/`id_*`/`.pem` yok | ❌ hata |
| Yapılandırma değiştiren eylemin salt okunur ön koşulu (`preview`), `warnings`'i ve `requires_sudo`'su var | ⚠️ uyarı. Ön koşul beklenmeyenler: adı `rollback`/`recover`/`restore`/`undo` ile başlayan kurtarma eylemleri (kontrol kaybından sonra da çalışmalı) ve yalnızca `installs-package` etkisi olan eylemler (örn. denetim tarayıcısı kuran `audit`) |
| `outputs.format` varsa playbook'ta `SSHPOCKET_RESULT <id>.<eylem>` çıktısı var | ⚠️ uyarı (dinamik üretilen metin yanlış alarm verebilir) |
| Değişken adı parola/token/anahtar izlenimi vermiyor (bool/int değişkenler hariç); her değişken kullanılıyor; üst veri (tür) var | ⚠️ uyarı |
| Değiştiren eylem için belgede geri alma/kurtarma anlatılmış (anahtar sözcük) | ⚠️ uyarı |
| `.sig` arşivin yanında | ⚠️ uyarı (imzayı `scripts/lock-component.sh` doğrular) |
| Geri almanın kapsamı dürüstçe yazılı mı; kilit PR'ının tek satır olması | elle (insan kontrolü) |

## 13. Kararlar (2026-10-11)

| # | Soru | Karar |
|---|---|---|
| 1 | Bildirim biçimi | **`component.json`** (okuma `python3 -I` + stdlib `json`). `component.yml` yalnızca insan-okunur kaynak; paket üretimi JSON'u ondan türetir. |
| 2 | `runner: script` | Şema ve bağlam (§7) **tanımlı**; ilk uygulama yalnızca `ansible`. `script` ikinci paketle birlikte kodlanır. |
| 3 | `confirm` | sshpocket **asgari kuralı** koyar (§5); paket yalnızca sıkılaştırabilir, gevşetemez. |
| 4 | Sonuç satırı | Tek satır `SSHPOCKET_RESULT <id>.<eylem> key=value …` (§8); linux-hardening#28 buna uyarlanır. |
| 5 | Bildirim özeti kilitte | **Hayır**: bildirim zaten imzalı arşivin içinde; kilit dosyası arşivin sha256'sını taşır. |

Bu kararlarla standart **v1 kabul edilmiştir**; uygulama sırası: 2.0 (kilit dosyası + imza doğrulama) → 2.1 (kurulum)
→ 2.2 (bildirim okuma) → 2.3 (`--doctor` + venv) → 2.4 (`--update` entegrasyonu). linux-hardening tarafı farkları (§11) **issue** olarak izlenir.

## 14. Kararlar (2026-10-16, linux-hardening#33 / sshpocket#40)

| # | Soru | Karar |
|---|---|---|
| 6 | `invoke.append` yer tutucuları | `<inventory>` ve `<server>` kabul (`^<[a-z0-9_ -]{1,40}>$`). `-e @<dosya>` pakette **yok**: değişken dosyasını sshpocket verir (§7). |
| 7 | `-i` / `--limit` | **Çalıştırıcı ekler** (geçici inventory'yi sshpocket üretir); paket bunları `invoke.append`'e yazmaz. `invoke.append` yalnızca ek bayraklar içindir (örn. `--ask-become-pass`, `interactive`). Yazılırsa çalıştırıcı yinelenen `-i`/`--limit` girdilerini atlar. |
| 8 | `outputs.prefix` | `<id>.<eylem>` kısmını sshpocket bildirimdeki `id` ve eylem adından **türetir**. Pakette `prefix` varsa bununla birebir uyuşmalı; uyuşmazsa paket reddedilir. `keys` bildirimde kalır. |
| 9 | Sonuç satırı ayrıştırma | Satır başı varsayılmaz: `^\s*SSHPOCKET_RESULT\s+` ile aranır (Ansible'ın `msg:` bloğu altında girintili gelir). |
