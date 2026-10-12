#!/usr/bin/env bash
# UI.sh - Ortak ekran öğeleri: başlık (ekmek kırıntısı), ayraç, alt ipucu
# Renk yalnızca hedef terminal ise ve NO_COLOR tanımsızsa kullanılır (boru/test çıktısı düz kalır).

UI_RULE='────────────────────────────────────────────────────────'

# $1 = dosya tanıtıcısı (1 stdout, 2 stderr)
_ui_color() { [ -t "${1:-1}" ] && [ -z "${NO_COLOR:-}" ]; }

# Başlık: boş satır, kalın ekmek kırıntısı, ayraç. Parametre: $1 - "Ana menü › ubuntutest", $2 - fd (ops.)
ui_header() {
    local fd="${2:-1}"
    printf '\n'
    if _ui_color "$fd"; then printf '\033[1m%s\033[0m\n' "$1"; else printf '%s\n' "$1"; fi
    printf '%s\n' "$UI_RULE"
}

# Alt ipucu: ayraç + soluk ipucu satırı. Parametre: $1 - metin, $2 - fd (ops.)
ui_footer() {
    local fd="${2:-1}"
    printf '%s\n' "$UI_RULE"
    if _ui_color "$fd"; then printf '\033[2m%s\033[0m\n' "$1"; else printf '%s\n' "$1"; fi
}

# Grup adının ekranda görünen karşılığı
ui_group_title() {
    case "$1" in
        MainMenu) printf 'Ana menü' ;;
        *) printf '%s' "$1" ;;
    esac
}

# ---------- Ok tuşlu seçim (saf bash, bash 3.2 uyumlu) ----------
# Etkin mi? Ayar UI: numbers → hayır, arrows → evet (zorla), auto → yalnızca gerçek terminalde.
ui_arrows_enabled() {
    local mode=auto
    if declare -F settings_get >/dev/null; then mode=$(settings_get UI); fi
    case "$mode" in
        numbers) return 1 ;;
        arrows) return 0 ;;
        fzf) if ui_fzf_bin >/dev/null 2>&1; then return 0; fi ;;
    esac
    [ -t 0 ] && [ -t 2 ] && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]
}

# fzf'in tam yolu: önce PATH, sonra Homebrew konumları (Finder'dan açılan start.command PATH'inde /opt/homebrew/bin yoktur).
# SSHPOCKET_FZF_DIRS (boşlukla ayrılmış) test/özel kurulum için değiştirir.
ui_fzf_bin() {
    local d p
    if p=$(command -v fzf 2>/dev/null) && [ -n "$p" ]; then printf '%s' "$p"; return 0; fi
    local IFS=' '
    # shellcheck disable=SC2086  # kasıtlı: boşlukla ayrılmış dizin listesi
    for d in ${SSHPOCKET_FZF_DIRS:-/opt/homebrew/bin /usr/local/bin}; do
        if [ -x "$d/fzf" ]; then printf '%s' "$d/fzf"; return 0; fi
    done
    return 1
}

# fzf arka ucu kullanılacak mı? UI=numbers|arrows → hayır; fzf yoksa hayır; auto → yalnızca gerçek terminalde;
# UI=fzf → zorla (fzf kuruluysa).
ui_fzf_enabled() {
    local mode=auto
    if declare -F settings_get >/dev/null; then mode=$(settings_get UI); fi
    case "$mode" in numbers|arrows) return 1 ;; esac
    ui_fzf_bin >/dev/null 2>&1 || return 1
    [ "$mode" = "fzf" ] && return 0
    [ -t 0 ] && [ -t 2 ] && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]
}

# Açıklamalar (isteğe bağlı): çağıran seçici çağrısından ÖNCE doldurur.
#   UI_PICK_DESCS=("1. öğenin açıklaması" "2. öğe..." ...)   UI_PICK_BACK_DESC="geri/çıkış satırının açıklaması"
# Ok tuşlu seçicide alt satırda, fzf'te önizleme penceresinde gösterilir.

# Tek tuş okur, UI_KEY'e yazar: UP DOWN LEFT RIGHT ENTER BACKSPACE ESC EOF OTHER CHAR:<c>
# (Testlerde bu fonksiyon sahte tuş kuyruğuyla değiştirilir.)
_ui_read_key() {
    local k k2 k3
    UI_KEY=""
    IFS= read -rsn1 k || { UI_KEY=EOF; return 0; }
    case "$k" in
        $'\033')
            IFS= read -rsn1 -t 1 k2 || { UI_KEY=ESC; return 0; }
            if [ "$k2" = "[" ] || [ "$k2" = "O" ]; then
                IFS= read -rsn1 -t 1 k3 || { UI_KEY=ESC; return 0; }
                case "$k3" in
                    A) UI_KEY=UP ;;
                    B) UI_KEY=DOWN ;;
                    C) UI_KEY=RIGHT ;;
                    D) UI_KEY=LEFT ;;
                    *) UI_KEY=OTHER ;;
                esac
            else
                UI_KEY=ESC
            fi
            ;;
        "") UI_KEY=ENTER ;;
        $'\177'|$'\b') UI_KEY=BACKSPACE ;;
        *) UI_KEY="CHAR:$k" ;;
    esac
}

_ui_cursor_show() { printf '\033[?25h\033[?7h' >&2; }

# Liste + alt ipucu çizer (stderr). Çağıranın yerel değişkenlerini kullanır: sel n back buf items
_ui_pick_draw() {
    local redraw="$1" i label num hint desc
    printf '\033[?7l' >&2        # otomatik sarma KAPALI: uzun satır sarılıp yeni satır üretmesin (imleç hesabı kaymasın)
    if [ "$redraw" = "1" ]; then printf '\033[%dA' "$((n + 4))" >&2; fi
    i=1
    while [ "$i" -le "$((n + 1))" ]; do
        if [ "$i" -le "$n" ]; then label="${items[$((i - 1))]}"; num="$i"; else label="$back"; num=0; fi
        printf '\r\033[2K' >&2
        if [ "$i" -eq "$sel" ]; then
            printf '\033[7m ›%2d) %s \033[0m\n' "$num" "$label" >&2
        else
            printf '   %2d) %s\n' "$num" "$label" >&2
        fi
        i=$((i + 1))
    done
    printf '\r\033[2K%s\n' "$UI_RULE" >&2
    if [ -n "$buf" ]; then hint="numara: $buf · Enter = seç · Backspace = sil"
    else hint="↑↓ seç · Enter aç · ←/q/0 geri · numara yazıp Enter"; fi
    printf '\r\033[2K\033[2m%s\033[0m\n' "$hint" >&2
    if [ "$sel" -le "$n" ]; then desc="${UI_PICK_DESCS[$((sel - 1))]:-}"; else desc="${UI_PICK_BACK_DESC:-}"; fi
    printf '\r\033[2K%s\n' "$desc" >&2
    printf '\033[?7h' >&2        # sarma yeniden AÇIK
}

# fzf arka ucu: "<no>\t<etiket>" satırları; açıklama --preview ile (dosyadan, kabuğa veri verilmez).
# Parametreler ui_pick_arrows ile aynı. Çıktı: seçilen numara (geri/Esc/hata = 0)
_ui_pick_fzf() {
    local sel="${1:-1}" back="$2"; shift 2
    local -a items=("$@")
    local n=$# tmp i label out rc num fzf_bin
    fzf_bin=$(ui_fzf_bin) || return 2
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/sshpocket-fzf.XXXXXX") || return 1
    if ! [[ "$tmp" =~ ^[A-Za-z0-9_./-]+$ ]]; then rm -r -- "${tmp:?}"; return 2; fi   # güvenli olmayan yol: kendi seçicimiz
    {
        i=1
        for label in "${items[@]}"; do
            label="${label//$'\t'/ }"; label="${label//$'\n'/ }"
            printf '%d\t%s\n' "$i" "$label"
            i=$((i + 1))
        done
        label="${back//$'\t'/ }"
        printf '0\t%s\n' "$label"
    } > "$tmp/list"
    {
        printf '%s\n' "${UI_PICK_BACK_DESC:-}"
        i=0
        while [ "$i" -lt "$n" ]; do printf '%s\n' "${UI_PICK_DESCS[$i]:-}"; i=$((i + 1)); done
    } > "$tmp/desc"
    out=$("$fzf_bin" --delimiter=$'\t' --with-nth=2.. --layout=reverse --height='~60%' --min-height=8 \
              --border --no-sort --cycle --prompt='› ' \
              --header='Enter: aç · ←/Esc: geri · yazarak ara' \
              --preview "awk -v n={1} 'NR==n+1' '$tmp/desc'" --preview-window='down,3,wrap,border-top' \
              --bind 'left:abort' --bind "start:pos($sel)" < "$tmp/list")
    rc=$?
    rm -r -- "${tmp:?}"
    num="${out%%$'\t'*}"
    if [ "$rc" -eq 0 ] && [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -le "$n" ]; then printf '%s' "$num"; else printf '0'; fi
    return 0
}

# ui_pick_arrows <başlangıç 1..n> <geri etiketi> <öğe>...
# Seçilen numarayı stdout'a yazar (geri/çıkış = 0). Ekran stderr'e çizilir.
# Arka uç: fzf (kuruluysa, UI=auto|fzf) → kendi ok tuşlu seçicimiz.
ui_pick_arrows() {
    local rc
    if ui_fzf_enabled; then
        _ui_pick_fzf "$@"; rc=$?
        [ "$rc" -ne 2 ] && return "$rc"
    fi
    _ui_pick_builtin "$@"
}

_ui_pick_builtin() {
    local sel="${1:-1}" back="$2"; shift 2
    local items=("$@") n=$# buf="" result=""
    [ "$sel" -ge 1 ] && [ "$sel" -le "$n" ] 2>/dev/null || sel=1
    trap '_ui_cursor_show' INT TERM
    printf '\033[?25l' >&2
    _ui_pick_draw 0
    while true; do
        _ui_read_key
        case "$UI_KEY" in
            UP|CHAR:k)
                buf=""; sel=$((sel - 1)); [ "$sel" -lt 1 ] && sel=$((n + 1)) ;;
            DOWN|CHAR:j)
                buf=""; sel=$((sel + 1)); [ "$sel" -gt "$((n + 1))" ] && sel=1 ;;
            LEFT|CHAR:q|CHAR:Q|EOF|ESC)
                result=0; break ;;
            CHAR:[0-9])
                if [ "${#buf}" -lt 3 ]; then buf="$buf${UI_KEY#CHAR:}"; fi
                if [ "$buf" = "0" ]; then sel=$((n + 1))
                elif [ "$buf" -ge 1 ] 2>/dev/null && [ "$buf" -le "$n" ]; then sel="$buf"; fi
                ;;
            BACKSPACE)
                buf="${buf%?}" ;;
            ENTER)
                if [ -n "$buf" ]; then
                    if [ "$buf" -ge 0 ] 2>/dev/null && [ "$buf" -le "$n" ]; then result="$buf"; break; fi
                    buf=""
                elif [ "$sel" -gt "$n" ]; then result=0; break
                else result="$sel"; break; fi
                ;;
        esac
        _ui_pick_draw 1
    done
    trap - INT TERM
    _ui_cursor_show
    printf '%s' "$result"
}

# Ana menü girdileri için açıklama. Parametre: işlev adı (server:<ad> dahil)
ui_describe_entry() {
    case "$1" in
        server:*)              printf 'Sunucu menüsünü açar: bağlan, key gönder, bilgileri güncelle, Keychain passphrase, knock ayarları.' ;;
        AddServerAction)       printf "Yeni sunucu ekler: IP/kullanıcı/port sorar, isterseniz ed25519 key üretir, passphrase'i Keychain'e kaydeder." ;;
        ImportSSHConfigAction) printf '%s' 'SSH config dosyasındaki (~/.ssh/config) sunucuları buraya aktarır; private key dosyaları kopyalanmaz, yolları kaydedilir.' ;;
        ManageServersAction)   printf 'Sunucuları listeler, siler veya yeniden adlandırır (silmede sunucu adını yazarak onaylarsınız).' ;;
        UpdateAction)          printf 'Yeni sürüm var mı bakar; imzalı paketi doğrulayıp onayınızla kurar. Sunucularınıza ve key'"'"'lerinize dokunmaz.' ;;
        SettingsAction)        printf 'Durum göstergesi, kontrol süresi ve menü stilini (fzf/ok tuşu/numara) ayarlar.' ;;
        ComponentsAction)      printf 'Kurulu paketlerin durumunu gösterir; eksik/eski olanı imzayı doğrulayarak, onayınızla kurar.' ;;
        *)                     printf '' ;;
    esac
}

# Ana menü döngüsüne "bu eylemden sonra duraklatma" der (menüden geri dönüldü; okunacak çıktı yok).
# shellcheck disable=SC2034  # Main.sh döngüsü okur
ui_no_pause() { SSHPOCKET_NO_PAUSE=1; }
