# servers/

Sunucularınızın **verisi** burada durur: her sunucu bir klasördür (`servers/<ad>/`).

```
servers/<ad>/server.env        IP=  USER=  PORT=  KEY=(ops.)  OS=(ops.)
servers/<ad>/id_ed25519_<ad>   private key (passphrase'li; Keychain'de saklanır)
```

- Bu klasörün içeriği **git'e girmez** ve release paketine **dahil edilmez**; güncelleme buraya dokunmaz.
- Buradaki dosyalar **çalıştırılmaz** (yalnızca `server.env` güvenli biçimde okunur).
- Yedeklenecek tek klasör budur.
