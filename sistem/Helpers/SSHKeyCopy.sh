#!/usr/bin/env bash
# SSHKeyCopy.sh - Public key'i sunucuya gönderir (ssh-copy-id sarmalayıcısı)
#
# Giriş yöntemini ssh-copy-id seçer: önce agent'taki/varsayılan key'ler, olmazsa parola.
# Parola yalnızca ssh'ın kendi isteminde girilir; bu script'e hiç uğramaz.
# PasswordAuthentication'ı kapatmak BİLEREK otomatik yapılmaz (kendinizi dışarıda bırakmayın).

# Parametreler: $1 - kullanıcı, $2 - ip, $3 - port, $4 - private key yolu
ssh_copy_key() {
    local user="$1" ip="$2" port="$3" key="$4"
    local pub="${key}.pub"

    if [ ! -f "$pub" ]; then
        if [ ! -f "$key" ]; then
            echo "⚠️  Key bulunamadı: $key"; return 1
        fi
        echo "ℹ️  .pub yok, private key'den türetiliyor (passphrase istenebilir)..."
        if ! ssh-keygen -y -f "$key" > "$pub"; then
            rm -f "$pub"; echo "⚠️  Public key türetilemedi"; return 1
        fi
    fi

    echo ""
    echo "Hedef:       ${user}@${ip}:${port}"
    echo "Fingerprint: $(ssh-keygen -lf "$pub" | awk '{print $2}')"
    local answer
    read -r -p "Bu public key bu sunucuya eklensin mi? (y/n) " answer
    case "$answer" in y|Y) ;; *) echo "İptal edildi."; return 1 ;; esac

    # Bu key sunucuda zaten kabul ediliyor mu? (etkileşimsiz deneme)
    if [ -f "$key" ] && ssh -o BatchMode=yes -o PasswordAuthentication=no \
            -o KbdInteractiveAuthentication=no -o IdentitiesOnly=yes \
            -o ConnectTimeout=8 -i "$key" -p "$port" "${user}@${ip}" true >/dev/null 2>&1; then
        echo "✅ Bu key sunucuda zaten yetkili, yapılacak bir şey yok."
        return 0
    fi

    # İsteğe bağlı: girişte kullanılacak başka bir key
    local boot=""
    read -r -p "Girişte başka bir key dosyası kullanılsın mı? (yol girin, Enter = agent/parola) " boot
    local -a args=(ssh-copy-id -i "$pub" -p "$port")
    if [ -n "$boot" ]; then
        if [ "${boot:0:1}" = "~" ]; then boot="$HOME${boot:1}"; fi
        if [ ! -f "$boot" ]; then
            echo "⚠️  Dosya yok: $boot"; return 1
        fi
        args+=(-o "IdentityFile=$boot" -o "IdentitiesOnly=no")
    fi
    args+=("${user}@${ip}")

    echo ""
    echo "🔑 ssh-copy-id çalışıyor (gerekirse host key ve parola burada sorulur)..."
    if "${args[@]}"; then
        echo ""
        echo "✅ Key gönderildi. Şimdi 'Bağlan' ile key ile girişi DENEYİN."
        echo "ℹ️  Sunucuda PasswordAuthentication'ı kapatmak istiyorsanız bunu"
        echo "    key ile girişin çalıştığını gördükten sonra ELLE yapın."
        return 0
    fi
    echo "⚠️  ssh-copy-id başarısız oldu"
    return 1
}
