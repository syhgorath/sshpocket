#!/usr/bin/env bash
# ComponentsExec.sh - Paket eylemi yürütücüsü (Aşama 3, PR C): kapılar → değişkenler → onay → çalıştır → sonuç → kayıt
# TEK giriş noktası comp_exec_action: sonraki katmanlar (CLI/menü) hiçbir adımı atlayamaz.
# Çıkış kodları: 0 başarı · playbook'un kendi kodu · 190 çalıştırılmadan reddedildi (kapı/değişken/onay/hazırlık)
# Gerektirir: Components.sh, ComponentsInstall.sh, ComponentsManifest.sh, ComponentsRun.sh, ComponentsGates.sh
#
# Bağlam (çağıran ayarlar; hepsi zorunlu, VM'e bağlanan ilk katman D'dir):
#   COMP_CTX_PKGDIR   paket kökü (component.json, ansible.cfg)      COMP_CTX_BINDIR   venv bin (ansible-playbook burada)
#   COMP_CTX_SERVER   sunucu adı   COMP_CTX_HOST   COMP_CTX_USER   COMP_CTX_PORT   COMP_CTX_KEY (mutlak yol)
#   COMP_CTX_PREFIX   Keychain modül öneki   COMP_CTX_PROFILE   algılanan OS profili   COMP_CTX_VALUES   değerler dosyası (yoksa boş)
# shellcheck disable=SC2034  # COMP_EXEC_RESULT çağıran tarafından okunur

COMP_EXEC_REFUSED=190
COMP_EXEC_RESULT=""

# comp_exec_parse_result <bilgi> <eylem> <log-dosyası> → COMP_EXEC_RESULT ("k=v" satırları); geçersizse boş ve 1
# Satır başı varsayılmaz (Ansible yaml/json çıktısında girintili/tırnaklı gelir): son 'SSHPOCKET_RESULT' işaretinden itibaren okunur.
comp_exec_parse_result() {
    local info="$1" action="$2" log="$3" id line rest tok keys k v seen=""
    local -a toks
    COMP_EXEC_RESULT=""
    [ "$(comp_action_get "$info" "$action" outputs.format)" = "keyvalue-line" ] || return 0
    id=$(comp_info_get "$info" id)
    keys=",$(comp_action_get "$info" "$action" outputs.keys),"
    line=$(grep 'SSHPOCKET_RESULT' "$log" 2>/dev/null | tail -n 1)
    [ -n "$line" ] || { echo "Sonuç satırı bulunamadı (SSHPOCKET_RESULT)." >&2; return 1; }
    rest="SSHPOCKET_RESULT${line#*SSHPOCKET_RESULT}"
    rest="${rest%%\\n*}"; rest="${rest%%\"*}"; rest="${rest%%\'*}"
    IFS=' ' read -r -a toks <<< "$rest"
    [ "${toks[0]:-}" = "SSHPOCKET_RESULT" ] && [ "${toks[1]:-}" = "$id.$action" ] \
        || { echo "Sonuç satırı beklenen önekle ('SSHPOCKET_RESULT $id.$action') başlamıyor." >&2; return 1; }
    local i out=""
    for ((i = 2; i < ${#toks[@]}; i++)); do
        tok="${toks[$i]}"
        k="${tok%%=*}"; v="${tok#*=}"
        if [[ "$tok" != *=* ]] || [[ "$keys" != *",$k,"* ]] || ! [[ "$v" =~ ^[A-Za-z0-9_.:+-]{0,64}$ ]] || [[ "$seen" == *",$k,"* ]]; then
            echo "Sonuç satırı geçersiz ('$k' bilinmiyor, yinelenmiş ya da değeri uygunsuz)." >&2
            return 1
        fi
        seen="$seen,$k,"
        out="$out$k=$v"$'\n'
    done
    COMP_EXEC_RESULT="${out%$'\n'}"
    return 0
}

# _comp_exec_body <bilgi> <paket> <sürüm> <eylem> → alt kabukta çalışır; geçici dosyalar HER çıkışta (Ctrl-C/TERM dahil) silinir
_comp_exec_body() {
    local info="$1" id="$2" ver="$3" action="$4"
    local server="$COMP_CTX_SERVER" pkg="$COMP_CTX_PKGDIR" bindir="$COMP_CTX_BINDIR" work sdir vf inv group dir_var outdir log w prog rc line
    local -a sets warn_names
    local refused="$COMP_EXEC_REFUSED"

    [ -f "$pkg/component.json" ] && [ -d "$bindir" ] || { echo "Paket dizini ya da venv bulunamadı." >&2; return "$refused"; }
    [ "$(comp_info_get "$info" runner)" = "ansible" ] || { echo "Yalnızca ansible runner destekleniyor." >&2; return "$refused"; }

    # ---- kapılar (hepsi yerel; biri durdurursa HİÇBİR ŞEY çalışmaz) ----
    comp_gate_not_root "$info" "$action" "$COMP_CTX_USER" || return "$refused"
    comp_gate_known_host "$COMP_CTX_HOST" "$COMP_CTX_PORT" || return "$refused"
    comp_gate_agent "$COMP_CTX_PREFIX" "$COMP_CTX_KEY" || return "$refused"
    comp_gate_profile "$info" "$COMP_CTX_PROFILE" || return "$refused"
    comp_gate_requires "$info" "$id" "$server" "$ver" "$action" || return "$refused"

    sdir=$(comp_gate_state_ensure "$id" "$server") || return "$refused"
    work=$(mktemp -d "${TMPDIR:-/tmp}/sshpocket-run.XXXXXX") || { echo "Geçici klasör oluşturulamadı." >&2; return "$refused"; }
    chmod 700 "$work"
    # yol trap KURULURKEN genişletilir: 'work' yereldir, EXIT anında artık yoktur
    # shellcheck disable=SC2064
    trap "rm -r -- $(printf '%q' "$work") 2>/dev/null" EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    vf="$work/vars.json"; inv="$work/inventory"

    # ---- değişkenler: dir_var HER ZAMAN kullanıcı klasörüne yönlendirilir (hassas çıktı USB'ye yazılmaz) ----
    sets=()
    dir_var=$(comp_action_get "$info" "$action" outputs.dir_var)
    if [ -n "$dir_var" ]; then
        outdir="$sdir/out"
        if ! ( umask 077; mkdir -p "$outdir" ) || ! chmod 700 "$outdir"; then echo "Çıktı klasörü oluşturulamadı." >&2; return "$refused"; fi
        sets=(--set "$dir_var=$outdir")
    fi
    warn_names=()
    if ! w=$(comp_run_vars "$pkg/component.json" "${COMP_CTX_VALUES:-/dev/null}" "$vf" ${sets[@]+"${sets[@]}"}); then
        echo "Değişkenler geçersiz; çalıştırılmadı." >&2; return "$refused"
    fi
    while IFS= read -r line; do
        case "$line" in warn=*) warn_names+=("${line#warn=}") ;; esac
    done <<< "$w"
    comp_gate_warn_vars ${warn_names[@]+"${warn_names[@]}"} || return "$refused"

    # ---- onay (effects + uyarılar gösterilir) ----
    comp_gate_confirm "$info" "$action" "$server" || return "$refused"

    # ---- girdiler ----
    group=$(comp_info_get "$info" inventory_group); group="${group:-sshpocket}"
    comp_run_write_inventory "$inv" "$group" "$server" "$COMP_CTX_HOST" "$COMP_CTX_USER" "$COMP_CTX_PORT" "$COMP_CTX_KEY" || return "$refused"
    comp_run_build_argv "$info" "$action" "$inv" "$server" "$vf" || return "$refused"
    prog="${COMP_RUN_ARGV[0]}"
    if [[ "$prog" == */* ]] || [ ! -x "$bindir/$prog" ]; then echo "Çalıştırılacak program bulunamadı: $prog" >&2; return "$refused"; fi
    COMP_RUN_ARGV[0]="$bindir/$prog"

    # sudo parolası istemi: Ansible yalnızca "BECOME password:" yazar; ne olduğunu önceden açıkla
    for w in "${COMP_RUN_ARGV[@]}"; do
        if [ "$w" = "--ask-become-pass" ] || [ "$w" = "-K" ]; then
            {
                echo "🔑 Sudo parolası istenecek: aşağıdaki 'BECOME password:' sunucudaki sudo parolasıdır."
                echo "   Sudo parola istemiyorsa (NOPASSWD) yalnızca Enter'a basın."
                echo "   Parola yalnızca Ansible'ın kendi istemine girilir; sshpocket'e, günlüğe ya da komut satırına yazılmaz."
            } >&2
            break
        fi
    done

    # ---- çalıştır (günlük kullanıcı klasöründe, izin 600; kullanıcı terminali çıktıyı olduğu gibi görür) ----
    log="$sdir/last-run.log"
    ( umask 077; : > "$log" ) || return "$refused"
    {
        cd "$pkg" && env ANSIBLE_CONFIG="$pkg/ansible.cfg" ANSIBLE_HOST_KEY_CHECKING=True PATH="$bindir:$PATH" "${COMP_RUN_ARGV[@]}"
    } 2>&1 | tee -a "$log"
    rc="${PIPESTATUS[0]}"
    return "$rc"
}

# comp_exec_action <bilgi> <paket> <sürüm> <eylem> → kapılar, çalıştırma, sonuç ayrıştırma ve kayıt
comp_exec_action() {
    local info="$1" id="$2" ver="$3" action="$4" rc sdir
    COMP_EXEC_RESULT=""
    ( _comp_exec_body "$info" "$id" "$ver" "$action" )
    rc=$?
    [ "$rc" -eq "$COMP_EXEC_REFUSED" ] && return "$rc"            # hiçbir şey çalışmadı: kayıt yok
    sdir=$(comp_gate_state_ensure "$id" "$COMP_CTX_SERVER") || return "$rc"
    comp_exec_parse_result "$info" "$action" "$sdir/last-run.log" || true
    if [ "$rc" -eq 0 ]; then comp_gate_record "$id" "$COMP_CTX_SERVER" "$ver" "$action" ok || true
    else comp_gate_record "$id" "$COMP_CTX_SERVER" "$ver" "$action" fail || true; fi
    return "$rc"
}
