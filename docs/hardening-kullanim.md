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

## Geri alma güvenlik ağı

`apply` SSH'ı değiştirdikten sonra denetleyiciden **yeni bir SSH bağlantısı** açıp doğrular, başarılıysa güvenlik ağını kapatır. Doğrulama başarısız olursa ya da
bağlantı kaybolursa sunucu `hardening_rollback_timeout` (varsayılan 300 sn) sonra **SSH drop-in'ini ve ufw'yi** önceki duruma döndürür; o sürede erişim
olmayabilir. Paketler, sysctl, auditd, fail2ban ve AIDE geri alınmaz.

## Bilinen küçük pürüzler (paket tarafı)
- Her çalıştırmada `Could not match supplied host pattern, ignoring: ubuntu` uyarısı: playbook'lar `hosts: "hardening:ubuntu"` der, eski `ubuntu` grubu yoktur. Zararsızdır.
- `INJECT_FACTS_AS_VARS` kullanımdan kaldırma uyarıları: ansible-core 2.24'te `ansible_distribution` yerine `ansible_facts[...]` gerekecek.
