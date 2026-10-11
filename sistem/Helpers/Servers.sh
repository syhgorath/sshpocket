#!/usr/bin/env bash
# Servers.sh - Sunucu veri katmanı
#
# Yeni biçim:  servers/<ad>/server.env   (IP, USER, PORT, KEY, OS)   + key dosyaları
# Eski biçim:  sistem/Modules/<ad>/.env  (<ÖNEK>_IP, <ÖNEK>_USER, ...) + üretilmiş <Ad>Module.sh
# Her iki biçim okunur; yazarken bulunan biçim korunur. Taşıma (migration) ayrı bir adımdır.
#
# GÜVENLİK: servers/ altından hiçbir dosya `source` edilmez; yalnızca server.env güvenli ayrıştırıcıyla okunur.
# Gerektirir: Validate.sh (module_name_valid), ModuleFiles.sh (module_prefix), SSHModule.sh (_ssh_env_get),
#             SSHModuleEdit.sh (_ssh_env_set), RegisterModules.sh

# servers/ klasörü: SSHPOCKET_SERVERS_DIR ile ya da uygulama kökünün yanında
servers_dir() {
    if [ -n "${SSHPOCKET_SERVERS_DIR:-}" ]; then
        printf '%s' "$SSHPOCKET_SERVERS_DIR"
        return 0
    fi
    local root
    root=$(cd "${SISTEM_PATH:?SISTEM_PATH tanımlı değil}/.." && pwd)
    printf '%s' "$root/servers"
}

# Ayar dosyasının yolu (yeni biçim varsa server.env, yoksa eski .env)
# Parametre: $1 - sunucu klasörü
srv_env_file() {
    if [ -f "$1/server.env" ]; then
        printf '%s' "$1/server.env"
    else
        printf '%s' "$1/.env"
    fi
}

# Yeni biçim mi?
srv_is_current() {
    [ -f "$1/server.env" ]
}

# Biçime göre anahtar adı: yeni → IP, eski → <ÖNEK>_IP
# Parametreler: $1 - önek (büyük harf), $2 - anahtar (IP|USER|PORT|KEY|OS), $3 - sunucu klasörü
srv_key_name() {
    if srv_is_current "$3"; then
        printf '%s' "$2"
    else
        printf '%s_%s' "$1" "$2"
    fi
}

# Değer oku. Parametreler: $1 - klasör, $2 - önek, $3 - anahtar
srv_get() {
    local f
    f=$(srv_env_file "$1")
    [ -f "$f" ] || return 1
    _ssh_env_get "$f" "$(srv_key_name "$2" "$3" "$1")"
}

# Değer yaz. Parametreler: $1 - klasör, $2 - önek, $3 - anahtar, $4 - değer
srv_set() {
    local f
    f=$(srv_env_file "$1")
    _ssh_env_set "$f" "$(srv_key_name "$2" "$3" "$1")" "$4"
}

# servers/ altındaki geçerli sunucu adları (server.env'i olan, adı kurala uyan; gizli klasörler hariç)
srv_names() {
    local d p n
    d=$(servers_dir)
    [ -d "$d" ] || return 0
    for p in "$d"/*/; do
        [ -d "$p" ] || continue
        n=$(basename "$p")
        module_name_valid "$n" || continue
        [ -f "${p}server.env" ] || continue
        printf '%s\n' "$n"
    done
}

# servers/ içindekileri ana menüye kaydeder (eski modüllerden ÖNCE çağrılır)
RegisterServers() {
    local n
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        RegisterModules "$(module_prefix "$n")" "MainMenu" "server:$n"
    done < <(srv_names)
}

# Menü girdisi çalıştırılabilir mi? ("server:<ad>" ya da fonksiyon adı)
EntryExists() {
    case "$1" in
        server:*) module_name_valid "${1#server:}" ;;
        *)        declare -F "$1" >/dev/null 2>&1 ;;
    esac
}

# Menü girdisini çalıştırır
RunEntry() {
    case "$1" in
        server:*) server_run "${1#server:}" ;;
        *)        "$1" ;;
    esac
}

# Sunucu menüsü
server_run() {
    local n="$1"
    module_name_valid "$n" || { echo "⚠️  Geçersiz sunucu adı: $n" >&2; return 1; }
    ssh_module_run "$(module_prefix "$n")" "$(servers_dir)/$n"
}

# Durum simgesi (Menu.sh paralel çağırır)
server_status() {
    local n="$1"
    module_name_valid "$n" || { printf '⚪'; return 0; }
    ssh_module_status "$(module_prefix "$n")" "$(servers_dir)/$n"
}

# Menü satırı için kısa özet: kullanıcı@ip[:port] (bilgi eksik/geçersizse boş)
server_summary() {
    local n="$1" d ip user port
    module_name_valid "$n" || return 0
    d="$(servers_dir)/$n"
    ip=$(srv_get "$d" "$(module_prefix "$n")" IP) || return 0
    user=$(srv_get "$d" "$(module_prefix "$n")" USER)
    port=$(srv_get "$d" "$(module_prefix "$n")" PORT)
    [ -n "$ip" ] && [ -n "$user" ] || return 0
    ssh_validate_target "$ip" "$user" "${port:-22}" 2>/dev/null || return 0
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        printf '%s@%s:%s' "$user" "$ip" "$port"
    else
        printf '%s@%s' "$user" "$ip"
    fi
}
