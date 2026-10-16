#!/usr/bin/env bash
# ComponentsCLI.sh - Paketlerin komut satırı/menü yönetimi (Aşama 2.4a)
#   ./start.sh --components list        kilit ↔ kurulu durumu (ağ yok)
#   ./start.sh --components sync [--yes] kilitteki sürümü kur/onar (onay ister)
#   ./start.sh --components check-new   kilitten daha yeni yayın var mı? (yalnızca bilgi; ağ)
#   ./start.sh --components run <paket> <eylem> <sunucu>   kurulu paketin eylemini sunucuda çalıştırır (ComponentsRunCLI.sh)
#
# Sürüm DAİMA kilit dosyasındakidir (imzalı sshpocket sürümüyle gelir). Daha yeni bir yayın bilgilendirir,
# kurulmaz: yeni sürüm, yeni sshpocket sürümüyle (kilit güncellenince) gelir.
# Gerektirir: Components.sh, ComponentsInstall.sh

# HTTPS başlık isteği; Location değerini yazdırır (testte işlev değiştirilebilir)
comp_http_head() {
    curl -sSI --proto '=https' --tlsv1.2 --max-time 15 "$1" 2>/dev/null \
        | tr -d '\r' | awk 'tolower($1)=="location:" {print $2; exit}'
}

# GitHub API: depodaki yayınlar (ön sürümler dahil, en yeni başta). Testte işlev değiştirilebilir.
comp_http_json() {
    curl -sS --proto '=https' --tlsv1.2 --max-time 15 -H 'Accept: application/vnd.github+json' "$1" 2>/dev/null
}

# comp_latest_version <depo> → en son yayın sürümü (v'siz); geçersizse hata
# Önce kararlı "latest" yönlendirmesi; ön sürüm (pre-release) olduğu için "latest" yoksa API'deki en yeni yayına düşer.
comp_latest_version() {
    local repo="$1" loc tag json
    comp_repo_valid "$repo" || return 1
    loc=$(comp_http_head "https://github.com/${repo}/releases/latest")
    if [ -n "$loc" ]; then
        tag="${loc##*/}"
        [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
        [ "$loc" = "https://github.com/${repo}/releases/tag/${tag}" ] || return 1
        printf '%s' "${tag#v}"
        return 0
    fi
    json=$(comp_http_json "https://api.github.com/repos/${repo}/releases?per_page=1") || return 1
    tag=$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s' "${tag#v}"
}

# comp_status <id> → ok | missing | outdated | ahead | broken
comp_status() {
    local id="$1" want have cmp
    want=$(comp_get "$id" version)
    have=$(comp_installed_version "$id")
    if [ -z "$have" ]; then echo missing; return 0; fi
    cmp=$(comp_version_cmp "$have" "$want")
    case "$cmp" in
        -1) echo outdated; return 0 ;;
        1)  echo ahead; return 0 ;;
    esac
    if comp_verify_installed "$id" "$have" >/dev/null 2>&1; then echo ok; else echo broken; fi
}

_comp_confirm() {
    local a
    if ! read -r -p "$1 [y/N] " a; then return 1; fi
    case "$a" in y|Y|e|E) return 0 ;; *) return 1 ;; esac
}

# Bozulmuş kurulumu silmeden kenara alır (<sürüm>.bozuk-<tarih>); current kaldırılır
_comp_quarantine() {
    local id="$1" ver="$2" base stamp
    base="$(comp_dir)/$id"
    stamp=$(date +%Y%m%d-%H%M%S)
    [ -d "$base/$ver" ] && mv "$base/$ver" "$base/$ver.bozuk-$stamp"
    [ -f "$base/$ver.files" ] && mv "$base/$ver.files" "$base/$ver.files.bozuk-$stamp"
    rm -f "$base/current"
}

comp_cli_list() {
    local ids id st want have mark
    comp_lock_validate || return 1
    ids=$(comp_ids)
    if [ -z "$ids" ]; then echo "Kilit dosyasında paket yok."; return 0; fi
    echo "Paketler (components.lock)"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        st=$(comp_status "$id")
        want=$(comp_get "$id" version)
        have=$(comp_installed_version "$id")
        case "$st" in
            ok) mark="✅ kurulu" ;;
            missing) mark="⬇️  kurulmamış" ;;
            outdated) mark="⬆️  güncellenmeli" ;;
            ahead) mark="⚠️  kilitten yeni (geri alınmaz)" ;;
            broken) mark="❌ dosyalar değişmiş (onarım gerekir)" ;;
        esac
        printf '  %-20s kilit %-8s kurulu %-8s %s\n' "$id" "$want" "${have:--}" "$mark"
    done <<< "$ids"
}

# comp_cli_sync [--yes] → 0 hepsi tamam, 1 en az bir hata/ret
comp_cli_sync() {
    local yes=0 ids id st want rc=0
    [ "${1:-}" = "--yes" ] && yes=1
    comp_lock_validate || return 1
    ids=$(comp_ids)
    [ -n "$ids" ] || return 0
    while IFS= read -r id <&3; do
        [ -n "$id" ] || continue
        st=$(comp_status "$id"); want=$(comp_get "$id" version)
        case "$st" in
            ok) continue ;;
            ahead) echo "⚠️  $id: kurulu sürüm kilitten yeni; dokunulmadı."; continue ;;
            missing|outdated)
                if [ "$yes" -eq 0 ] && ! _comp_confirm "$id $want indirilip imzası doğrulanarak kurulsun mu?"; then
                    echo "Atlandı: $id"; rc=1; continue
                fi
                ;;
            broken)
                echo "❌ $id: kurulu dosyalar değişmiş (kurulumdan sonra düzenlenmiş olabilir)."
                if [ "$yes" -eq 0 ] && ! _comp_confirm "Bozuk kurulum kenara alınıp $id $want yeniden kurulsun mu?"; then
                    echo "Atlandı: $id"; rc=1; continue
                fi
                _comp_quarantine "$id" "$(comp_installed_version "$id")" || { rc=1; continue; }
                ;;
        esac
        if comp_install "$id"; then echo "✅ $id $want"; else echo "⚠️  $id kurulamadı"; rc=1; fi
    done 3<<< "$ids"
    return "$rc"
}

comp_cli_check_new() {
    local ids id want latest repo
    comp_lock_validate || return 1
    ids=$(comp_ids)
    [ -n "$ids" ] || { echo "Kilit dosyasında paket yok."; return 0; }
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        repo=$(comp_get "$id" repo); want=$(comp_get "$id" version)
        if ! latest=$(comp_latest_version "$repo"); then echo "ℹ️  $id: yayın bilgisi alınamadı"; continue; fi
        if [ "$(comp_version_cmp "$latest" "$want")" = "1" ]; then
            echo "🆕 $id: $latest yayınlanmış (sshpocket'ın kilidi: $want)."
            echo "   Yeni sürüm, yeni bir sshpocket sürümüyle (kilit güncellenince) gelir; şimdi kurulmaz."
        else
            echo "✅ $id: güncel ($want)"
        fi
    done <<< "$ids"
    return 0
}

components_cli() {
    local sub="${1:-list}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        list) comp_cli_list ;;
        sync) comp_cli_sync "$@" ;;
        check-new) comp_cli_check_new ;;
        run) comp_cli_run "$@" ;;
        *) echo "kullanım: --components list | sync [--yes] | check-new | run <paket> <eylem> <sunucu>" >&2; return 2 ;;
    esac
}
