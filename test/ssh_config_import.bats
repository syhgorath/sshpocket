#!/usr/bin/env bats
load test_helper
setup() {
    # shellcheck source=/dev/null
    source "$H/SSHConfigImport.sh"
    CFG="$BATS_TEST_TMPDIR/config"
    cat > "$CFG" <<'CONF'
# yorum
Host *
    ServerAliveInterval 30

Host web1 web2
    HostName 192.0.2.10
    User deploy
    Port 2200
    IdentityFile ~/.ssh/id_web

Host=db
    HostName=db.example.com
    user = admin

Host bare

Host *.internal gate?
    User nobody

Match host foo
    User matched

Host after-match
    HostName 192.0.2.99
CONF
}

@test "joker içeren Host kayıtları atlanır" {
    run ssh_config_hosts "$CFG"
    [[ "$output" != *"*"* ]]
    [[ "$output" != *"nobody"* ]]
}
@test "birden çok alias ayrı satır olur" {
    run ssh_config_hosts "$CFG"
    [[ "$output" == *"web1|192.0.2.10|deploy|2200|~/.ssh/id_web"* ]]
    [[ "$output" == *"web2|192.0.2.10|deploy|2200|~/.ssh/id_web"* ]]
}
@test "'=' sözdizimi ve büyük/küçük harf" {
    run ssh_config_hosts "$CFG"
    [[ "$output" == *"db|db.example.com|admin||"* ]]
}
@test "HostName yoksa alias kullanılır" {
    run ssh_config_hosts "$CFG"
    [[ "$output" == *"bare|bare|||"* ]]
}
@test "Match bloğunun ayarları sızmaz" {
    run ssh_config_hosts "$CFG"
    [[ "$output" != *"matched"* ]]
    [[ "$output" == *"after-match|192.0.2.99|||"* ]]
}
@test "modül adı üretimi" {
    run ssh_config_module_name "Web-1";   [ "$output" = "web_1" ]
    run ssh_config_module_name "1host";   [ "$output" = "h_1host" ]
    run ssh_config_module_name "my.srv";  [ "$output" = "my_srv" ]
}
@test "CLI: seçilenleri modül olarak içe aktarır, mevcut olanı atlar" {
    export SSHPOCKET_MODULES_DIR="$BATS_TEST_TMPDIR/Modules"
    mkdir -p "$SSHPOCKET_MODULES_DIR/db"
    run bash "$ROOT/sistem/ImportSSHConfig.sh" "$CFG" <<< "a"
    [ "$status" -eq 0 ]
    [ -f "$SSHPOCKET_MODULES_DIR/web1/Web1Module.sh" ]
    [ -f "$SSHPOCKET_MODULES_DIR/web2/Web2Module.sh" ]
    [[ "$output" == *"db zaten var"* ]]
    # private key kopyalanmaz, yol .env'e yazılır
    grep -q 'WEB1_KEY=~/.ssh/id_web' "$SSHPOCKET_MODULES_DIR/web1/.env"
    [ -z "$(ls "$SSHPOCKET_MODULES_DIR/web1" | grep id_ed25519 || true)" ]
}
@test "CLI: Enter iptal eder" {
    export SSHPOCKET_MODULES_DIR="$BATS_TEST_TMPDIR/Modules"
    mkdir -p "$SSHPOCKET_MODULES_DIR"
    run bash "$ROOT/sistem/ImportSSHConfig.sh" "$CFG" <<< ""
    [[ "$output" == *"İptal"* ]]
    [ -z "$(ls -A "$SSHPOCKET_MODULES_DIR")" ]
}
@test "CLI: geçersiz hostname içeren kayıt atlanır" {
    printf 'Host evil\n    HostName a$(id)\n' > "$CFG"
    export SSHPOCKET_MODULES_DIR="$BATS_TEST_TMPDIR/Modules"
    mkdir -p "$SSHPOCKET_MODULES_DIR"
    run bash "$ROOT/sistem/ImportSSHConfig.sh" "$CFG" <<< "a"
    [[ "$output" == *"içe aktarılamadı"* ]]
    [ ! -e "$SSHPOCKET_MODULES_DIR/evil" ]
}
