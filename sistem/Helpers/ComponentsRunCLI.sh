#!/usr/bin/env bash
# ComponentsRunCLI.sh - ./start.sh --components run <paket> <eylem> <sunucu>  (Aşama 3, PR D)
# Sunucu bilgisini okur, işletim sistemi profilini SALT OKUNUR bir ssh ile algılar, gerekirse (onayla) Python ortamını kurar
# ve yürütücüyü (ComponentsExec.sh) çağırır. Parola/passphrase istemez: sudo parolasını Ansible kendi isteminden alır.
# Çıkış kodları: 0 başarı · 2 kullanım hatası · 190 çalıştırılmadı (kapı/onay/hazırlık) · aksi halde playbook'un kodu
# shellcheck disable=SC2034  # COMP_CTX_* değişkenlerini ComponentsExec.sh (dinamik kapsam) okur
# Gerektirir: Components*.sh, ComponentsRun.sh, ComponentsGates.sh, ComponentsExec.sh, Servers.sh, Validate.sh, ModuleFiles.sh

# comp_detect_profile <host> <port> <kullanıcı> <anahtar> → "ubuntu-26.04" (ID-VERSION_ID). Uzak komut SABİT ve salt okunurdur.
# Host key kapatılmaz (StrictHostKeyChecking=yes), parola sorulmaz (BatchMode). Çıktı asla source/eval edilmez.
comp_detect_profile() {
    local host="$1" port="$2" user="$3" key="$4" out id ver
    out=$(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 \
              -o PreferredAuthentications=publickey -o PasswordAuthentication=no \
              -p "$port" -i "$key" "$user@$host" 'cat /etc/os-release' 2>/dev/null) || return 1
    id=$(printf '%s\n' "$out" | awk -F= '$1=="ID" { gsub(/"/, "", $2); print tolower($2); exit }')
    ver=$(printf '%s\n' "$out" | awk -F= '$1=="VERSION_ID" { gsub(/"/, "", $2); print tolower($2); exit }')
    [[ "$id" =~ ^[a-z0-9][a-z0-9._-]{0,31}$ ]] && [[ "$ver" =~ ^[a-z0-9][a-z0-9._-]{0,31}$ ]] || return 1
    printf '%s-%s' "$id" "$ver"
}

_comp_run_cli_usage() {
    echo "kullanım: ./start.sh --components run <paket> <eylem> <sunucu>" >&2
}

# comp_cli_run <paket> <eylem> <sunucu>
comp_cli_run() {
    if [ $# -ne 3 ]; then _comp_run_cli_usage; return 2; fi
    local id="$1" action="$2" server="$3" ver info pkg dir prefix ip user port key values range venv profile ans rc refused="$COMP_EXEC_REFUSED"
    comp_id_valid "$id" || { echo "Geçersiz paket kimliği." >&2; return 2; }
    [[ "$action" =~ ^[a-z][a-z0-9_]{0,63}$ ]] || { echo "Geçersiz eylem adı." >&2; return 2; }
    module_name_valid "$server" || { echo "Geçersiz sunucu adı." >&2; return 2; }

    info=$(comp_prepare "$id") || return "$refused"
    ver=$(comp_info_get "$info" version)
    comp_info_all "$info" action | grep -qxF -- "$action" || { echo "'$id' paketinde '$action' eylemi yok." >&2; return 2; }
    pkg="$(comp_dir)/$id/$ver"

    dir="$(servers_dir)/$server"
    [ -d "$dir" ] || { echo "Sunucu bulunamadı: $server" >&2; return 2; }
    prefix=$(module_prefix "$server")
    ip=$(srv_get "$dir" "$prefix" IP); user=$(srv_get "$dir" "$prefix" USER); port=$(srv_get "$dir" "$prefix" PORT); port="${port:-22}"
    key=$(srv_get "$dir" "$prefix" KEY)
    if [ -n "$key" ]; then
        if [ "${key:0:1}" = "~" ]; then key="$HOME${key:1}"; fi
    else
        key="$dir/id_ed25519_${server}"
    fi
    ssh_validate_target "$ip" "$user" "$port" 2>/dev/null || { echo "Sunucu bilgisi eksik/geçersiz (IP, kullanıcı, port)." >&2; return "$refused"; }
    [ -f "$key" ] || { echo "SSH key bulunamadı: $key" >&2; return "$refused"; }

    # Python ortamı: yoksa AÇIKÇA onay istenir (ağdan indirir)
    range=$(comp_info_get "$info" requires.python); range="${range:->=3.12}"
    if ! venv=$(comp_venv_lookup "$id" "$pkg" "$range"); then
        echo "Python ortamı kurulu değil. İlk kullanımda kurulacak: PyPI'dan yalnızca hash'li wheel paketleri (yaklaşık 10 MB indirme," >&2
        echo "diskte yaklaşık 90 MB; ~/.cache/sshpocket altında, sistem Python'una dokunulmaz)." >&2
        printf 'Kurulsun mu? [e/H]: ' >&2
        IFS= read -r ans || { echo >&2; echo "Onay alınamadı." >&2; return "$refused"; }
        case "$ans" in e|E|evet|Evet) ;; *) echo "İptal edildi." >&2; return "$refused" ;; esac
        venv=$(comp_venv_ensure "$id" "$pkg" "$range") || return "$refused"
    fi

    # İşletim sistemi profili: anahtar ajanda olmalı, host key tanınmalı; sonra salt okunur algılama
    comp_gate_known_host "$ip" "$port" || return "$refused"
    comp_gate_agent "$prefix" "$key" || return "$refused"
    profile=$(comp_detect_profile "$ip" "$port" "$user" "$key") || { echo "Sunucunun işletim sistemi algılanamadı (ssh)." >&2; return "$refused"; }
    echo "Sunucu: $server ($user@$ip:$port)  Profil: $profile  Paket: $id $ver" >&2

    values="$dir/$id.vars"
    [ -f "$values" ] || values=""
    COMP_CTX_PKGDIR="$pkg"; COMP_CTX_BINDIR="$venv/bin"; COMP_CTX_SERVER="$server"; COMP_CTX_HOST="$ip"; COMP_CTX_USER="$user"
    COMP_CTX_PORT="$port"; COMP_CTX_KEY="$key"; COMP_CTX_PREFIX="$prefix"; COMP_CTX_PROFILE="$profile"; COMP_CTX_VALUES="$values"
    comp_exec_action "$info" "$id" "$ver" "$action"
    rc=$?
    if [ "$rc" -eq "$refused" ]; then echo "Çalıştırılmadı." >&2; return "$rc"; fi
    # Kayıt (gizli bilgi yok): tarih|paket|sürüm|eylem|sonuç
    ( umask 077; printf '%s|%s|%s|%s|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$ver" "$action" "$([ "$rc" -eq 0 ] && echo ok || echo fail)" >> "$dir/components.log" ) || true
    if [ -n "$COMP_EXEC_RESULT" ]; then
        echo "Sonuç:" >&2
        while IFS= read -r ans; do echo "  $ans" >&2; done <<< "$COMP_EXEC_RESULT"
    fi
    return "$rc"
}
