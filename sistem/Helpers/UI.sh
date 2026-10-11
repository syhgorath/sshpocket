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
    esac
    [ -t 0 ] && [ -t 2 ] && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]
}

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

_ui_cursor_show() { printf '\033[?25h' >&2; }

# Liste + alt ipucu çizer (stderr). Çağıranın yerel değişkenlerini kullanır: sel n back buf items
_ui_pick_draw() {
    local redraw="$1" i label num hint
    if [ "$redraw" = "1" ]; then printf '\033[%dA' "$((n + 3))" >&2; fi
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
}

# ui_pick_arrows <başlangıç 1..n> <geri etiketi> <öğe>...
# Seçilen numarayı stdout'a yazar (geri/çıkış = 0). Ekran stderr'e çizilir.
ui_pick_arrows() {
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
