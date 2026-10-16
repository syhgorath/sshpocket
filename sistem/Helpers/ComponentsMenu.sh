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

# _comp_menu_ctx <paket> <sunucu> <bilgi> → COMP_MENU_VER/PKG/MF/DIR/VARS (dinamik kapsam)
_comp_menu_ctx() {
    COMP_MENU_VER=$(comp_info_get "$3" version)
    COMP_MENU_PKG="$(comp_dir)/$1/$COMP_MENU_VER"
    COMP_MENU_MF="$COMP_MENU_PKG/component.json"
    COMP_MENU_DIR="$(servers_dir)/$2"
    COMP_MENU_VARS=$(comp_vars_file "$COMP_MENU_DIR" "$1")
}

# _comp_menu_forced <bilgi> → çalıştırıcının zorladığı değişkenler (outputs.dir_var), satır satır
_comp_menu_forced() {
    local n d
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        d=$(comp_action_get "$1" "$n" outputs.dir_var)
        [ -n "$d" ] && printf '%s\n' "$d"
    done < <(comp_info_all "$1" action) | sort -u
}

# _comp_menu_field <TSV-satırı> <n> → n. alan (boş alanlar korunur)
_comp_menu_field() { printf '%s' "$1" | awk -F'\t' -v n="$2" '{ print $n }'; }

# _comp_menu_unq <değer> → JSON dizgesinin çevreleyen tırnaklarını soyar
_comp_menu_unq() { local v="$1"; if [[ "$v" == \"*\" ]]; then v="${v#\"}"; v="${v%\"}"; fi; printf '%s' "$v"; }

# comp_menu_actions <paket> <sunucu> → hazırlık durumu + (📝 Değişkenler | eylemler); seçileni çalıştırır; geri dönene kadar döngü
comp_menu_actions() {
    local id="$1" server="$2" info name pick i act eff req missing m
    local -a names labels
    info=$(comp_prepare "$id") || { echo "Paket doğrulanamadı: $id (./start.sh --components list)" >&2; return 1; }
    _comp_menu_ctx "$id" "$server" "$info"
    names=()
    while IFS= read -r name; do
        [ -n "$name" ] && names+=("$name")
    done < <(comp_info_all "$info" action)
    [ "${#names[@]}" -gt 0 ] || { echo "Pakette eylem yok." >&2; return 1; }
    while true; do
        missing=$(comp_vars_missing "$COMP_MENU_MF" "$COMP_MENU_VARS")
        clear
        if declare -F ui_header >/dev/null; then ui_header "Sunucu › $server › Paketler › $id $COMP_MENU_VER"; fi
        echo ""
        echo "Hazırlık"
        if [ -n "$missing" ]; then
            while IFS= read -r m; do [ -n "$m" ] && echo "  ❌ $m  (zorunlu, henüz yazılmadı)"; done <<< "$missing"
            echo "  Eylemler, zorunlu değişkenler tamamlanana kadar kapalıdır: önce 📝 Değişkenler."
        else
            echo "  ✅ Zorunlu değişkenler tamam"
        fi
        echo ""
        labels=("📝 Değişkenler${missing:+  ← önce burası}")
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local -a UI_PICK_DESCS=("Paket değişkenlerini görüntüler ve düzenler (${COMP_MENU_VARS##*/}); değerler kaydedilmeden önce doğrulanır.")
        for name in "${names[@]}"; do
            req=$(comp_action_get "$info" "$name" requires)
            labels+=("$name — $(_comp_menu_badge "$info" "$name")${req:+  (önce: ${req//,/, })}${missing:+  ⛔}")
            act=$(comp_info_all "$info" "action.$name.warning" | head -n 1)
            eff=$(comp_action_get "$info" "$name" confirm)
            UI_PICK_DESCS+=("${act:-Ek uyarı yok.} [onay: ${eff:-none}]")
        done
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local UI_PICK_BACK_DESC="Sunucu menüsüne döner."
        pick=$(_comp_menu_pick "Geri" "${labels[@]}")
        [ "$pick" -ge 1 ] 2>/dev/null || return 0
        if [ "$pick" -eq 1 ]; then
            comp_menu_vars "$id" "$server" "$info"
            continue
        fi
        if [ -n "$missing" ]; then
            echo ""
            echo "⛔ Önce zorunlu değişkenleri tamamlayın (📝 Değişkenler)."
            read -r -p "Devam için Enter..." _ || return 0
            continue
        fi
        echo ""
        comp_cli_run "$id" "${names[$((pick - 2))]}" "$server" || true
        echo ""
        read -r -p "Devam için Enter..." _ || return 0
    done
}

# comp_menu_vars <paket> <sunucu> <bilgi> → değişken listesi; seçileni düzenletir
comp_menu_vars() {
    local id="$1" server="$2" info="$3" line n t r d lo hi desc cur forced pick
    local -a lines labels
    forced=$(_comp_menu_forced "$info")
    while true; do
        lines=(); labels=()
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local -a UI_PICK_DESCS=()
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            lines+=("$line")
            n=$(_comp_menu_field "$line" 1); t=$(_comp_menu_field "$line" 2); r=$(_comp_menu_field "$line" 3)
            d=$(_comp_menu_unq "$(_comp_menu_field "$line" 4)"); lo=$(_comp_menu_field "$line" 5); hi=$(_comp_menu_field "$line" 6)
            desc=$(_comp_menu_field "$line" 8)
            cur=$(comp_vars_get "$COMP_MENU_VARS" "$n" 2>/dev/null) || cur=""
            if printf '%s\n' "$forced" | grep -qxF -- "$n"; then
                labels+=("$n — otomatik (çalıştırıcı kullanıcı klasörüne yönlendirir; değiştirilemez)")
            elif [ -n "$cur" ]; then
                labels+=("$n = $cur")
            elif [ -n "$d" ]; then
                labels+=("$n = (varsayılan: $d)")
            else
                labels+=("$n = (boş)${r:+$([ "$r" = yes ] && echo '  ❌ zorunlu')}")
            fi
            UI_PICK_DESCS+=("$t${lo:+ · en az $lo}${hi:+ · en çok $hi} — ${desc:-açıklama yok}")
        done < <(comp_vars_describe "$COMP_MENU_MF")
        [ "${#lines[@]}" -gt 0 ] || { echo "Pakette değişken yok."; read -r -p "Devam için Enter..." _ || true; return 0; }
        clear
        if declare -F ui_header >/dev/null; then ui_header "Sunucu › $server › Paketler › $id › Değişkenler"; fi
        echo ""
        # shellcheck disable=SC2034  # ui_pick_arrows (dinamik kapsam) okur
        local UI_PICK_BACK_DESC="Eylem listesine döner."
        pick=$(_comp_menu_pick "Geri" "${labels[@]}")
        [ "$pick" -ge 1 ] 2>/dev/null || return 0
        line="${lines[$((pick - 1))]}"
        n=$(_comp_menu_field "$line" 1); t=$(_comp_menu_field "$line" 2)
        echo ""
        if printf '%s\n' "$forced" | grep -qxF -- "$n"; then
            echo "ℹ️  $n çalıştırıcı tarafından belirlenir (hassas çıktı USB'ye yazılmasın diye kullanıcı klasörüne yönlendirilir)."
            read -r -p "Devam için Enter..." _ || return 0
        elif [[ "$t" == list\[cidr\] ]]; then
            comp_menu_edit_cidr "$n" "$server" || return 0
        else
            comp_menu_edit_value "$line" || return 0
        fi
    done
}

# comp_menu_edit_value <TSV-satırı> → tek değişkeni düzenletir (doğrula → gerekirse onay → yaz)
comp_menu_edit_value() {
    local line="$1" n t d lo hi desc cur v v2 out
    n=$(_comp_menu_field "$line" 1); t=$(_comp_menu_field "$line" 2); d=$(_comp_menu_unq "$(_comp_menu_field "$line" 4)")
    lo=$(_comp_menu_field "$line" 5); hi=$(_comp_menu_field "$line" 6); desc=$(_comp_menu_field "$line" 8)
    cur=$(comp_vars_get "$COMP_MENU_VARS" "$n" 2>/dev/null) || cur=""
    echo "$n — ${desc:-açıklama yok}"
    echo "Tür: $t${lo:+ · en az $lo}${hi:+ · en çok $hi}${d:+ · varsayılan $d}"
    echo "Şimdiki: ${cur:-(boş)}"
    IFS= read -r -p "Yeni değer (Enter = değiştirme, - = sil): " v || return 1
    case "$v" in
        "") return 0 ;;
        "-") comp_vars_unset "$COMP_MENU_VARS" "$n"; echo "Silindi (varsayılana döner)."; read -r -p "Devam için Enter..." _ || return 1; return 0 ;;
    esac
    out=$(comp_vars_check "$COMP_MENU_MF" "$n" "$v" 2>&1) || { echo "⚠️  $out"; read -r -p "Devam için Enter..." _ || return 1; return 0; }
    case "$out" in
        *warn=*)
            echo "⚠️  Bu değer riskli (paketin warn_if uyarısı)."
            IFS= read -r -p "Yine de kaydedilsin mi? [e/H]: " v2 || return 1
            case "$v2" in e|E|evet|Evet) ;; *) echo "İptal edildi."; return 0 ;; esac ;;
    esac
    if comp_vars_set "$COMP_MENU_VARS" "$n" "$v"; then echo "✅ Kaydedildi."; else echo "⚠️  Kaydedilemedi."; fi
    read -r -p "Devam için Enter..." _ || return 1
}

# comp_menu_edit_cidr <değişken> <sunucu> → CIDR listesi: öneri ekle / elle ekle / sil / temizle / kaydet
# Öneri yalnızca ŞU ANKİ bağlantının ağını bilir; başka ağlar (ev LAN, başka VPN) kullanıcıya sorulur. Hiçbir şey otomatik yazılmaz.
comp_menu_edit_cidr() {
    local n="$1" server="$2" cur la seen prefix ip port user key choice c x i k v ans out found
    local -a list sc sd keep
    prefix=$(module_prefix "$server")
    ip=$(srv_get "$COMP_MENU_DIR" "$prefix" IP); port=$(srv_get "$COMP_MENU_DIR" "$prefix" PORT); port="${port:-22}"
    user=$(srv_get "$COMP_MENU_DIR" "$prefix" USER); key=$(srv_get "$COMP_MENU_DIR" "$prefix" KEY)
    [ -n "$key" ] || key="$COMP_MENU_DIR/id_ed25519_${server}"
    if [ "${key:0:1}" = "~" ]; then key="$HOME${key:1}"; fi
    cur=$(comp_vars_get "$COMP_MENU_VARS" "$n" 2>/dev/null) || cur=""
    list=()
    if [ -n "$cur" ]; then
        IFS=',' read -r -a list <<< "$cur"
    fi
    la=$(comp_net_local "$ip" 2>/dev/null) || la=""
    while true; do
        sc=(); sd=()
        if [ -n "$la" ]; then
            while IFS=$'\t' read -r c x; do [ -n "$c" ] && { sc+=("$c"); sd+=("$x"); }; done < <(comp_net_suggest "$la")
        fi
        echo "$n — SSH'a izin verilen ağlar (CIDR). Bu liste sunucunun güvenlik duvarına (ufw) yazılır; listede olmayan ağlardan SSH kapanır."
        if [ "${#list[@]}" -gt 0 ]; then echo "Mevcut liste: $(IFS=,; printf '%s' "${list[*]}")"; else echo "Mevcut liste: (boş)"; fi
        if [ -n "$la" ]; then echo "Bu bilgisayarın sunucuya bağlandığı adres: $la"; else echo "Bu bilgisayarın adresi belirlenemedi (öneri yok); elle ekleyin."; fi
        i=1
        for c in ${sc[@]+"${sc[@]}"}; do echo "  $i) ekle: $c  — ${sd[$((i - 1))]}"; i=$((i + 1)); done
        echo "  e) elle ekle   d) listeden sil   t) temizle   v) sunucunun gördüğü adresi sorgula (salt okunur ssh)   k) kaydet   0) iptal"
        IFS= read -r -p "Seçim: " choice || return 1
        case "$choice" in
            0|q|Q) return 0 ;;
            e|E)
                IFS= read -r -p "CIDR (örn. 192.168.1.0/24): " c || return 1
                if out=$(comp_vars_check "$COMP_MENU_MF" "$n" "$c" 2>&1); then list+=("$c"); else echo "⚠️  $out"; fi ;;
            d|D)
                IFS= read -r -p "Silinecek sıra numarası: " x || return 1
                if [[ "$x" =~ ^[0-9]+$ ]] && [ "$x" -ge 1 ] && [ "$x" -le "${#list[@]}" ]; then
                    k=0; keep=()
                    for v in "${list[@]}"; do k=$((k + 1)); [ "$k" -eq "$x" ] || keep+=("$v"); done
                    list=()
                    for v in ${keep[@]+"${keep[@]}"}; do list+=("$v"); done
                else echo "Geçersiz numara."; fi ;;
            t|T) list=() ;;
            v|V)
                if seen=$(comp_net_seen_by_server "$ip" "$port" "$user" "$key"); then la="$seen/32"; echo "Sunucu seni şu adresten görüyor: $seen"
                else echo "⚠️  Sunucudan sorgulanamadı (ağ/anahtar/host key)."; fi ;;
            k|K)
                if [ "${#list[@]}" -eq 0 ]; then echo "⚠️  Liste boş olamaz (zorunlu)."; continue; fi
                if [ "${#list[@]}" -eq 1 ]; then
                    echo "⚠️  Listede yalnızca bir ağ var. Başka bir ağdan (ev LAN, ofis, başka VPN) bağlanırsanız SSH kapalı olur."
                    IFS= read -r -p "Başka ağ da eklemek ister misiniz? [e/H]: " ans || return 1
                    case "$ans" in e|E|evet|Evet) continue ;; esac
                fi
                v=$(IFS=,; printf '%s' "${list[*]}")
                if comp_vars_save "$COMP_MENU_MF" "$COMP_MENU_VARS" "$n" "$v" >/dev/null; then echo "✅ Kaydedildi: $v"; else echo "⚠️  Kaydedilemedi."; fi
                read -r -p "Devam için Enter..." _ || return 1
                return 0 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#sc[@]}" ]; then
                    c="${sc[$((choice - 1))]}"; found=0
                    for v in ${list[@]+"${list[@]}"}; do [ "$v" = "$c" ] && found=1; done
                    if [ "$found" -eq 1 ]; then echo "Zaten listede."; else list+=("$c"); fi
                else echo "Geçersiz seçim."; fi ;;
        esac
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
