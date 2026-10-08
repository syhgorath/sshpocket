#!/usr/bin/env bash
# SSHModuleEdit.sh - Modül ayarlarını (.env) ve Keychain kaydını güncelleme
# Gerektirir: Validate.sh, SSHModule.sh (_ssh_env_get), SSHHelper.sh (Keychain/agent yardımcıları)

# .env içinde bir anahtarın değerini günceller (yoksa sona ekler); diğer satırlar ve yorumlar korunur.
# Değer kabuğa verilmez, yalnızca printf ile yazılır. Dosya izni 600 yapılır.
# Parametreler: $1 - .env dosyası, $2 - anahtar, $3 - değer
_ssh_env_set() {
    local file="$1" want="$2" value="$3"
    local tmp line trimmed key found=0
    tmp=$(mktemp "${file}.XXXXXX") || return 1
    if [ -f "$file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            key=""
            trimmed="${line#"${line%%[![:space:]]*}"}"
            case "$trimmed" in
                ''|\#*) ;;
                *=*) key="${trimmed%%=*}"; key="${key%"${key##*[![:space:]]}"}" ;;
            esac
            if [ "$key" = "$want" ] && [ "$found" -eq 0 ]; then
                printf '%s=%s\n' "$want" "$value" >> "$tmp"
                found=1
            else
                printf '%s\n' "$line" >> "$tmp"
            fi
        done < "$file"
    fi
    if [ "$found" -eq 0 ]; then
        printf '%s=%s\n' "$want" "$value" >> "$tmp"
    fi
    chmod 600 "$tmp"
    mv "$tmp" "$file"
}

# IP/kullanıcı/port/key yolunu soru-cevapla günceller (Enter = değiştirme)
# Parametreler: $1 - öneki, $2 - modül klasörü
ssh_module_edit() {
    local prefix="$1" module_dir="$2"
    local env_file="$module_dir/.env"
    local cur_ip cur_user cur_port cur_key ip user port key verr

    if [ ! -f "$env_file" ]; then
        : > "$env_file"
        chmod 600 "$env_file"
    fi
    cur_ip=$(_ssh_env_get "$env_file" "${prefix}_IP")
    cur_user=$(_ssh_env_get "$env_file" "${prefix}_USER")
    cur_port=$(_ssh_env_get "$env_file" "${prefix}_PORT")
    cur_port="${cur_port:-22}"
    cur_key=$(_ssh_env_get "$env_file" "${prefix}_KEY")

    echo ""
    echo "Bilgileri güncelle (köşeli parantez = mevcut değer, Enter = değiştirme)"
    read -r -p "IP/host [${cur_ip}]: " ip || return 1
    ip="${ip:-$cur_ip}"
    read -r -p "Kullanıcı [${cur_user}]: " user || return 1
    user="${user:-$cur_user}"
    read -r -p "Port [${cur_port}]: " port || return 1
    port="${port:-$cur_port}"
    read -r -p "Key yolu [${cur_key:-modül klasöründeki varsayılan}] (Enter = aynı, - = varsayılana dön): " key || return 1
    case "$key" in
        '') key="$cur_key" ;;
        -)  key="" ;;
    esac

    if ! verr=$(ssh_validate_target "$ip" "$user" "$port" 2>&1); then
        echo "⚠️  Kaydedilmedi: $verr"
        return 1
    fi

    _ssh_env_set "$env_file" "${prefix}_IP" "$ip"
    _ssh_env_set "$env_file" "${prefix}_USER" "$user"
    _ssh_env_set "$env_file" "${prefix}_PORT" "$port"
    if [ -n "$key" ] || [ -n "$cur_key" ]; then
        _ssh_env_set "$env_file" "${prefix}_KEY" "$key"
    fi

    local check="$key"
    if [ "${check:0:1}" = "~" ]; then check="$HOME${check:1}"; fi
    if [ -n "$check" ] && [ ! -f "$check" ]; then
        echo "ℹ️  Uyarı: key dosyası şu an yok: $check"
    fi
    echo "✅ Güncellendi: ${user}@${ip}:${port}"
}

# Keychain'deki passphrase kaydını kaydet/güncelle/sil
# Parametreler: $1 - öneki, $2 - private key yolu (doğrulama için)
ssh_keychain_manage() {
    local prefix="$1" ssh_key="$2" choice account
    account=$(ssh_keychain_account "$prefix")

    echo ""
    if ssh_has_passphrase "$prefix"; then
        echo "Keychain kaydı: ✅ var ($account)"
    else
        echo "Keychain kaydı: ❌ yok"
    fi
    echo "  1) Kaydet / güncelle"
    echo "  2) Sil"
    echo "  0) Geri"
    read -r -p "Seçim [0]: " choice || return 0
    case "${choice:-0}" in
        1)
            # -w son argüman: passphrase komut satırında görünmez, güvenli sorulur
            if security add-generic-password -U -a "$account" -s "$SSH_KEYCHAIN_SERVICE" -w; then
                echo "✅ Keychain'e kaydedildi"
                if [ -f "$ssh_key" ]; then
                    echo "🔎 Doğrulanıyor (key agent'tan çıkarılıp passphrase ile yeniden ekleniyor)..."
                    ssh-add -d "$ssh_key" >/dev/null 2>&1
                    if ssh_agent_add "$prefix" "$ssh_key"; then
                        echo "✅ Key açıldı, passphrase doğru."
                    else
                        echo "⚠️  Doğrulanamadı: passphrase yanlış olabilir. Seçenek 1 ile tekrar deneyin."
                    fi
                fi
            else
                echo "⚠️  Kaydedilemedi"
            fi
            ;;
        2)
            if security delete-generic-password -a "$account" -s "$SSH_KEYCHAIN_SERVICE" >/dev/null 2>&1; then
                echo "✅ Keychain kaydı silindi"
            else
                echo "ℹ️  Silinecek kayıt yok"
            fi
            ;;
    esac
}
