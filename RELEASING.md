# Sürüm çıkarma (bakımcı rehberi)

Güncelleme (`--update`) yalnızca **sizin imza anahtarınızla imzalı** paketleri kurar. Bu rehber, anahtarın
bir kez nasıl kurulacağını ve her sürümün nasıl imzalanıp yayınlanacağını anlatır.

> **Özel imza anahtarı asla** repoya, CI/GitHub Secrets'a, sohbete veya e-postaya konmaz.
> Yalnızca bakımcının makinesinde (tercihen passphrase ile) durur. Kaybolursa/sızarsa aşağıdaki
> "Anahtar rotasyonu" bölümüne bakın.

## 1) Bir kez: imza anahtarını üretin

```bash
ssh-keygen -t ed25519 -a 100 -C "sshpocket release signing" -f ~/.ssh/sshpocket_release
```

- Güçlü bir **passphrase** belirleyin (boş bırakmayın).
- `~/.ssh/sshpocket_release` **özel** anahtardır: paylaşmayın.
- `~/.ssh/sshpocket_release.pub` **public** anahtardır: paylaşılabilir.

Public anahtarı `sistem/release_signers` dosyasına tek satır olarak ekleyin
(`AAAA...` yerine `.pub` dosyasındaki değeri yazın):

```
sshpocket-release namespaces="sshpocket-release" ssh-ed25519 AAAA...
```

Commit'leyin. **Bu satır, kullanıcıların kurulu kopyalarına gömülen güven noktasıdır**; bir kullanıcı bu
anahtara sahip bir sürüm kurduktan sonra, sonraki güncellemeleri yalnızca bu anahtarla doğrular.

## 2) Her sürüm

1. `VERSION`'ı artırın, `CHANGELOG.md`'de `[Unreleased]` içeriğini yeni sürüm başlığına taşıyın.
2. `bats test` ve ShellCheck temiz olsun; commit'leyin ve `git push` yapın, CI'ın yeşil olmasını bekleyin.
3. Etiket:

   ```bash
   git tag -a vX.Y.Z -m "sshpocket X.Y.Z" && git push origin vX.Y.Z
   ```

4. İmzalı paketi üretin (passphrase sorulur):

   ```bash
   SSHPOCKET_SIGNING_KEY=~/.ssh/sshpocket_release ./scripts/release.sh
   ```

   Betik çalışma alanının temiz olduğunu, etiketin HEAD'i gösterdiğini ve CHANGELOG başlığını denetler,
   `git archive` ile paketi üretir, imzalar ve **yayından önce kendisi doğrular**.
5. GitHub'da `vX.Y.Z` Release'ini açın ve `dist/sshpocket-X.Y.Z.tar.gz` ile `dist/sshpocket-X.Y.Z.tar.gz.sig`
   dosyalarını **Assets**'e yükleyin. Dosya adları tam olarak bu biçimde olmalı.
6. Kendiniz deneyin: eski sürümlü bir kopyada `./start.sh --update`.

## Neden "kaynak arşivi" değil de kendi paketimiz?
GitHub'ın otomatik "Source code" arşivleri imzalı değildir ve içerikleri (sıkıştırma ayrıntıları) sabit
garanti edilmez. İmzalı paketi biz üretiriz; `.gitattributes` ile `test/`, `scripts/`, `.github/` gibi geliştirme
dosyaları paketin dışında kalır.

## Güven modeli (kısaca)
- Kurulu kopya, `sistem/release_signers` içindeki anahtarlarla doğrular. Yeni sürümün kendi `release_signers`
  dosyası **kurulumdan sonra** devreye girer; yani bir güncelleme, yalnızca *mevcut* güvenilen anahtarla
  imzalıysa kabul edilir.
- Hesap/depo ele geçirilse bile saldırgan imza anahtarına sahip değilse sahte paket kurulamaz.
- İmza, paketin ne olduğunu kanıtlar ama **güncel** olduğunu kanıtlamaz; bu yüzden uzak sürüm kurulu sürümden
  büyük olmalı ve paketin içindeki `VERSION` etikete eşit olmalıdır.

## Anahtar rotasyonu / sızıntı
- **Planlı değişim:** yeni anahtar üretin; `release_signers`'a yeni satırı **ekleyin** (eskisini silmeyin),
  sürümü eski anahtarla imzalayıp yayınlayın. Kullanıcılar bunu kurunca yeni anahtara da güvenir. Sonraki
  sürümü yeni anahtarla imzalayın, bir süre sonra eskisini kaldırın.
- **Özel anahtar sızdıysa:** eski anahtarla imzalı güncellemeler artık güvenilir değildir. Kullanıcılara GitHub
  Release notunda ve README'de duyuru yapın; yeni kurulumu elle (`git clone` / release indirme) yapmaları ve
  `release_signers`'ı yeni anahtarla değiştirmeleri gerekir. Bu yüzden anahtarı iyi koruyun.
