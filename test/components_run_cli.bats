#!/usr/bin/env bats
# Aşama 3, PR D: --components run (sahte ssh ve ansible-playbook; ağ yok, VM'e dokunmaz)
load test_helper

setup() {
    export SISTEM_PATH="$ROOT/sistem"
    for f in Validate ModuleFiles SSHModule SSHHelper SSHModuleEdit Servers Components ComponentsInstall ComponentsManifest ComponentsVenv \
             ComponentsRun ComponentsGates ComponentsExec ComponentsRunCLI ComponentsCLI; do source "$H/$f.sh"; done
    T="$BATS_TEST_TMPDIR"
    export SSHPOCKET_SERVERS_DIR="$T/servers" SSHPOCKET_COMPONENTS_DIR="$T/comps" SSHPOCKET_STATE_DIR="$T/state" TMPDIR="$T/tmp"
    mkdir -p "$T/tmp" "$T/bin" "$T/venv/bin" "$T/servers/web1" "$T/comps/demo/1.0.0"
    export PATH="$T/bin:$PATH"
    printf 'IP=10.1.10.193\nUSER=ziya\nPORT=22\n' > "$T/servers/web1/server.env"
    : > "$T/servers/web1/id_ed25519_web1"
    printf 'allow_from=10.1.10.0/24\n' > "$T/servers/web1/demo.vars"
    cat > "$T/comps/demo/1.0.0/component.json" <<'JSON'
{"id":"demo","version":"1.0.0","sshpocket_api":1,"runner":"ansible","inventory_group":"hardening",
 "profiles":[{"id":"ubuntu-26.04","status":"supported"}],
 "requires":{"control":{"python":">=3.12"}},
 "actions":{"preview":{"cmd":"ansible-playbook playbooks/harden.yml --check","effects":[]}},
 "vars":[{"name":"allow_from","type":"list[cidr]","required":true}],
 "invoke":{"append":[{"arg":"--ask-become-pass","required":true,"interactive":true}]}}
JSON
    echo "[defaults]" > "$T/comps/demo/1.0.0/ansible.cfg"
    INFO=$(comp_manifest_info "$T/comps/demo/1.0.0/component.json" demo 1.0.0)
    # kapsam dışı bağımlılıklar (kendi testleri var) sahtelenir
    comp_prepare() { printf '%s\n' "$INFO"; }
    comp_gate_known_host() { return 0; }
    comp_gate_agent() { return 0; }
    comp_venv_lookup() { [ -e "$T/venv_ok" ] && printf '%s' "$T/venv"; }
    comp_venv_ensure() { echo ensure >> "$T/ensure_calls"; touch "$T/venv_ok"; printf '%s' "$T/venv"; }
    # sahte ssh: argümanları kaydeder, os-release basar
    cat > "$T/bin/ssh" <<STUB
#!/bin/bash
echo "\$*" >> "$T/ssh_calls"
[ "\${FAKE_SSH_FAIL:-0}" = 1 ] && exit 255
printf '%s\n' "\${FAKE_OSREL:-NAME=\"Ubuntu\"
ID=ubuntu
VERSION_ID=\"26.04\"}"
STUB
    chmod +x "$T/bin/ssh"
    cat > "$T/venv/bin/ansible-playbook" <<STUB
#!/bin/bash
echo "\$*" > "$T/ansible_args"
while [ \$# -gt 0 ]; do case "\$1" in -e) cp "\${2#@}" "$T/seen_vars";; esac; shift; done
exit \${FAKE_RC:-0}
STUB
    chmod +x "$T/venv/bin/ansible-playbook"
    touch "$T/venv_ok"
}

modeof() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

@test "run: sunucu bilgisi okunur, OS salt okunur ssh ile algılanır, eylem çalışır, kayıtlar yazılır" {
    run comp_cli_run demo preview web1 </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"Profil: ubuntu-26.04"* ]] || false
    [ "$(wc -l < "$T/ssh_calls" | tr -d ' ')" = "1" ]
    grep -q -- "-o BatchMode=yes" "$T/ssh_calls"
    grep -q -- "-o StrictHostKeyChecking=yes" "$T/ssh_calls"
    # uzak komut SABİT: satırın tamamı birebir eşleşmeli (ek komut sızdırılamaz)
    [ "$(cat "$T/ssh_calls")" = "-o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -o PreferredAuthentications=publickey -o PasswordAuthentication=no -p 22 -i $T/servers/web1/id_ed25519_web1 ziya@10.1.10.193 cat /etc/os-release" ]
    grep -q -- "--limit web1" "$T/ansible_args"
    grep -q '"allow_from"' "$T/seen_vars"                 # servers/web1/demo.vars kullanıldı
    grep -q '|1.0.0|preview|ok$' "$T/state/demo/web1/results"
    grep -qE '^[0-9TZ:-]+\|demo\|1.0.0\|preview\|ok$' "$T/servers/web1/components.log"
    [ "$(modeof "$T/servers/web1/components.log")" = "600" ]
}

@test "run: playbook başarısızsa kod döner ve components.log'a 'fail' yazılır" {
    FAKE_RC=2 run comp_cli_run demo preview web1 </dev/null
    [ "$status" -eq 2 ]
    grep -q '|preview|fail$' "$T/servers/web1/components.log"
}

@test "run: profil desteklenmiyorsa çalıştırılmaz (190), components.log'a yazılmaz" {
    FAKE_OSREL=$'ID=debian\nVERSION_ID="13"' run comp_cli_run demo preview web1 </dev/null
    [ "$status" -eq 190 ]
    [ ! -e "$T/ansible_args" ]
    [ ! -e "$T/servers/web1/components.log" ]
}

@test "run: ssh algılaması başarısız ya da os-release bozuk/kötü niyetliyse durur" {
    FAKE_SSH_FAIL=1 run comp_cli_run demo preview web1 </dev/null;  [ "$status" -eq 190 ]
    FAKE_OSREL=$'ID=ubuntu;rm -rf\nVERSION_ID="26.04"' run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    [[ "$output" == *"algılanamadı"* ]]          # bozuk değer hiç profil olarak kullanılmaz/gösterilmez
    [[ "$output" != *"rm -rf"* ]] || false
    FAKE_OSREL=$'ID=ubuntu' run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    FAKE_OSREL=' ' run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    [ ! -e "$T/ansible_args" ]
}

@test "run: Python ortamı yoksa onay istenir; H/EOF kurmaz, e kurar ve devam eder" {
    rm -f "$T/venv_ok"
    run comp_cli_run demo preview web1 <<<"h";    [ "$status" -eq 190 ]; [ ! -e "$T/ensure_calls" ]; [ ! -e "$T/ssh_calls" ]
    run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]; [ ! -e "$T/ensure_calls" ]
    run comp_cli_run demo preview web1 <<<"e";    [ "$status" -eq 0 ];   [ -e "$T/ensure_calls" ]
    [[ "$output" == *"yaklaşık 10 MB"* ]] || false
    [ -e "$T/ansible_args" ]
}

@test "run: ortam hazırsa hiçbir şey sorulmaz/kurulmaz" {
    run comp_cli_run demo preview web1 </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$T/ensure_calls" ]
}

@test "run: geçersiz argüman, bilinmeyen paket eylemi/sunucu ve eksik key ssh'a hiç gitmez" {
    run comp_cli_run demo preview;                       [ "$status" -eq 2 ]
    run comp_cli_run "Demo!" preview web1 </dev/null;    [ "$status" -eq 2 ]
    run comp_cli_run demo "pre view" web1 </dev/null;    [ "$status" -eq 2 ]
    run comp_cli_run demo preview "../x" </dev/null;     [ "$status" -eq 2 ]
    run comp_cli_run demo preview ".." </dev/null;       [ "$status" -eq 2 ]
    run comp_cli_run demo yok web1 </dev/null;           [ "$status" -eq 2 ]
    run comp_cli_run demo preview yok </dev/null;        [ "$status" -eq 2 ]
    rm "$T/servers/web1/id_ed25519_web1"
    run comp_cli_run demo preview web1 </dev/null;       [ "$status" -eq 190 ]
    [ ! -e "$T/ssh_calls" ]
}

@test "run: server.env'de geçersiz IP/kullanıcı reddedilir" {
    printf 'IP=10.0.0.1;rm\nUSER=ziya\n' > "$T/servers/web1/server.env"
    run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    printf 'IP=10.0.0.1\nUSER=-oProxyCommand=x\n' > "$T/servers/web1/server.env"
    run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    [ ! -e "$T/ssh_calls" ]
}

@test "run: kapı (known_hosts / agent) durdurursa ssh algılaması bile yapılmaz" {
    comp_gate_known_host() { return 1; }
    run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    [ ! -e "$T/ssh_calls" ]
    comp_gate_known_host() { return 0; }
    comp_gate_agent() { return 1; }
    run comp_cli_run demo preview web1 </dev/null; [ "$status" -eq 190 ]
    [ ! -e "$T/ssh_calls" ]
}

@test "components_cli: run alt komutu yönlendirilir; kullanım mesajı run'ı içerir" {
    run components_cli run demo preview web1 </dev/null
    [ "$status" -eq 0 ]
    run components_cli bilinmeyen
    [ "$status" -eq 2 ]
    [[ "$output" == *"run <paket> <eylem> <sunucu>"* ]] || false
}

@test "venv_lookup: sağlıklı ortam yoksa 1 döner ve hiçbir şey oluşturmaz" {
    unset -f comp_venv_lookup
    source "$H/ComponentsVenv.sh"
    export XDG_CACHE_HOME="$T/cache" HOME="$T/home"; mkdir -p "$T/home"
    printf 'x==1 --hash=sha256:%064d\n' 0 > "$T/comps/demo/1.0.0/requirements.txt"
    run comp_venv_lookup demo "$T/comps/demo/1.0.0" ">=3.0"
    [ "$status" -ne 0 ]
    [ ! -e "$T/cache" ] && [ ! -e "$T/home/.cache/sshpocket/venv" ]
}
