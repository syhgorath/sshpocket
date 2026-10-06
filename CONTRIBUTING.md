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
