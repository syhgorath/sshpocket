# linux-hardening: kullanım notları

`linux-hardening` paketini sshpocket üzerinden bir sunucuda çalıştırırken bilinmesi gerekenler. Bu belge deneyimlerden (gerçek bir Ubuntu 26.04 VM'inde
`rollback_status` → `preview` → `apply`) çıkarıldı; paketin kendi belgesi için paketin `README.md`/`HOWTO.md` dosyalarına bakın.

## Akış

| Adım | Komut (ya da menü: sunucu › 🛡️ Paketler) | Sunucuyu değiştirir mi? |
|---|---|---|
| Durum | `./start.sh --components run linux-hardening rollback_status <sunucu>` | Hayır |
| Önizleme | `... run linux-hardening preview <sunucu>` | Hayır (`--check`); ufw ve servis durumunu göstermez |
| Uygulama | `... run linux-hardening apply <sunucu>` | **Evet** (SSH, ufw, paketler...); önce taze bir `preview` ve sunucu adını yazma onayı gerekir |

- `BECOME password:` sunucudaki **sudo parolasıdır**; sudo parola istemiyorsa (NOPASSWD) Enter'a basın.
- `preview` kaydı **30 dakika** geçerlidir; `apply` aynı sunucu ve sürüm için yalnızca bu süre içinde açılır.
- USB dışından denerken: `SSHPOCKET_SERVERS_DIR=/Volumes/<usb>/servers ./start.sh --components run ...`.

## ⚠️ Erişim ağı tuzağı (`hardening_ssh_allow_from`)

`apply`, sunucunun güvenlik duvarına (**ufw**) "SSH (22/tcp) yalnızca şu ağlardan" kuralını yazar ve gelen trafiğin geri kalanını **reddeder (deny)**.
İzin verilen ağlar `servers/<ad>/linux-hardening.vars` dosyasındaki `hardening_ssh_allow_from` (virgülle ayrılmış CIDR listesi) ile verilir; değişkenin
**varsayılanı yoktur** (yanlış bir varsayılan sizi dışarıda bırakabilirdi).

**Tuzak:** `apply`'ı VPN'den (örn. `10.99.0.0/24`) çalıştırıp yalnızca VPN ağını yazarsanız, sunucuya daha sonra **VPN olmadan** (aynı ev/lab ağından bile)
bağlanamazsınız. Belirtiler:

- `ping` ve ARP çalışır (ufw bunları engellemez), ama `ssh` **zaman aşımına** uğrar (`Operation timed out`).
- Sunucu ayakta ve sağlamdır; kural tam olarak istendiği gibi çalışıyordur.

**Önlem:** `apply`'dan önce sunucuya bağlanabileceğiniz **tüm** ağları listeye yazın, örneğin VPN + yerel ağ:

```
hardening_ssh_allow_from=10.99.0.0/24,192.168.1.0/24
```

Listeyi değiştirmek sunucuyu kendiliğinden değiştirmez; yeni değerin işlemesi için `preview` + `apply` yeniden çalıştırılır. Paket, `apply` sırasında
**o anki bağlantının** kaynak adresinin listede olduğunu doğrular (aksi halde durur), ama *sonradan kullanacağınız* ağları bilemez.

**Erişimi kaybettiyseniz:** sunucunun konsolundan (hypervisor/ekran) `sudo ufw allow from <ağ>/24 to any port 22` ya da VM snapshot'ına dönün.
Sonra `.vars` dosyasını düzeltip `apply`'ı yeniden çalıştırın ki dosya ile sunucu tutarlı kalsın.

## Bağlanılamıyorsa: hata ipuçları

Sunucunun işletim sistemi algılanamazsa sshpocket, ssh'ın hatasını sınıflandırıp ne yapılacağını söyler (`↳` satırı):

| ssh hatası | ipucu |
|---|---|
| `Operation/Connection timed out` | Sunucuya ulaşılamıyor: VPN/ağ açık mı? `ufw` bu ağdan SSH'a izin vermiyor olabilir (`hardening_ssh_allow_from`) |
| `No route to host` / `Network is unreachable` | Ağ yolu yok: VPN açık mı, doğru ağda mısınız? |
| `Connection refused` | `sshd` çalışmıyor ya da `server.env` PORT yanlış |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host key **değişmiş**: sunucu yeniden kurulduysa `ssh-keygen -R`; aksi halde araya girilmiş olabilir, bağlanmayın |
| `Host key verification failed` / `No … host key is known` | Önce sshpocket ile bir kez bağlanıp host key'i kabul edin |
| `Permission denied` | Anahtar reddedildi: doğru anahtar mı, `authorized_keys`'te mi, ajanda mı? |
| `Too many authentication failures` | `MaxAuthTries` düşük (hardening 3 yazar); ajandaki fazla anahtarı temizleyin |
| `Connection reset` / `kex_exchange_identification` | Çok başarısız denemeden sonra `fail2ban` engellemiş olabilir; biraz bekleyin |

Hata metni sunucudan gelebileceği için denetim karakterleri temizlenir, 160 karaktere kesilir ve kabuğa verilmez.

## Geri alma güvenlik ağı

`apply` SSH'ı değiştirdikten sonra denetleyiciden **yeni bir SSH bağlantısı** açıp doğrular, başarılıysa güvenlik ağını kapatır. Doğrulama başarısız olursa ya da
bağlantı kaybolursa sunucu `hardening_rollback_timeout` (varsayılan 300 sn) sonra **SSH drop-in'ini ve ufw'yi** önceki duruma döndürür; o sürede erişim
olmayabilir. Paketler, sysctl, auditd, fail2ban ve AIDE geri alınmaz.

**İki durum, Docker LAB'ında gerçek `systemd` ile denendi** (`bats test/e2e/components.bats`; LAB'da süre 30 sn):

| Durum | Ne olur |
|---|---|
| Yeni bağlantı doğrulaması **başarısız** (örn. kural bağlantınızı kesti) | Playbook hemen yedekten geri yükler (`ROLLBACK - restore previous state`) ve durur; sunucu hardening öncesi hâlinde, `apply` kaydı `fail` |
| **Denetleyici kaybolur** (bilgisayar kapanır, VPN düşer; playbook ortada ölür) | Sunucu `armed` kalır; `hardening_rollback_timeout` sn sonra zamanlayıcı SSH drop-in'ini siler ve ufw'yi eski hâline getirir (`armed=no`). Kurtarılana kadar bekleyin, ardından yeniden bağlanın |

Durumu görmek için `rollback_status` eylemi (`installed`, `armed`, `timer`, `remaining_seconds`) ya da menüdeki Hazırlık bloğu.

## Denemek için güvenli laboratuvar (Docker)

Gerçek bir sunucuyu riske atmadan akışı (`preview` → `apply`, erişim ağı tuzağı, hata yolları) denemek için tek kullanımlık, systemd'li bir **Ubuntu 26.04
Docker LAB'ı** vardır: `./test/e2e/lab/up.sh && bats test/e2e/components.bats`. Sınırları (çekirdek paylaşılır, `auditd` taklit edilir) ve kurulum için
[test/e2e/lab/README.md](../test/e2e/lab/README.md). Gerçek bir VM'de son doğrulama yine önerilir.

## Platformlar: Ubuntu, Proxmox VE, Raspberry Pi
- **Profil kapısı (sshpocket):** sunucunun `os-release` `ID-VERSION_ID` değeri paketin `supported` profillerinden biri olmalı. Paket **0.6.0** ile `ubuntu-26.04` ve `debian-13` desteklenir.
  **Proxmox VE 9 ve Raspberry Pi OS da `debian-13` görünür**; sshpocket bunları ayıramaz, kapıyı geçerler. (0.4.0'a kadar `debian-13` desteklenmediği için Proxmox hostu bu kapıda reddediliyordu.)
- **Platform denetimi (paket):** asıl koruma paketin preflight'ındadır. Proxmox VE hostu (`/etc/pve` ya da `pveversion`) **`generic` platformla ASLA sertleştirilmez**; hiçbir bayrak (`hardening_allow_unsupported` dahil)
  bunu atlatmaz ve `--check` (preview) içinde de çalışır. Proxmox hostunda gerçek değişiklik için `hardening_platform=proxmox-host` **ve** `hardening_pve_apply=true` gerekir; yanlış platform seçimi (ör. Ubuntu'da `proxmox-host`) da durur.
- **Platformu ayarlamak:** `hardening_platform` (`generic` | `proxmox-host` | `raspberry-pi`) sunucu başına bir paket değişkenidir: 📝 Değişkenler ekranından ya da `servers/<ad>/linux-hardening.vars` dosyasından (`hardening_platform=proxmox-host`). Serbest metin olarak gösterilir; yanlış değerde paket durur.
- Proxmox üstündeki **sıradan Ubuntu VM'leri** etkilenmez: `generic` platformla normal şekilde sertleştirilir. Proxmox hostunun **güvenlik duvarı** `playbooks/pve-firewall.yml` ile ayrıdır ve sshpocket'te henüz bir eylem olarak sunulmaz.
- Önce snapshot (Proxmox için host disk imajı); önce `preview`.

## Bilinen küçük pürüzler
- Paket **0.3.0+** ile giderildi: `Could not match supplied host pattern ... ubuntu` uyarısı ve `INJECT_FACTS_AS_VARS` kullanımdan kaldırma uyarıları (linux-hardening#35, #36). 0.6.0 koşusunda ikisi de görünmüyor, ikinci `apply` `changed=0` (LAB).
