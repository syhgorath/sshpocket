# Güvenlik politikası / Security policy

Bu araç SSH anahtarları ve passphrase'lerle çalıştığı için güvenlik açıklarını ciddiye alıyoruz.

## Açık bildirme

**Lütfen güvenlik açıklarını herkese açık issue olarak açmayın.**
GitHub'daki **Security → Report a vulnerability** (özel bildirim) yolunu kullanın.
*Please do not open public issues for vulnerabilities; use GitHub's private "Report a vulnerability" form.*

Bildirimde şunlar yardımcı olur: etkilenen dosya/komut, tekrar adımları, etkisi. **Gerçek anahtar,
parola veya sunucu bilgisi eklemeyin.**

Proje tek kişilik ve gönüllü bir çalışma; yanıt süresi için söz veremem ama makul sürede bakmaya çalışırım.

## Kapsam

- Kapsam içi: komut/seçenek enjeksiyonu, gizli bilginin diske/log'a sızması, güvensiz geçici dosya, yanlış
  izinler, doğrulama atlatma.
- Kapsam dışı: USB'nin fiziksel olarak ele geçirilmesi ve şifrelenmemiş bir USB'de duran private key'ler
  (USB'yi şifreleyin; bkz. README), sunucu tarafı yapılandırma hataları.

## Desteklenen sürümler

Yalnızca `main` dalının son hâli.
