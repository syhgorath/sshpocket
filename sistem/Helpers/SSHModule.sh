#!/usr/bin/env bash
# SSHModule.sh - Tüm SSH modülleri için ortak çalıştırıcı
# Her modül yalnızca kendi önekini ve klasörünü verir; mantık burada tek yerde durur.
#
# Modül klasörü beklentisi:
#   .env                 -> <ÖNEK>_IP, <ÖNEK>_USER, <ÖNEK>_PORT (gizli bilgi YOK)
#   id_ed25519_<önek>    -> SSH private key (küçük harf önek)
# Passphrase: macOS Keychain (hesap: USBMonitor_<ÖNEK>_Passphrase)

# .env dosyasından tek bir anahtarı güvenli okur (eval/source kullanmaz)
# Parametreler: $1 - dosya, $2 - anahtar adı
_ssh_env_get() {
    local file="$1" want="$2" line key value
    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in ''|\#*) continue ;; esac
        case "$line" in *=*) ;; *) continue ;; esac
        key="${line%%=*}"
        value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        # Çevreleyen tırnakları kaldır
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
            *) value="${value%%[[:space:]]#*}"   # tırnaksız değerde satır sonu yorumunu at
               value="${value%"${value##*[![:space:]]}"}" ;;
        esac
        if [ "$key" = "$want" ]; then
            printf '%s' "$value"
            return 0
        fi
    done < "$file"
    return 1
}

# Parametreler:
#   $1 - öneki (büyük harf, örn: RPI)
#   $2 - modül klasörü
ssh_module_run() {
    local prefix="$1"
    local module_dir="$2"
    local lower
    lower=$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]')
    local env_file="$module_dir/.env"
    local ssh_key="$module_dir/id_ed25519_${lower}"

    clear
    echo "====================================="
    echo "$prefix SSH Bağlantı"
    echo "====================================="
    echo ""

    if [ ! -f "$env_file" ]; then
        echo "⚠️  .env bulunamadı: $env_file"
        echo ""
        echo "Şablondan oluşturun:"
        echo "  cp \"$module_dir/.env.example\" \"$env_file\""
        return 1
    fi

    local ip user port
    ip=$(_ssh_env_get "$env_file" "${prefix}_IP")
    user=$(_ssh_env_get "$env_file" "${prefix}_USER")
    port=$(_ssh_env_get "$env_file" "${prefix}_PORT")
    port="${port:-22}"

    if [ -z "$ip" ] || [ -z "$user" ]; then
        echo "⚠️  .env içinde eksik bilgi var:"
        echo "  ${prefix}_IP:   $([ -z "$ip" ] && echo "❌ eksik" || echo "✅")"
        echo "  ${prefix}_USER: $([ -z "$user" ] && echo "❌ eksik" || echo "✅")"
        return 1
    fi

    # Komut/seçenek enjeksiyonuna karşı doğrulama
    local verr
    if ! verr=$(ssh_validate_target "$ip" "$user" "$port" 2>&1); then
        echo "⚠️  .env: $verr"; return 1
    fi

    # İsteğe bağlı: modül klasörü yerine mevcut bir key (örn: ~/.ssh/id_ed25519)
    local custom_key
    custom_key=$(_ssh_env_get "$env_file" "${prefix}_KEY")
    if [ -n "$custom_key" ]; then
        if [ "${custom_key:0:1}" = "~" ]; then custom_key="$HOME${custom_key:1}"; fi
        ssh_key="$custom_key"
    fi

    if [ ! -f "$ssh_key" ]; then
        echo "⚠️  SSH key bulunamadı: $ssh_key"
        return 1
    fi
    chmod 600 "$ssh_key" 2>/dev/null

    echo "📡 Bağlantı Bilgileri:"
    echo "  IP:   $ip"
    echo "  User: $user"
    echo "  Port: $port"
    echo "  Key:  $ssh_key"
    if ssh_has_passphrase "$prefix"; then
        echo "  Passphrase: ✅ Keychain"
        ssh_agent_add "$prefix" "$ssh_key"
    else
        echo "  Passphrase: ℹ️  Keychain'de yok (ssh gerekirse soracak)"
    fi
    echo ""

    local choice
    echo "  1) Bağlan"
    echo "  2) Public key'i sunucuya gönder"
    echo "  0) Geri"
    read -r -p "Seçim [1]: " choice
    case "${choice:-1}" in
        1) ;;
        2) ssh_copy_key "$user" "$ip" "$port" "$ssh_key"; return $? ;;
        *) return 0 ;;
    esac
    echo ""

    echo "🔍 Port kontrolü..."
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "$ip" "$port" 2>/dev/null; then
            echo "✅ Port $port açık"
        else
            echo "⚠️  Port $port kapalı veya erişilemiyor"
            local answer
            read -r -p "Yine de bağlanılsın mı? (y/n) " answer
            case "$answer" in y|Y) ;; *) echo "İptal edildi."; return 1 ;; esac
        fi
    else
        echo "ℹ️  'nc' yok, port kontrolü atlandı"
    fi
    echo ""

    Log "INFO" "$prefix SSH bağlantısı: ${user}@${ip}:${port}"
    ssh_connect "$user" "$ip" "$port" "$ssh_key"
}

# Menüde gösterilecek durum simgesi: 🟢 port açık, 🔴 kapalı/erişilemiyor, ⚪ ayar yok
# Parametreler: $1 - öneki, $2 - modül klasörü
ssh_module_status() {
    local prefix="$1" module_dir="$2"
    local env_file="$module_dir/.env" ip port
    if [ ! -f "$env_file" ]; then printf '⚪'; return 0; fi
    ip=$(_ssh_env_get "$env_file" "${prefix}_IP")
    port=$(_ssh_env_get "$env_file" "${prefix}_PORT")
    port="${port:-22}"
    if [ -z "$ip" ] || ! ssh_validate_target "$ip" "x" "$port" 2>/dev/null; then
        printf '⚪'; return 0
    fi
    if command -v nc >/dev/null 2>&1 && nc -z -w 1 "$ip" "$port" 2>/dev/null; then
        printf '🟢'
    else
        printf '🔴'
    fi
}
