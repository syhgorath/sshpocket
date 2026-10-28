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
#   COMP_CTX_BECOME_EXE   boş ya da /usr/bin/sudo.ws (Ubuntu'da sudo-rs + parolalı sudo için; envantere ansible_become_exe olarak yazılır)
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

# --- script runner (docs/package-standard.md §7) ---
COMP_EXEC_REMOTE_TMP=""

# _comp_exec_remote_rm → sudo'lu yolda sunucuya yazılan geçici betiği (içinde değişken değerleri olabilir) siler; her çıkışta çağrılır, hata verirse sessiz geçer
_comp_exec_remote_rm() {
    [ -n "$COMP_EXEC_REMOTE_TMP" ] || return 0
    [[ "$COMP_EXEC_REMOTE_TMP" =~ ^/tmp/sshpocket-[A-Za-z0-9]{8}$ ]] || return 0
    ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 \
        -o PreferredAuthentications=publickey -o PasswordAuthentication=no \
        -p "$COMP_CTX_PORT" -i "$COMP_CTX_KEY" "$COMP_CTX_USER@$COMP_CTX_HOST" "rm -f $COMP_EXEC_REMOTE_TMP" >/dev/null 2>&1 || true
    COMP_EXEC_REMOTE_TMP=""
}

# _comp_exec_script <bilgi> <eylem> <vars.json> <yerel-iş-klasörü> <durum-klasörü>
# Betik paketin 'scripts/' klasöründen okunur; başına SSHPOCKET_* export satırları eklenir ve SUNUCUDA 'bash -s -- <argümanlar>' ile çalışır.
#  · sudo gerekmiyorsa: ssh stdin'inden akıtılır (betik stdin okuyamaz).
#  · requires_sudo ise: sunucuda 0600 geçici dosyaya yazılır, ssh -t ile (sudo istemi AYNI terminalde) çalıştırılır, HER çıkışta silinir.
_comp_exec_script() {
    local info="$1" action="$2" vf="$3" work="$4" sdir="$5" refused="$COMP_EXEC_REFUSED"
    local cmd script payload log rc rpath sudo_prog rargs w
    local -a words ssh_base
    cmd=$(comp_action_get "$info" "$action" cmd)
    IFS=' ' read -r -a words <<< "$cmd"
    script="$COMP_CTX_PKGDIR/${words[0]}"
    if [ ! -f "$script" ] || [ -L "$script" ] || [ "$(wc -c < "$script" | tr -d ' ')" -gt 262144 ]; then
        echo "Betik bulunamadı, sembolik bağ ya da çok büyük (en çok 256 KB): ${words[0]}" >&2; return "$refused"
    fi
    payload="$work/payload.sh"
    { python3 -I "$COMP_RUN_PY" env "$vf" "$COMP_CTX_SERVER" "$action" "$COMP_CTX_PROFILE" && cat "$script"; } > "$payload" \
        || { echo "Betik hazırlanamadı (değişkenler)." >&2; return "$refused"; }
    rargs=""
    for w in "${words[@]:1}"; do rargs="$rargs $(printf '%q' "$w")"; done
    ssh_base=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10
              -o PreferredAuthentications=publickey -o PasswordAuthentication=no -p "$COMP_CTX_PORT" -i "$COMP_CTX_KEY")
    log="$sdir/last-run.log"
    ( umask 077; : > "$log" ) || return "$refused"
    # shellcheck disable=SC2064
    trap "rm -r -- $(printf '%q' "$work") 2>/dev/null; _comp_exec_remote_rm" EXIT

    if [ "$(comp_action_get "$info" "$action" sudo)" = "yes" ]; then
        # shellcheck disable=SC2016  # $f sunucuda genişler (yerelde değil)
        rpath=$("${ssh_base[@]}" "$COMP_CTX_USER@$COMP_CTX_HOST" 'umask 077; f=$(mktemp /tmp/sshpocket-XXXXXXXX) && cat > "$f" && printf %s "$f"' < "$payload" 2>/dev/null) \
            || { echo "Betik sunucuya yazılamadı." >&2; return "$refused"; }
        [[ "$rpath" =~ ^/tmp/sshpocket-[A-Za-z0-9]{8}$ ]] || { echo "Sunucudaki geçici betik yolu beklenmedik: çalıştırılmadı." >&2; return "$refused"; }
        COMP_EXEC_REMOTE_TMP="$rpath"
        sudo_prog="sudo"; [ -n "${COMP_CTX_BECOME_EXE:-}" ] && sudo_prog="$COMP_CTX_BECOME_EXE"
        {
            echo "🔑 Sudo parolası istenecek: aşağıdaki istem sunucudaki sudo parolasıdır (sudo parola istemiyorsa yalnızca Enter)."
            echo "   Parola yalnızca sunucunun sudo isteminde girilir; sshpocket'e, günlüğe ya da komut satırına yazılmaz."
        } >&2
        "${ssh_base[@]}" -t "$COMP_CTX_USER@$COMP_CTX_HOST" "$sudo_prog bash $rpath$rargs" 2>&1 | tee -a "$log"
        rc="${PIPESTATUS[0]}"
        _comp_exec_remote_rm
    else
        "${ssh_base[@]}" "$COMP_CTX_USER@$COMP_CTX_HOST" "bash -s --$rargs" < "$payload" 2>&1 | tee -a "$log"
        rc="${PIPESTATUS[0]}"
    fi
    return "$rc"
}

# _comp_exec_body <bilgi> <paket> <sürüm> <eylem> → alt kabukta çalışır; geçici dosyalar HER çıkışta (Ctrl-C/TERM dahil) silinir
_comp_exec_body() {
    local info="$1" id="$2" ver="$3" action="$4" kv
    local server="$COMP_CTX_SERVER" pkg="$COMP_CTX_PKGDIR" bindir="${COMP_CTX_BINDIR:-}" runner work sdir vf inv group dir_var outdir log w prog rc line
    local -a sets warn_names
    local refused="$COMP_EXEC_REFUSED"

    runner=$(comp_info_get "$info" runner)
    [ -f "$pkg/component.json" ] || { echo "Paket dizini bulunamadı." >&2; return "$refused"; }
    case "$runner" in
        ansible) [ -d "$bindir" ] || { echo "Python ortamı (venv) bulunamadı." >&2; return "$refused"; } ;;
        script) ;;
        *) echo "Desteklenmeyen runner: $runner" >&2; return "$refused" ;;
    esac

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
    trap 'exit 129' HUP      # terminal penceresi kapanırsa da geçici dosyalar silinsin
    vf="$work/vars.json"; inv="$work/inventory"

    # ---- değişkenler: dir_var HER ZAMAN kullanıcı klasörüne yönlendirilir (hassas çıktı USB'ye yazılmaz) ----
    sets=()
    dir_var=$(comp_action_get "$info" "$action" outputs.dir_var)
    if [ -n "$dir_var" ]; then
        outdir="$sdir/out"
        if ! ( umask 077; mkdir -p "$outdir" ) || ! chmod 700 "$outdir"; then echo "Çıktı klasörü oluşturulamadı." >&2; return "$refused"; fi
        sets=(--set "$dir_var=$outdir")
    fi
    # eylem düzeyi sabit değişkenler (manifest action.set): kullanıcının .vars değerinin ÜSTÜNE yazılır (örn. *_preview eylemi pve_apply=false'u zorlar)
    while IFS= read -r kv; do
        [ -n "$kv" ] && sets+=(--set "$kv")
    done < <(comp_info_all "$info" "action.$action.set")
    warn_names=()
    # Salt okunur, başka eylemin ön koşulu olmayan eylemler (rollback_status vb.) zorunlu değişken istemez; değer verilmişse yine doğrulanır
    if ! comp_gate_required_applies "$info" "$action"; then sets+=(--no-required); fi
    if ! w=$(comp_run_vars "$pkg/component.json" "${COMP_CTX_VALUES:-/dev/null}" "$vf" ${sets[@]+"${sets[@]}"}); then
        echo "Değişkenler geçersiz; çalıştırılmadı." >&2; return "$refused"
    fi
    while IFS= read -r line; do
        case "$line" in warn=*) warn_names+=("${line#warn=}") ;; esac
    done <<< "$w"
    if comp_gate_warn_applies "$info" "$action"; then
        comp_gate_warn_vars ${warn_names[@]+"${warn_names[@]}"} || return "$refused"
    fi

    # ---- onay (effects + uyarılar gösterilir) ----
    comp_gate_confirm "$info" "$action" "$server" || return "$refused"

    # ---- script runner: betik SUNUCUDA çalışır (Mac'te yabancı kod çalışmaz); kapılar/değişkenler/onay yukarıda ortak ----
    if [ "$runner" = "script" ]; then
        _comp_exec_script "$info" "$action" "$vf" "$work" "$sdir"
        return $?
    fi

    # ---- girdiler ----
    group=$(comp_info_get "$info" inventory_group); group="${group:-sshpocket}"
    comp_run_write_inventory "$inv" "$group" "$server" "$COMP_CTX_HOST" "$COMP_CTX_USER" "$COMP_CTX_PORT" "$COMP_CTX_KEY" "${COMP_CTX_BECOME_EXE:-}" || return "$refused"
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
        cd "$pkg" && env ANSIBLE_CONFIG="$pkg/ansible.cfg" ANSIBLE_HOST_KEY_CHECKING=True ANSIBLE_TIMEOUT="${ANSIBLE_TIMEOUT:-30}" PATH="$bindir:$PATH" "${COMP_RUN_ARGV[@]}"
    } 2>&1 | tee -a "$log"
    rc="${PIPESTATUS[0]}"
    if [ "$rc" -ne 0 ] && grep -q "waiting for privilege escalation prompt" "$log" 2>/dev/null; then
        {
            echo "  ↳ Sudo istemi beklenirken zaman aşımı: sudo parolası yanlış olabilir ya da sunucudaki sudo Ansible ile uyumsuz olabilir"
            echo "    (Ubuntu 26.04'te varsayılan sudo-rs parolalı kullanımda takılır). Parolayı kontrol edin; sudo'yu elle deneyin (ssh ile: sudo -v)."
        } >&2
    fi
    return "$rc"
}

# comp_exec_save_result <durum-klasörü> <eylem> → COMP_EXEC_RESULT'ı "result.<eylem>" dosyasına yazar (ilk satır: epoch; izin 600, atomik)
comp_exec_save_result() {
    local sdir="$1" action="$2" tmp
    [[ "$action" =~ ^[a-z][a-z0-9_]{0,63}$ ]] || return 1
    [ -n "$COMP_EXEC_RESULT" ] || return 0
    tmp=$(mktemp "$sdir/result.XXXXXX") || return 1
    chmod 600 "$tmp"
    if ! { date +%s; printf '%s\n' "$COMP_EXEC_RESULT"; } > "$tmp" || ! mv -f -- "$tmp" "$sdir/result.$action"; then
        rm -f -- "$tmp"; return 1
    fi
}

# comp_exec_last_result <paket> <sunucu> <eylem> → ilk satır epoch, sonra "anahtar=değer" satırları; kayıt yoksa 1
comp_exec_last_result() {
    local f
    f="$(_comp_gate_state_dir)/$1/$2/result.$3"
    [[ "$3" =~ ^[a-z][a-z0-9_]{0,63}$ ]] && _comp_gate_name_ok "$2" && comp_id_valid "$1" && [ -f "$f" ] || return 1
    head -n 40 "$f"
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
    comp_exec_save_result "$sdir" "$action" || true
    if [ "$rc" -eq 0 ]; then comp_gate_record "$id" "$COMP_CTX_SERVER" "$ver" "$action" ok || true
    else comp_gate_record "$id" "$COMP_CTX_SERVER" "$ver" "$action" fail || true; fi
    return "$rc"
}
