#!/usr/bin/env bats
load test_helper

setup() {
    load_helpers
    # load_helpers gerçek tuş okuyucuyu yükler; sahte kuyrukla değiştir (pty gerekmez)
    _ui_read_key() { UI_KEY="${KEYQ[$KEYI]:-EOF}"; KEYI=$((KEYI + 1)); }
}

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

# ---------- ok tuşlu seçim (sahte tuş kuyruğu, pty gerekmez) ----------
feed() { KEYQ=("$@"); KEYI=0; }
pick() { ui_pick_arrows "$@" 2>/dev/null; }

@test "ok tuşu: Enter başlangıç satırını seçer" {
    feed ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "1" ]
}

@test "ok tuşu: aşağı/yukarı hareket eder, sarar" {
    feed DOWN DOWN ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "3" ]
    feed UP ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "0" ]          # yukarı sararak Geri satırına gider
    feed DOWN DOWN DOWN DOWN ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "1" ]          # aşağı sararak başa döner
}

@test "ok tuşu: j/k hareket eder" {
    feed CHAR:j CHAR:j CHAR:k ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "2" ]
}

@test "ok tuşu: q, Q, sol ok, ESC ve EOF geri (0) verir" {
    for k in CHAR:q CHAR:Q LEFT ESC; do
        feed DOWN "$k"
        run pick 1 "Geri" "A" "B"
        [ "$output" = "0" ]
    done
    feed
    run pick 1 "Geri" "A" "B"
    [ "$output" = "0" ]
}

@test "ok tuşu: numara yazıp Enter doğrudan seçer; 0 geri; geçersiz yok sayılır" {
    feed CHAR:2 ENTER
    run pick 1 "Geri" "A" "B" "C"
    [ "$output" = "2" ]
    feed CHAR:0 ENTER
    run pick 2 "Geri" "A" "B" "C"
    [ "$output" = "0" ]
    feed CHAR:9 ENTER ENTER                # 9 yok → temizlenir, ikinci Enter başlangıç satırını seçer
    run pick 3 "Geri" "A" "B" "C"
    [ "$output" = "3" ]
}

@test "ok tuşu: iki haneli numara ve Backspace" {
    items=(); for i in 1 2 3 4 5 6 7 8 9 10 11 12; do items+=("S$i"); done
    feed CHAR:1 CHAR:2 ENTER
    run pick 1 "Geri" "${items[@]}"
    [ "$output" = "12" ]
    feed CHAR:1 CHAR:2 BACKSPACE CHAR:0 ENTER
    run pick 1 "Geri" "${items[@]}"
    [ "$output" = "10" ]
}

@test "ok tuşu: imleç gizlenir ve her çıkışta geri açılır" {
    feed ENTER
    out=$(ui_pick_arrows 1 "Geri" "A" "B" 2>&1 >/dev/null)
    [[ "$out" == *$'\033[?25l'* ]]
    [[ "$out" == *$'\033[?25h'* ]]
}

@test "ok tuşu: çizim seçili satırı vurgular" {
    feed DOWN ENTER
    out=$(ui_pick_arrows 1 "Geri" "AAA" "BBB" 2>&1 >/dev/null)
    [[ "$out" == *$'\033[7m'*"BBB"* ]]
}

@test "ok tuşu: UI ayarı numbers ise etkin değil, arrows ise zorla etkin" {
    export SSHPOCKET_CONF="$BATS_TEST_TMPDIR/c.conf"
    SSHPOCKET_UI=numbers run ui_arrows_enabled
    [ "$status" -ne 0 ]
    SSHPOCKET_UI=arrows run ui_arrows_enabled
    [ "$status" -eq 0 ]
    SSHPOCKET_UI=auto run ui_arrows_enabled     # bats içinde terminal yok
    [ "$status" -ne 0 ]
}

@test "ok tuşu: Menu ok modunda seçilen modül fonksiyonunu döndürür" {
    source "$H/RegisterModules.sh"; source "$H/Menu.sh"
    RegisterModules "ONE" "MainMenu" "OneModule"
    RegisterModules "TWO" "MainMenu" "TwoModule"
    export SSHPOCKET_UI=arrows
    feed DOWN ENTER
    out=$(Menu "MainMenu" 2>/dev/null)
    [ "$out" = "TwoModule" ]
    feed CHAR:q
    out=$(Menu "MainMenu" 2>/dev/null)
    [ "$out" = "exit" ]
}

@test "ok tuşu (gerçek okuyucu): ESC dizileri çözülür, menüler ok modunda çalışır" {
    unset -f _ui_read_key
    source "$H/UI.sh"
    make_sandbox
    printf '#!/bin/bash\nexit 1\n' > "$SANDBOX/bin/diskutil"
    chmod +x "$SANDBOX/bin/"*
    mkdir -p "$SANDBOX/servers/alpha"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$SANDBOX/servers/alpha/server.env"
    # ↓ ↑ (başa dön) Enter → ALPHA menüsü; o menüde q → geri; Enter (devam); ana menüde q → çıkış
    run bash -c "printf '\033[B\033[A\nq\n\nq' | SSHPOCKET_UI=arrows SSHPOCKET_STATUS=off TERM=xterm PATH='$SANDBOX/bin:$PATH' bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"Ana menü › ALPHA"* ]]
    [[ "$output" == *"Exiting"* ]]
}

@test "ok tuşu (gerçek okuyucu): Ayarlar paneli ok modunda ayarı çevirir ve geri döner" {
    unset -f _ui_read_key
    source "$H/UI.sh"
    export SSHPOCKET_CONF="$BATS_TEST_TMPDIR/c.conf"
    export SISTEM_PATH="$ROOT/sistem"
    # Enter → 1. ayar (STATUS on→off); sonra q
    SSHPOCKET_UI=arrows run bash -c 'source "'"$H"'/Settings.sh"; source "'"$H"'/UI.sh"; clear(){ :; }; SettingsAction' <<< $'\nq'
    grep -q '^STATUS=off$' "$SSHPOCKET_CONF"
}

@test "ok tuşu (gerçek okuyucu): Sunucuları yönet ok modunda açılır, Sil seçilip ad boş bırakılırsa hiçbir şey silinmez" {
    unset -f _ui_read_key
    source "$H/UI.sh"
    make_sandbox
    mkdir -p "$SANDBOX/servers/alpha"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$SANDBOX/servers/alpha/server.env"
    run bash -c "export SSHPOCKET_UI=arrows SISTEM_PATH='$SANDBOX/sistem' TERM=xterm; \
        source '$SANDBOX/sistem/Helpers/Settings.sh'; source '$SANDBOX/sistem/Helpers/UI.sh'; source '$SANDBOX/sistem/Helpers/BuiltinMenu.sh' >/dev/null 2>&1; \
        ReloadModules(){ :; }; clear(){ :; }; \
        ManageServersAction" <<< $'\n\n'
    [[ "$output" == *"Ana menü › Sunucuları yönet"* ]]
    [[ "$output" == *$'\033[7m'*"Sil"* ]]          # ok moduna özgü vurgulu satır
    [ -f "$SANDBOX/servers/alpha/server.env" ]
}
