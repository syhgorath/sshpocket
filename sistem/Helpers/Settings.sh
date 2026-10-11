#!/usr/bin/env bash
# Settings.sh - Küçük ayar katmanı: sshpocket.conf (ANAHTAR=değer)
# Öncelik: ortam değişkeni (SSHPOCKET_<ANAHTAR>) > dosya > varsayılan.
# Dosya ASLA source edilmez; yalnızca bilinen anahtarlar okunur, değerler doğrulanır.
# Gerektirir: (SISTEM_PATH ya da SSHPOCKET_CONF)

settings_file() {
    if [ -n "${SSHPOCKET_CONF:-}" ]; then
        printf '%s' "$SSHPOCKET_CONF"
    else
        printf '%s' "${SISTEM_PATH:-.}/../sshpocket.conf"
    fi
}

settings_default() {
    case "$1" in
        STATUS) printf 'on' ;;
        STATUS_TIMEOUT) printf '1' ;;
        UI) printf 'auto' ;;
        *) return 1 ;;
    esac
}

# Değeri normalleştirir (STATUS: 1/true→on, 0/false→off); geçersizse boş yazar, 1 döner
settings_normalize() {
    local key="$1" val="$2"
    case "$key" in
        STATUS)
            case "$val" in
                on|1|true|yes) printf 'on' ;;
                off|0|false|no) printf 'off' ;;
                *) return 1 ;;
            esac ;;
        STATUS_TIMEOUT)
            case "$val" in
                [1-5]) printf '%s' "$val" ;;
                *) return 1 ;;
            esac ;;
        UI)
            case "$val" in
                auto|arrows|numbers) printf '%s' "$val" ;;
                *) return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

# IFS'ten bağımsız (çağıran bağlamda IFS değişmiş olabilir)
settings_known() {
    case "$1" in
        STATUS|STATUS_TIMEOUT|UI) return 0 ;;
        *) return 1 ;;
    esac
}

# Dosyadaki ham değer (son tanım kazanır); yoksa boş
_settings_file_raw() {
    local f
    f=$(settings_file)
    [ -f "$f" ] || return 0
    grep -E "^$1=" "$f" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '\r' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_settings_env_raw() {
    local name="SSHPOCKET_$1"
    printf '%s' "${!name:-}"
}

# Geçerli değer
settings_get() {
    local key="$1" raw val
    settings_known "$key" || return 1
    raw=$(_settings_env_raw "$key")
    if [ -n "$raw" ] && val=$(settings_normalize "$key" "$raw"); then printf '%s' "$val"; return 0; fi
    raw=$(_settings_file_raw "$key")
    if [ -n "$raw" ] && val=$(settings_normalize "$key" "$raw"); then printf '%s' "$val"; return 0; fi
    settings_default "$key"
}

# Değerin kaynağı: env | file | default
settings_source() {
    local key="$1" raw
    raw=$(_settings_env_raw "$key")
    if [ -n "$raw" ] && settings_normalize "$key" "$raw" >/dev/null; then echo env; return 0; fi
    raw=$(_settings_file_raw "$key")
    if [ -n "$raw" ] && settings_normalize "$key" "$raw" >/dev/null; then echo file; return 0; fi
    echo default
}

# Dosyaya yazar (diğer satırlar korunur); geçersiz değer/anahtar reddedilir
settings_set() {
    local key="$1" val f tmp line done_=0
    settings_known "$key" || { echo "Bilinmeyen ayar: $key" >&2; return 1; }
    val=$(settings_normalize "$key" "$2") || { echo "Geçersiz değer: $2" >&2; return 1; }
    f=$(settings_file)
    tmp=$(mktemp "${f}.XXXXXX" 2>/dev/null) || { echo "Ayar dosyası yazılamıyor: $f" >&2; return 1; }
    if [ -f "$f" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                "$key="*) if [ "$done_" -eq 0 ]; then printf '%s=%s\n' "$key" "$val" >> "$tmp"; done_=1; fi ;;
                *) printf '%s\n' "$line" >> "$tmp" ;;
            esac
        done < "$f"
    else
        printf '# sshpocket ayarları (gizli bilgi YAZMAYIN)\n' > "$tmp"
    fi
    if [ "$done_" -eq 0 ]; then printf '%s=%s\n' "$key" "$val" >> "$tmp"; fi
    chmod 644 "$tmp" 2>/dev/null
    mv -f "$tmp" "$f" || { rm -f "$tmp"; echo "Ayar dosyası yazılamıyor: $f" >&2; return 1; }
}

_settings_label() {
    case "$1" in
        STATUS) printf 'Durum göstergesi (🟢/🔴)' ;;
        STATUS_TIMEOUT) printf 'Durum kontrol süresi (sn)' ;;
        UI) printf 'Menü: auto/arrows/numbers' ;;
    esac
}

_settings_note() {
    case "$(settings_source "$1")" in
        env) printf '  (ortam değişkeni SSHPOCKET_%s geçerli; dosya yok sayılır)' "$1" ;;
        default) printf '  (varsayılan)' ;;
    esac
}

# Menü eylemi: ⚙️ Ayarlar
SettingsAction() {
    local choice cur new
    while true; do
        clear
        echo "=== ⚙️  Ayarlar ==="
        echo ""
        printf '  1) %-28s %s%s\n' "$(_settings_label STATUS)" "$(settings_get STATUS)" "$(_settings_note STATUS)"
        printf '  2) %-28s %s%s\n' "$(_settings_label STATUS_TIMEOUT)" "$(settings_get STATUS_TIMEOUT)" "$(_settings_note STATUS_TIMEOUT)"
        printf '  3) %-28s %s%s\n' "$(_settings_label UI)" "$(settings_get UI)" "$(_settings_note UI)"
        echo "  0) Geri (q)"
        echo ""
        if ! read -r -p "Değiştirilecek ayar [0]: " choice; then return 0; fi
        case "${choice:-0}" in
            0|q|Q) return 0 ;;
            1)
                cur=$(settings_get STATUS)
                if [ "$cur" = "on" ]; then new=off; else new=on; fi
                settings_set STATUS "$new" || read -r -p "Enter..." _ || true
                ;;
            3)
                case "$(settings_get UI)" in
                    auto) new=numbers ;;
                    numbers) new=arrows ;;
                    *) new=auto ;;
                esac
                settings_set UI "$new" || read -r -p "Enter..." _ || true
                ;;
            2)
                if ! read -r -p "Süre 1-5 sn [$(settings_get STATUS_TIMEOUT)]: " new; then return 0; fi
                if [ -n "$new" ]; then
                    settings_set STATUS_TIMEOUT "$new" || read -r -p "Enter..." _ || true
                fi
                ;;
        esac
    done
}
