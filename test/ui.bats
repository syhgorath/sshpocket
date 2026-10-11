#!/usr/bin/env bats
load test_helper

setup() { load_helpers; }

@test "ui: boru/test çıktısında renk kodu yok (düz metin)" {
    run ui_header "Ana menü › x"
    [[ "$output" == *"Ana menü › x"* ]]
    [[ "$output" != *$'\033'* ]]
    run ui_footer "ipucu"
    [[ "$output" == *"ipucu"* ]]
    [[ "$output" != *$'\033'* ]]
}

@test "ui: grup başlığı çevrilir" {
    [ "$(ui_group_title MainMenu)" = "Ana menü" ]
    [ "$(ui_group_title Diger)" = "Diger" ]
}

@test "ui: server_summary kullanıcı@ip[:port] verir, eksik/geçersizde boş" {
    export SSHPOCKET_SERVERS_DIR="$BATS_TEST_TMPDIR/srv"
    mkdir -p "$SSHPOCKET_SERVERS_DIR"/{alpha,beta,gamma}
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=2222\n' > "$SSHPOCKET_SERVERS_DIR/alpha/server.env"
    printf 'IP=192.0.2.8\nUSER=root\n' > "$SSHPOCKET_SERVERS_DIR/beta/server.env"
    printf 'IP=$(touch x)\nUSER=root\n' > "$SSHPOCKET_SERVERS_DIR/gamma/server.env"
    [ "$(server_summary alpha)" = "deploy@192.0.2.7:2222" ]
    [ "$(server_summary beta)" = "root@192.0.2.8" ]
    [ -z "$(server_summary gamma)" ]
    [ -z "$(server_summary yok)" ]
}

@test "ui: ana menüde başlık, sunucu özeti ve alt ipucu görünür" {
    make_sandbox
    printf '#!/bin/bash\nexit 1\n' > "$SANDBOX/bin/diskutil"
    chmod +x "$SANDBOX/bin/"*
    mkdir -p "$SANDBOX/servers/alpha"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$SANDBOX/servers/alpha/server.env"
    run bash -c "printf '0\n' | TERM=xterm PATH='$SANDBOX/bin:$PATH' bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"Ana menü"* ]]
    [[ "$output" == *"deploy@192.0.2.7"* ]]
    [[ "$output" == *"0 veya q = çıkış"* ]]
}

@test "ui: modül menüsünde ekmek kırıntısı ve geri ipucu görünür" {
    make_sandbox
    printf '#!/bin/bash\nexit 1\n' > "$SANDBOX/bin/diskutil"
    chmod +x "$SANDBOX/bin/"*
    mkdir -p "$SANDBOX/servers/alpha"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$SANDBOX/servers/alpha/server.env"
    run bash -c "printf '1\n0\n\n0\n' | TERM=xterm PATH='$SANDBOX/bin:$PATH' bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"Ana menü › ALPHA"* ]]
    [[ "$output" == *"0 veya q = geri"* ]]
}
