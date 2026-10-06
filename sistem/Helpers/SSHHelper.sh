#!/usr/bin/env bash
# SSHHelper.sh - Keychain tabanlı passphrase yönetimi ve SSH başlatma
# Passphrase hiçbir zaman diske yazılmaz: macOS Keychain'de durur ve
# SSH_ASKPASS (Helpers/askpass.sh) üzerinden ssh-add'e doğrudan aktarılır.

SSH_KEYCHAIN_SERVICE="USBMonitor"

# Keychain'deki passphrase hesabının adı
# Parametre: $1 - modül öneki (büyük harf, örn: RPI)
ssh_keychain_account() {
    echo "USBMonitor_${1}_Passphrase"
}

# Passphrase Keychain'de kayıtlı mı?
# Parametre: $1 - modül öneki
ssh_has_passphrase() {
    security find-generic-password -a "$(ssh_keychain_account "$1")" \
        -s "$SSH_KEYCHAIN_SERVICE" >/dev/null 2>&1
}

# SSH key'i (gerekirse Keychain'deki passphrase ile) agent'a ekle
# Parametreler: $1 - modül öneki, $2 - key dosyası
ssh_agent_add() {
    local prefix="$1"
    local ssh_key="$2"
    local fingerprint
    fingerprint=$(ssh-keygen -lf "$ssh_key" 2>/dev/null | awk '{print $2}')

    if [ -n "$fingerprint" ] && ssh-add -l 2>/dev/null | grep -q "$fingerprint"; then
        echo "✅ SSH key zaten agent'ta" >&2
        return 0
    fi

    echo "🔐 SSH key agent'a ekleniyor (Keychain passphrase'i ile)..." >&2
    SSH_ASKPASS="$SISTEM_PATH/Helpers/askpass.sh" \
    SSH_ASKPASS_REQUIRE=force \
    DISPLAY="${DISPLAY:-:0}" \
    ASKPASS_ACCOUNT="$(ssh_keychain_account "$prefix")" \
    ASKPASS_SERVICE="$SSH_KEYCHAIN_SERVICE" \
        ssh-add "$ssh_key" </dev/null >/dev/null 2>&1

    if [ -n "$fingerprint" ] && ssh-add -l 2>/dev/null | grep -q "$fingerprint"; then
        echo "✅ SSH key agent'a eklendi" >&2
        return 0
    fi
    echo "⚠️  Key agent'a eklenemedi, ssh passphrase'i kendisi soracak" >&2
    return 1
}

# Yeni bir Terminal penceresinde ssh çalıştırır
# Parametreler: $1 - kullanıcı, $2 - ip, $3 - port, $4 - key dosyası
# Ortam: SSH_VERBOSE=1 ise -v ekler
ssh_connect() {
    local user="$1" ip="$2" port="${3:-22}" ssh_key="$4"

    local -a args=(ssh)
    [ "${SSH_VERBOSE:-0}" = "1" ] && args+=(-v)
    args+=(-p "$port")
    [ -f "$ssh_key" ] && args+=(-i "$ssh_key" -o IdentitiesOnly=yes)
    # Host key ilk bağlantıda kullanıcıya sorulur (otomatik kabul yok)
    args+=(-o PreferredAuthentications=publickey,keyboard-interactive)
    args+=(-o PasswordAuthentication=no)
    args+=("${user}@${ip}")

    # Boşluklu yollar (iCloud, USB adı) için kabuk kaçışı
    local cmd
    cmd=$(printf '%q ' "${args[@]}")

    echo "🔌 SSH bağlantısı kuruluyor: ${user}@${ip}:${port}"

    if command -v osascript >/dev/null 2>&1; then
        # AppleScript string kaçışı
        local as_cmd="${cmd//\\/\\\\}"
        as_cmd="${as_cmd//\"/\\\"}"
        if osascript -e 'tell application "Terminal"' \
                     -e 'activate' \
                     -e "do script \"${as_cmd}\"" \
                     -e 'end tell' >/dev/null 2>&1; then
            echo "✅ Terminal penceresi açıldı"
            return 0
        fi
        echo "⚠️  Terminal açılamadı, bu pencerede bağlanılıyor" >&2
    fi
    "${args[@]}"
}
