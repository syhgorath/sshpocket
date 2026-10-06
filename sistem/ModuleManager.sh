#!/usr/bin/env bash
# ModuleManager.sh - Modülleri listele / sil / yeniden adlandır
# Kullanım:
#   bash sistem/ModuleManager.sh list
#   bash sistem/ModuleManager.sh remove <ad>
#   bash sistem/ModuleManager.sh rename <eski_ad> <yeni_ad>
# SSHPOCKET_MODULES_DIR ile Modules klasörü değiştirilebilir (testler için).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SSHPOCKET_MODULES_DIR:-$SCRIPT_DIR/Modules}"

# shellcheck source=Helpers/Validate.sh
source "$SCRIPT_DIR/Helpers/Validate.sh"
# shellcheck source=Helpers/ModuleFiles.sh
source "$SCRIPT_DIR/Helpers/ModuleFiles.sh"
# shellcheck source=Helpers/SSHModule.sh
source "$SCRIPT_DIR/Helpers/SSHModule.sh"

cmd_list() {
    local d name upper ip user port found=0
    for d in "$MODULES_DIR"/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        upper=$(module_prefix "$name")
        ip=$(_ssh_env_get "$d/.env" "${upper}_IP" 2>/dev/null)
        user=$(_ssh_env_get "$d/.env" "${upper}_USER" 2>/dev/null)
        port=$(_ssh_env_get "$d/.env" "${upper}_PORT" 2>/dev/null)
        printf '  %-18s %s\n' "$name" "${user:+$user@}${ip:-(ayar yok)}${port:+:$port}"
        found=1
    done
    [ "$found" -eq 1 ] || echo "  (modül yok)"
}

# Adı doğrular ve modül klasörünün var olduğunu denetler
_require_module() {
    if ! module_name_valid "$1"; then echo "⚠️  Geçersiz modül adı: '$1'" >&2; return 1; fi
    if [ ! -d "$MODULES_DIR/$1" ]; then echo "⚠️  Modül yok: $1" >&2; return 1; fi
}

cmd_remove() {
    local name="$1"
    _require_module "$name" || return 1
    local upper confirm
    upper=$(module_prefix "$name")
    echo "Silinecek: $MODULES_DIR/$name"
    ls -A "$MODULES_DIR/$name"
    read -r -p "Onaylamak için modül adını yazın ($name): " confirm
    if [ "$confirm" != "$name" ]; then echo "İptal edildi."; return 1; fi
    rm -r "${MODULES_DIR:?}/${name:?}"
    echo "✅ Silindi: $name"
    if command -v security >/dev/null 2>&1 \
        && security find-generic-password -a "USBMonitor_${upper}_Passphrase" -s USBMonitor >/dev/null 2>&1; then
        local del
        read -r -p "Keychain'deki passphrase kaydı da silinsin mi? (y/n) " del
        if [ "$del" = "y" ] || [ "$del" = "Y" ]; then
            security delete-generic-password -a "USBMonitor_${upper}_Passphrase" -s USBMonitor >/dev/null \
                && echo "✅ Keychain kaydı silindi"
        fi
    fi
}

cmd_rename() {
    local old="$1" new="$2"
    _require_module "$old" || return 1
    if ! module_name_valid "$new"; then echo "⚠️  Geçersiz yeni ad: '$new'" >&2; return 1; fi
    if [ -e "$MODULES_DIR/$new" ]; then echo "⚠️  Hedef zaten var: $new" >&2; return 1; fi

    local uold unew ip user port key
    uold=$(module_prefix "$old"); unew=$(module_prefix "$new")
    local env="$MODULES_DIR/$old/.env"
    ip=$(_ssh_env_get "$env" "${uold}_IP"); user=$(_ssh_env_get "$env" "${uold}_USER")
    port=$(_ssh_env_get "$env" "${uold}_PORT"); key=$(_ssh_env_get "$env" "${uold}_KEY")
    port="${port:-22}"

    module_write_files "$MODULES_DIR" "$new" "$ip" "$user" "$port" "$key" || return 1
    # Modül klasöründeki key'leri taşı (varsa)
    if [ -f "$MODULES_DIR/$old/id_ed25519_${old}" ]; then
        mv "$MODULES_DIR/$old/id_ed25519_${old}" "$MODULES_DIR/$new/id_ed25519_${new}"
    fi
    if [ -f "$MODULES_DIR/$old/id_ed25519_${old}.pub" ]; then
        mv "$MODULES_DIR/$old/id_ed25519_${old}.pub" "$MODULES_DIR/$new/id_ed25519_${new}.pub"
    fi
    rm -r "${MODULES_DIR:?}/${old:?}"
    echo "✅ $old → $new"
    echo "ℹ️  Keychain kaydı otomatik taşınmaz. Passphrase kullanıyorsanız yeniden ekleyin:"
    echo "   security add-generic-password -U -a USBMonitor_${unew}_Passphrase -s USBMonitor -w"
}

case "${1:-}" in
    list)   cmd_list ;;
    remove) [ -n "${2:-}" ] || { echo "Kullanım: remove <ad>" >&2; exit 1; }; cmd_remove "$2" ;;
    rename) [ -n "${3:-}" ] || { echo "Kullanım: rename <eski> <yeni>" >&2; exit 1; }; cmd_rename "$2" "$3" ;;
    *) echo "Kullanım: $0 list | remove <ad> | rename <eski> <yeni>" >&2; exit 1 ;;
esac
