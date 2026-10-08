# Katkı rehberi / Contributing

Proje ham ve gelişmeye açık; her türlü katkı (hata raporu, test, belge, çeviri, kod) makbule geçer.
The project is young and open to all kinds of contributions (bugs, tests, docs, translations, code).

## Başlamadan / Before you start

- Büyük bir değişiklik düşünüyorsanız önce bir issue açıp konuşalım.
- **Gizli bilgi paylaşmayın:** issue/PR'a gerçek IP, anahtar, parola, `.env` içeriği veya log yapıştırmayın.
  Gerekirse `192.0.2.x` (örnek aralık) kullanın.

## Geliştirme ortamı

```bash
brew install shellcheck bats-core
shellcheck -x -s bash start.sh start.command sistem/*.sh sistem/Helpers/*.sh sistem/Modules/*/*.sh
bats test
```

PR açmadan önce ikisi de temiz olmalı (CI aynısını çalıştırır; CI'daki ShellCheck bazen yerelden
eski olabilir, o yüzden `info` seviyesindeki uyarıları da düzeltin).

## Uçtan uca testler (isteğe bağlı, Docker gerekir)

Gerçek bir `sshd`'ye karşı (yerel bir Ubuntu konteyneri, yalnızca `127.0.0.1`) `ssh-copy-id` ve key akışlarını dener:

```bash
./test/e2e/up.sh      # konteyneri kurar; rastgele test şifresi test/e2e/.secrets içinde (git'e girmez)
bats test/e2e
./test/e2e/down.sh    # kaldırır (--clean: şifre, host key ve known_hosts kaydını da siler)
```

Varsayılan `bats test` bu klasörü çalıştırmaz; CI'da da yoktur. ssh, `~/.ssh/known_hosts`'a
`[127.0.0.1]:2222` kaydı ekler; `down.sh --clean` temizler.

## Sürüm çıkarma

Yalnızca bakımcı: bkz. [RELEASING.md](RELEASING.md). Güncelleme/imza koduna dokunan PR'lar özellikle dikkatle incelenir;
`test/update.bats` ve `test/release.bats` saldırı senaryolarını (sahte imza, `..`, symlink, eski sürüm sunma) kapsar.

## Kod kuralları

- **bash 3.2 uyumlu** olun (macOS varsayılanı): `declare -A`, `mapfile`, `${var,,}` kullanmayın.
- Dışarıdan gelen her değeri (`.env`, `~/.ssh/config`, kullanıcı girdisi) kabuğa vermeden önce doğrulayın
  (`sistem/Helpers/Validate.sh`). `eval` kullanmayın.
- Gizli bilgiyi diske, log'a veya komut satırına yazmayın (Keychain kullanın).
- Yeni davranış için Bats testi ekleyin (`test/`). Testler gerçek sunucuya, Keychain'e veya
  `~/.ssh`'e dokunmamalı; geçici klasör ve sahte komutlar kullanın (bkz. `test/integration.bats`).
- Yeni modül mantığı `sistem/Helpers/SSHModule.sh` içinde yaşar; modül dosyaları ince kalmalı.

## PR süreci

1. Fork → dal açın (`fix/...`, `feat/...`).
2. Değişikliği ve testi ekleyin; `CHANGELOG.md`'nin *Unreleased* bölümüne bir satır yazın.
3. PR açıklamasında ne/neden yaptığınızı ve nasıl test ettiğinizi yazın.

Yapay zekâ yardımıyla yazılmış katkılar kabul edilir; gönderdiğiniz kodu okuyup anladığınızdan
ve test ettiğinizden emin olun.
