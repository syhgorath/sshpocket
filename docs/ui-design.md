# Tasarım: arayüz (UI), fzf ve teknoloji alternatifleri

> **Durum: TASARIM / TARTIŞMA, henüz uygulanmadı ve kararlar KESİNLEŞMEDİ.** (2026-10-11)
> Amaç: iyi bir TUI, ama küçük maliyetle. Kod yazılmadan önce bu belge güncellenir.

## 1. Sorun
- "Bazen neredeyim bilmiyorum": ekranlar arasında **yönelim** (hangi menü, hangi sunucu, durum) yok.
- Numaralı seçim (1, 2, 3) sunucu eklenip silindikçe **kayar**, ezberlenemez.
- Durum göstergesi (🟢/🔴) varsayılan olarak kapalı (`SSHPOCKET_STATUS=1`); `start.command` bu değişkeni vermediği için görünmüyor.
- Alt kısımda tuş ipucu yok ("0 geri mi, çık mı?").

## 2. İlkeler
| Alan | Kural |
|---|---|
| Gezinme | **Yön tuşları:** ↑ ↓ seç, Enter gir, ← geri. Numara/harf kısayolları ek olarak kalır. |
| **Yıkıcı veya geri dönüşü zor işler** (sil, yeniden adlandır, `apply`, `rollback_now`) | **Sunucu adını yazarak onayla** (bugünkü silme gibi). Hata yaptırmayan kalıp, yaygınlaştırılır. |
| Geri alınabilir sorular | `y/n` |
| Yönelim | Her ekranda **başlık + ekmek kırıntısı** (`Ana menü › ubuntutest`), alttaki **tuş ipucu satırı**, sunucu satırında `kullanıcı@ip` ve durum. |
| Terminal değilse (pipe, test, betik) | Eski **numaralı menü** (ve renksiz çıktı). Testler bozulmaz. |
| Renk | Yalnızca `[ -t 1 ]` ve `NO_COLOR` tanımsızsa. |

## 3. Taslak
```
sshpocket <sürüm>                                        USB: <ad>
────────────────────────────────────────────────────────────────
Ana menü

  🟢 ubuntutest    kullanici@10.0.0.5
  🔴 proxmox       admin@10.0.0.9:2222
  ────────────────────────────
  ➕ Yeni sunucu ekle
  ...
────────────────────────────────────────────────────────────────
↑↓ seç · Enter aç · ← geri · / ara · ? yardım
```
(IP'ler örnektir.)

## 4. Tuş okuma (saf bash) için notlar
- `read -rsn1`; ok tuşu `ESC [ A|B|C|D`. macOS bash **3.2**'de kesirli `read -t` yoktur, bu yüzden tek başına `ESC` bağlanmaz;
  geri için `←`, `0` veya `q`.
- İmleç gizlenir ve **çıkışta (trap) mutlaka geri açılır**, `stty` durumu geri yüklenir; yoksa terminal bozuk kalır.
- Seçim mantığı, tuş okuyucuyu sahte tuş dizisiyle değiştirerek test edilir (pty gerekmez).
- Emoji genişliği bazı yazı tiplerinde hizayı kaydırabilir; vurgu satırın tamamına uygulanır.

## 5. fzf (isteğe bağlı iyileştirme)
**Tercih sırası:** sistemde `fzf` varsa onu kullan → yoksa USB'deki ikili → o da yoksa saf bash ok tuşlu menü → numaralı menü.

| Konu | Karar / not |
|---|---|
| Dağıtım | USB'de **iki ikili**: `darwin_arm64` ve `darwin_amd64` (her biri ~3-4 MB). Mimari `uname -m` ile seçilir. |
| Güven | Sürüm ve **SHA-256**, imzalı sshpocket sürümüyle gelen `components.lock`'ta sabitlenir; çalıştırmadan önce doğrulanır. fzf'nin kendi sürüm imzası ayrıca doğrulanmalı (BİLİNMİYOR). |
| Lisans | MIT; lisans metni ikilinin yanında bulunur. |
| exFAT/FAT USB | Çalıştırma izni garanti değil: başarısızsa geçici klasöre kopyalayıp oradan çalıştır. |
| Gatekeeper | `curl` ile inen dosyaya karantina işareti konmaz; Apple Silicon'da imzasız ikili çalışmaz (ad-hoc imza yeter). **Doğrulanmadı.** |
| Tehdit modeli | Özet doğrulaması **kazara bozulmaya** karşı korur. USB'ye yazabilen kararlı bir saldırgan `start.sh`'i de değiştirebilir; gerçek koruma **USB şifrelemesi** ve imzalı güncellemelerdir. |

## 6. Test edilen / edilmeyen ortamlar
| Ortam | Durum |
|---|---|
| Intel (x86_64), macOS 15.7.9, bash 3.2.57, OpenSSH 9.9p2 | Denendi |
| Apple Silicon (arm64) | **Denenmedi** |
| macOS 26 ve sonrası | **Denenmedi** |

**Apple Silicon / yeni macOS doğrulama listesi** (ilk fırsatta bir M-serisi Mac'te):
1. `start.sh` ve `start.command` açılıyor mu (Gatekeeper)?
2. `security` (Keychain) izin penceresi ve passphrase kaydı/doğrulaması.
3. `ssh-add` + `SSH_ASKPASS` akışı (OpenSSH sürümü farkı).
4. `ssh-copy-id`, `osascript` ile Terminal açma.
5. (fzf eklenirse) arm64 ikilisi çalışıyor mu, karantina, exFAT'tan çalıştırma.
6. Bats testleri ve ShellCheck aynı sonucu veriyor mu.

## 7. Teknoloji alternatifleri
Mevcut yığın: **bash + ShellCheck + Bats**. Karar için ölçütler: (a) Intel/ARM ve macOS sürümleri arasında taşınabilirlik,
(b) çalışma zamanı bağımlılığı (USB'yle yabancı Mac'e takıldığında), (c) TUI kalitesi, (d) geliştirme/token maliyeti, (e) test edilebilirlik.

| Seçenek | TUI kalitesi | USB/yabancı Mac | Maliyet | Not |
|---|---|---|---|---|
| **Bash + ok tuşu (+ isteğe bağlı fzf)** | İyi (liste/arama için yeterli) | ✅ bağımlılık yok | **Düşük** | Önerilen ilk adım |
| **Go + Bubble Tea** | Çok iyi (form, ilerleme, canlı panel) | ✅ tek statik ikili, tek makineden Intel+ARM derlenir | **Orta-yüksek** (yeniden yazım) | Hızlı geliştirme, olgun TUI kütüphaneleri, kolay çapraz derleme |
| Rust + ratatui | Çok iyi | ✅ tek ikili | Yüksek | Bellek güvenliği; öğrenme/derleme maliyeti daha yüksek |
| Python + Textual | Mükemmel | ❌ Python çalışma zamanı gerekir (macOS'unki eski/yok) | Orta | Paketleme (PyInstaller) büyük ve kırılgan |
| Node + Ink | İyi | ❌ Node gerekir | Orta | Önerilmez |
| Swift (menü çubuğu / SwiftUI) | GUI | ✅ yalnızca macOS, Keychain yerel | Yüksek | TUI hedefinden farklı; Linux yok |
| Tauri/Electron | GUI | ✅ ama ağır | Yüksek | Aşırı |
| Mevcut araçlar (`~/.ssh/config` üzerinde TUI'ler, örn. `sshs`, `lazyssh`) | İyi | ✅ | Çok düşük | **İncelenmedi**; bizim farkımız USB, Keychain yaşam döngüsü, imzalı güncelleme, hardening |

## 8. Strateji (öneri)
1. **Şimdi:** bash'te kal; arayüz cilası (başlık, ekmek kırıntısı, ipucu, durum varsayılan açık) ve ok tuşlu seçim. Maliyet düşük.
2. **Veri ve sözleşmeler dilden bağımsız tutulur** (`servers/*/server.env`, `components.lock`, `component.yml`, Docker e2e testleri).
   Böylece ileride Go/Rust ön yüzü aynı veriyi okuyup adım adım devralabilir ("kademeli geçiş"), baştan yazmak gerekmez.
3. **Geçiş tetikleyicileri** (herhangi biri gerçekleşirse Go düşünülür): form/ilerleme/canlı log gibi bash'te zorlanan TUI ihtiyaçları;
   Apple Silicon/yeni macOS'ta bash/fzf taşınabilirlik sorunları; katkıcı talebi; test bakım maliyeti.
4. **Ucuz deney (spike):** karar vermeden önce, tek oturumluk küçük bir Go prototipi (menü + durum + bağlan) yapılıp
   "gerçekten daha mı iyi hissettiriyor?" sorusu cevaplanabilir. Çekirdeğe dokunmaz.

## 9. Açık kararlar
- Durum göstergesi varsayılan açık mı? (Öneri: evet.)
- `←` geri mi, `0`/`q` mu? Yazarak arama şimdi mi sonra mı?
- fzf'yi USB'ye gömmek mi, "sistemde varsa" mı?
- Go spike'ı yapılsın mı?
