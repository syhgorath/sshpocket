#!/usr/bin/env bats
# Aşama 3, PR C: yürütücü (sahte ansible-playbook; ağ yok, VM'e dokunmaz)
load test_helper

setup() {
    export SISTEM_PATH="$ROOT/sistem"
    source "$H/Components.sh"
    source "$H/ComponentsInstall.sh"
    source "$H/ComponentsManifest.sh"
    source "$H/ComponentsRun.sh"
    source "$H/ComponentsGates.sh"
    source "$H/ComponentsExec.sh"
    T="$BATS_TEST_TMPDIR"
    export SSHPOCKET_STATE_DIR="$T/state" TMPDIR="$T/tmp"
    mkdir -p "$T/tmp" "$T/pkg" "$T/bin"
    # --- paket ---
    cat > "$T/pkg/component.json" <<'JSON'
{"id":"demo","version":"1.0.0","sshpocket_api":1,"runner":"ansible","inventory_group":"hardening",
 "profiles":[{"id":"ubuntu-26.04","status":"supported"}],
 "actions":{
  "preview":{"cmd":"ansible-playbook playbooks/harden.yml --check","effects":[],"requires_sudo":true},
  "audit":{"cmd":"ansible-playbook playbooks/audit.yml","effects":["installs-package"],"confirm":"yes-no",
           "outputs":{"dir_var":"scan_dir"}},
  "status":{"cmd":"ansible-playbook playbooks/status.yml","effects":[],
            "outputs":{"format":"keyvalue-line","prefix":"SSHPOCKET_RESULT demo.status","keys":["armed","remaining_seconds","timer"]}},
  "apply":{"cmd":"ansible-playbook playbooks/harden.yml","effects":["changes-config"],"requires":["preview"],"confirm":"yes-no"}},
 "vars":[{"name":"allow_from","type":"list[cidr]","required":true},
         {"name":"scan_dir","type":"path"},
         {"name":"rb_enabled","type":"bool","default":true,"warn_if":false}],
 "invoke":{"append":[{"arg":"-i","value":"<inventory>","required":true},{"arg":"--limit","value":"<server>","required":true},
                     {"arg":"--ask-become-pass","required":true,"interactive":true}]}}
JSON
    echo "[defaults]" > "$T/pkg/ansible.cfg"
    INFO=$(comp_manifest_info "$T/pkg/component.json" demo 1.0.0)
    printf 'allow_from=10.1.10.0/24\n' > "$T/values"
    # --- sahte ansible-playbook ---
    cat > "$T/bin/ansible-playbook" <<STUB
#!/bin/bash
echo "\$*" > "$T/args"
echo "\$PWD" > "$T/pwd"
echo "\$ANSIBLE_CONFIG|\$ANSIBLE_HOST_KEY_CHECKING" > "$T/envseen"
# -i ve -e @ dosyalarının İÇERİĞİNİ çalışma sırasında kaydet
while [ \$# -gt 0 ]; do case "\$1" in -i) cp "\$2" "$T/seen_inv"; stat -c %a "\$2" >/dev/null 2>&1 && stat -c %a "\$2" > "$T/inv_mode" || stat -f %Lp "\$2" > "$T/inv_mode"; echo "\$2" > "$T/inv_path";; -e) f="\${2#@}"; cp "\$f" "$T/seen_vars"; echo "\$f" > "$T/vars_path";; esac; shift; done
[ -n "\${FAKE_OUT:-}" ] && printf '%s\n' "\$FAKE_OUT"
[ -n "\${FAKE_KILL_PARENT:-}" ] && { touch "$T/started"; kill -TERM \$(ps -o ppid= -p \$PPID | tr -d ' '); sleep 30; }
exit \${FAKE_RC:-0}
STUB
    chmod +x "$T/bin/ansible-playbook"
    # --- bağlam ---
    COMP_CTX_PKGDIR="$T/pkg"; COMP_CTX_BINDIR="$T/bin"; COMP_CTX_SERVER=web1; COMP_CTX_HOST=10.1.10.193
    COMP_CTX_USER=ziya; COMP_CTX_PORT=22; COMP_CTX_KEY=/Volumes/test/k; COMP_CTX_PREFIX=WEB1
    COMP_CTX_PROFILE=ubuntu-26.04; COMP_CTX_VALUES="$T/values"
    # kapıların kendi testleri components_gates.bats'ta: burada geçecek şekilde sahtelenir
    comp_gate_known_host() { return 0; }
    comp_gate_agent() { return 0; }
}

modeof() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
tmpleft() { ls -d "$T"/tmp/sshpocket-run.* 2>/dev/null | wc -l | tr -d ' '; }

@test "yürütme: salt okunur eylem çalışır; argv, çalışma dizini, ortam, geçici dosya içeriği ve izinleri doğru" {
    run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 0 ]
    read -r a < "$T/args"
    [[ "$a" == "playbooks/harden.yml --check -i "*" --limit web1 -e @"*" --ask-become-pass" ]] || false
    [ "$(cat "$T/pwd")" = "$(cd "$T/pkg" && pwd -P)" ] || [ "$(cat "$T/pwd")" = "$T/pkg" ]
    [ "$(cat "$T/envseen")" = "$T/pkg/ansible.cfg|True" ]
    grep -q "^\[hardening\]" "$T/seen_inv"
    grep -q "web1 ansible_host=10.1.10.193 ansible_user=ziya ansible_port=22 ansible_private_key_file='/Volumes/test/k'" "$T/seen_inv"
    [ "$(cat "$T/inv_mode")" = "600" ]
    grep -q '"allow_from"' "$T/seen_vars"
    [ "$(tmpleft)" = "0" ]                                  # geçici dosyalar silindi
    [ ! -e "$(cat "$T/inv_path")" ] && [ ! -e "$(cat "$T/vars_path")" ]
    [ "$(modeof "$T/state/demo/web1/last-run.log")" = "600" ]
    grep -q '|1.0.0|preview|ok$' "$T/state/demo/web1/results"
}

@test "yürütme: ortamdan ANSIBLE_HOST_KEY_CHECKING=False gelse bile True zorlanır" {
    ANSIBLE_HOST_KEY_CHECKING=False run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 0 ]
    [ "$(cat "$T/envseen")" = "$T/pkg/ansible.cfg|True" ]
}

@test "yürütme: playbook başarısızsa kodu döner, 'fail' kaydedilir, geçici dosyalar silinir" {
    FAKE_RC=2 run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 2 ]
    grep -q '|1.0.0|preview|fail$' "$T/state/demo/web1/results"
    [ "$(tmpleft)" = "0" ]
}

@test "yürütme: kapı durdurursa playbook HİÇ çalışmaz, kayıt yok, 190 döner" {
    comp_gate_known_host() { echo "tanınmıyor" >&2; return 1; }
    run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 190 ]
    [ ! -e "$T/args" ]
    [ ! -e "$T/state/demo/web1/results" ]
    [ "$(tmpleft)" = "0" ]
}

@test "yürütme: her kapı ayrı ayrı durdurur (agent, root, profil, requires)" {
    comp_gate_agent() { return 1; };            run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null; [ "$status" -eq 190 ]
    comp_gate_agent() { return 0; }
    COMP_CTX_USER=root;                         run comp_exec_action "$INFO" demo 1.0.0 apply </dev/null;   [ "$status" -eq 190 ]
    COMP_CTX_USER=ziya; COMP_CTX_PROFILE=rpi;   run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null; [ "$status" -eq 190 ]
    COMP_CTX_PROFILE=ubuntu-26.04;              run comp_exec_action "$INFO" demo 1.0.0 apply <<<"e";       [ "$status" -eq 190 ]
    [[ "$output" == *"önce 'preview'"* ]] || false
    [ ! -e "$T/args" ]
}

@test "yürütme: geçersiz/eksik değişken çalıştırmaz" {
    : > "$T/values"
    run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 190 ]
    [ ! -e "$T/args" ]
}

@test "yürütme: confirm reddedilirse çalıştırmaz; kabul edilirse çalıştırır" {
    run comp_exec_action "$INFO" demo 1.0.0 audit <<<"h"; [ "$status" -eq 190 ]; [ ! -e "$T/args" ]
    run comp_exec_action "$INFO" demo 1.0.0 audit </dev/null; [ "$status" -eq 190 ]; [ ! -e "$T/args" ]
    run comp_exec_action "$INFO" demo 1.0.0 audit <<<"e"; [ "$status" -eq 0 ]; [ -e "$T/args" ]
}

@test "yürütme: warn_if eşleşirse ayrıca onay istenir" {
    printf 'allow_from=10.1.10.0/24\nrb_enabled=false\n' > "$T/values"
    run comp_exec_action "$INFO" demo 1.0.0 preview <<<"h"; [ "$status" -eq 190 ]; [ ! -e "$T/args" ]
    run comp_exec_action "$INFO" demo 1.0.0 preview <<<"e"; [ "$status" -eq 0 ]
}

@test "yürütme: apply, taze preview kaydından sonra çalışır" {
    comp_gate_record demo web1 1.0.0 preview ok
    run comp_exec_action "$INFO" demo 1.0.0 apply <<<"e"
    [ "$status" -eq 0 ]
    grep -q '|1.0.0|apply|ok$' "$T/state/demo/web1/results"
}

@test "yürütme: dir_var kullanıcı klasörüne ZORLANIR (değerler dosyasındaki USB yolu ezilir), klasör 0700" {
    printf 'allow_from=10.1.10.0/24\nscan_dir=/Volumes/test/oops\n' > "$T/values"
    run comp_exec_action "$INFO" demo 1.0.0 audit <<<"e"
    [ "$status" -eq 0 ]
    grep -q "\"scan_dir\": \"$T/state/demo/web1/out\"" "$T/seen_vars"
    run ! grep -q "/Volumes/test/oops" "$T/seen_vars"
    [ "$(modeof "$T/state/demo/web1/out")" = "700" ]
}

@test "yürütme: bin dizininde program yoksa ya da cmd yol içeriyorsa çalıştırmaz" {
    rm "$T/bin/ansible-playbook"
    run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ "$status" -eq 190 ]
    [ "$(tmpleft)" = "0" ]
}

@test "yürütme: TERM (Ctrl-C benzeri) gelirse geçici dosyalar yine de silinir" {
    FAKE_KILL_PARENT=1 run comp_exec_action "$INFO" demo 1.0.0 preview </dev/null
    [ -e "$T/started" ]
    [ "$status" -ne 0 ]
    sleep 1
    [ "$(tmpleft)" = "0" ]
    [ ! -e "$(cat "$T/inv_path")" ]
}

# ---------- sonuç satırı ----------
res() { printf '%s\n' "$1" > "$T/log"; comp_exec_parse_result "$INFO" status "$T/log"; }

@test "sonuç: düz, yaml-girintili ve json-tırnaklı satırlar ayrıştırılır" {
    res 'SSHPOCKET_RESULT demo.status armed=yes timer=active remaining_seconds=120'
    [ "$COMP_EXEC_RESULT" = $'armed=yes\ntimer=active\nremaining_seconds=120' ]
    res '        msg: |-
          SSHPOCKET_RESULT demo.status armed=no timer=inactive'
    [ "$COMP_EXEC_RESULT" = $'armed=no\ntimer=inactive' ]
    res '"msg": "SSHPOCKET_RESULT demo.status armed=yes\n"'
    [ "$COMP_EXEC_RESULT" = "armed=yes" ]
}

@test "sonuç: son satır geçerli sayılır; yanlış önek, bilinmeyen anahtar, kötü değer, yinelenen anahtar, satır yok → ret" {
    printf 'SSHPOCKET_RESULT demo.status armed=no\nSSHPOCKET_RESULT demo.status armed=yes\n' > "$T/log"
    comp_exec_parse_result "$INFO" status "$T/log"; [ "$COMP_EXEC_RESULT" = "armed=yes" ]
    for bad in 'SSHPOCKET_RESULT other.status armed=yes' 'SSHPOCKET_RESULT demo.apply armed=yes' 'SSHPOCKET_RESULT demo.status evil=1' \
               'SSHPOCKET_RESULT demo.status armed=a;b' 'SSHPOCKET_RESULT demo.status armed=yes armed=no' 'SSHPOCKET_RESULT demo.status armed' 'merhaba'; do
        run res "$bad"
        [ "$status" -ne 0 ] || { echo "KABUL EDİLDİ: $bad"; return 1; }
    done
}

@test "sonuç: outputs.format olmayan eylem için ayrıştırma sessizce atlanır" {
    printf 'SSHPOCKET_RESULT demo.preview x=1\n' > "$T/log"
    run comp_exec_parse_result "$INFO" preview "$T/log"
    [ "$status" -eq 0 ]
}

@test "yürütme + sonuç: status çalışınca COMP_EXEC_RESULT dolar" {
    FAKE_OUT='SSHPOCKET_RESULT demo.status armed=yes timer=active remaining_seconds=42' comp_exec_action "$INFO" demo 1.0.0 status </dev/null
    [ "$COMP_EXEC_RESULT" = $'armed=yes\ntimer=active\nremaining_seconds=42' ]
}

# ---------- bildirim: outputs doğrulaması ----------
mf() { printf '%s\n' "$1" > "$T/m.json"; }
BASE='"id":"demo","version":"1.0.0","sshpocket_api":1,"runner":"ansible","profiles":[{"id":"u","status":"supported"}]'

@test "bildirim outputs: geçerli biçim kabul; yanlış prefix, tanımsız dir_var, boş/yinelenen keys reddedilir" {
    mf "{$BASE,\"actions\":{\"s\":{\"cmd\":\"x\",\"effects\":[],\"outputs\":{\"format\":\"keyvalue-line\",\"prefix\":\"SSHPOCKET_RESULT demo.s\",\"keys\":[\"a\"]}}}}"
    run comp_manifest_info "$T/m.json" demo 1.0.0; [ "$status" -eq 0 ]
    for o in '"format":"keyvalue-line","prefix":"SSHPOCKET_RESULT demo.baska","keys":["a"]' '"format":"keyvalue-line","keys":[]' \
             '"format":"keyvalue-line","keys":["a","a"]' '"format":"keyvalue-line","keys":["A!"]' '"format":"json"' '"dir_var":"yok"' '"keys":["a"]'; do
        mf "{$BASE,\"actions\":{\"s\":{\"cmd\":\"x\",\"effects\":[],\"outputs\":{$o}}}}"
        run comp_manifest_info "$T/m.json" demo 1.0.0
        [ "$status" -ne 0 ] || { echo "KABUL EDİLDİ: $o"; return 1; }
    done
}
