#!/usr/bin/env bash
# ComponentsMenu.sh - Sunucu menüsünde "🛡️ Paketler": paket seç → eylem seç → comp_cli_run (Aşama 3, PR E1)
# Eylemin kendisi comp_cli_run → comp_exec_action zincirinde çalışır (kapılar/onaylar orada); burada yalnızca seçim vardır.
# Gerektirir: Components.sh, ComponentsInstall.sh, ComponentsManifest.sh, ComponentsRunCLI.sh, Servers.sh, UI.sh (isteğe bağlı: ui_pick_arrows)

# comp_menu_installed → kurulu paket kimlikleri (satır satır)
comp_menu_installed() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        [ -n "$(comp_installed_version "$id")" ] && printf '%s\n' "$id"
    done < <(comp_ids 2>/dev/null)
    return 0
}

# comp_menu_available <sunucu-klasörü> → 0: yeni biçimli sunucu ve en az bir kurulu paket var
comp_menu_available() {
    srv_is_current "$1" 2>/dev/null || return 1
    [ -n "$(comp_menu_installed)" ]
}

# _comp_menu_badge <bilgi> <eylem> → "🔍 salt okunur" | "✏️  değişiklik yapar" | "☠️  yıkıcı"
_comp_menu_badge() {
    local eff
    eff=$(comp_action_get "$1" "$2" effects)
    case ",$eff," in
        ",,") printf '🔍 salt okunur' ;;
        *,destructive,*) printf '☠️  yıkıcı' ;;
        *) printf '✏️  değişiklik yapar' ;;
    esac
}

# _comp_menu_pick <başlık-geri> <öğe>... → seçilen numara (geri/hata = 0); UI_PICK_DESCS/UI_PICK_BACK_DESC dinamik kapsamdan okunur
_comp_menu_pick() {
    local back="$1" choice i=1 label; shift
    if declare -F ui_arrows_enabled >/dev/null && ui_arrows_enabled; then
        choice=$(ui_pick_arrows 1 "$back" "$@")
        echo "" >&2
    else
        for label in "$@"; do printf '  %d) %s\n' "$i" "$label" >&2; i=$((i + 1)); done
        printf '  0) %s (q)\n' "$back" >&2
        IFS= read -r -p "Seçim [0]: " choice || { printf '0'; return 0; }
    fi
    case "${choice:-0}" in
        q|Q) choice=0 ;;
    esac
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$#" ]; then printf '%s' "$choice"; else printf '0'; fi
}

# comp_menu_actions <paket> <sunucu> → eylem listesi, seçileni çalıştırır; geri dönene kadar döngü
comp_menu_actions() {
    local id="$1" server="$2" info ver name pick i act eff req
    local -a names labels
    info=$(comp_prepare "$id") || { echo "Paket doğrulanamadı: $id (./start.sh --components list)" >&2; return 1; }
    ver=$(comp_info_get "$info" version)
    names=(); labels=()
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        names+=("$name")
        req=$(comp_action_get "$info" "$name" requires)
        labels+=("$name — $(_comp_menu_badge "$info" "$name")${req:+  (önce: ${req//,/, })}")
    done < <(comp_info_all "$info" action)
    [ "${#names[@]}" -gt 0 ] || { echo "Pakette eylem yok." >&2; return 1; }
    while true; do
        clear
        if declare -F ui_header >/dev/null; then ui_header "Sunucu › $server › Paketler › $id $ver"; fi
        echo ""
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local -a UI_PICK_DESCS=()
        i=0
        for name in "${names[@]}"; do
            act=$(comp_info_all "$info" "action.$name.warning" | head -n 1)
            eff=$(comp_action_get "$info" "$name" confirm)
            UI_PICK_DESCS+=("${act:-Ek uyarı yok.} [onay: ${eff:-none}]")
            i=$((i + 1))
        done
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local UI_PICK_BACK_DESC="Sunucu menüsüne döner."
        pick=$(_comp_menu_pick "Geri" "${labels[@]}")
        [ "$pick" -ge 1 ] 2>/dev/null || return 0
        echo ""
        comp_cli_run "$id" "${names[$((pick - 1))]}" "$server" || true
        echo ""
        read -r -p "Devam için Enter..." _ || return 0
    done
}

# comp_menu_server <önek> <sunucu-klasörü> → kurulu paket(ler)den birini seçtirir
comp_menu_server() {
    local module_dir="$2" server pick
    local -a ids
    server=$(basename "$module_dir")
    ids=()
    while IFS= read -r pick; do [ -n "$pick" ] && ids+=("$pick"); done < <(comp_menu_installed)
    [ "${#ids[@]}" -gt 0 ] || { echo "Kurulu paket yok. Ana menü › Paketler ile kurun." >&2; return 0; }
    if [ "${#ids[@]}" -eq 1 ]; then comp_menu_actions "${ids[0]}" "$server"; return $?; fi
    while true; do
        clear
        if declare -F ui_header >/dev/null; then ui_header "Sunucu › $server › Paketler"; fi
        echo ""
        local -a labels=()
        for pick in "${ids[@]}"; do labels+=("$pick $(comp_installed_version "$pick")"); done
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local -a UI_PICK_DESCS=()
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local UI_PICK_BACK_DESC="Sunucu menüsüne döner."
        pick=$(_comp_menu_pick "Geri" "${labels[@]}")
        [ "$pick" -ge 1 ] 2>/dev/null || return 0
        comp_menu_actions "${ids[$((pick - 1))]}" "$server"
    done
}
