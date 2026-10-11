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
