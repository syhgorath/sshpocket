#!/usr/bin/env bats
load test_helper

setup() {
    load_helpers
    export SSHPOCKET_CONF="$BATS_TEST_TMPDIR/sshpocket.conf"
    unset SSHPOCKET_STATUS SSHPOCKET_STATUS_TIMEOUT
}

@test "ayar: varsayılanlar (STATUS=on, STATUS_TIMEOUT=1)" {
    [ "$(settings_get STATUS)" = "on" ]
    [ "$(settings_get STATUS_TIMEOUT)" = "1" ]
    [ "$(settings_source STATUS)" = "default" ]
}

@test "ayar: dosya değeri varsayılanı ezer" {
    printf 'STATUS=off\nSTATUS_TIMEOUT=3\n' > "$SSHPOCKET_CONF"
    [ "$(settings_get STATUS)" = "off" ]
    [ "$(settings_get STATUS_TIMEOUT)" = "3" ]
    [ "$(settings_source STATUS)" = "file" ]
}

@test "ayar: ortam değişkeni dosyayı ezer (1/0 da kabul)" {
    printf 'STATUS=off\n' > "$SSHPOCKET_CONF"
    SSHPOCKET_STATUS=1 run settings_get STATUS
    [ "$output" = "on" ]
    SSHPOCKET_STATUS=on run settings_source STATUS
    [ "$output" = "env" ]
    printf 'STATUS=on\n' > "$SSHPOCKET_CONF"
    SSHPOCKET_STATUS=0 run settings_get STATUS
    [ "$output" = "off" ]
}

@test "ayar: geçersiz değerler yok sayılır, varsayılana düşer" {
    printf 'STATUS=maybe\nSTATUS_TIMEOUT=99\n' > "$SSHPOCKET_CONF"
    [ "$(settings_get STATUS)" = "on" ]
    [ "$(settings_get STATUS_TIMEOUT)" = "1" ]
    SSHPOCKET_STATUS_TIMEOUT='1;touch x' run settings_get STATUS_TIMEOUT
    [ "$output" = "1" ]
}

@test "ayar: dosya source edilmez (komut enjeksiyonu çalışmaz)" {
    printf 'STATUS=off\n$(touch %s/pwned)\nSTATUS_TIMEOUT=2; touch %s/pwned2\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$SSHPOCKET_CONF"
    [ "$(settings_get STATUS)" = "off" ]
    [ "$(settings_get STATUS_TIMEOUT)" = "1" ]
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
    [ ! -e "$BATS_TEST_TMPDIR/pwned2" ]
}

@test "ayar: set dosyayı oluşturur, diğer satırları korur, tek satır bırakır" {
    printf '# not\nSTATUS=on\nSTATUS=on\nBILINMEYEN=1\n' > "$SSHPOCKET_CONF"
    run settings_set STATUS off
    [ "$status" -eq 0 ]
    [ "$(grep -c '^STATUS=' "$SSHPOCKET_CONF")" -eq 1 ]
    grep -q '^STATUS=off$' "$SSHPOCKET_CONF"
    grep -q '^# not$' "$SSHPOCKET_CONF"
    grep -q '^BILINMEYEN=1$' "$SSHPOCKET_CONF"
    rm "$SSHPOCKET_CONF"
    settings_set STATUS_TIMEOUT 4
    [ "$(settings_get STATUS_TIMEOUT)" = "4" ]
}

@test "ayar: set geçersiz anahtar/değeri reddeder ve dosyaya dokunmaz" {
    run settings_set STATUS_TIMEOUT 0
    [ "$status" -ne 0 ]
    run settings_set NOPE 1
    [ "$status" -ne 0 ]
    run settings_set STATUS $'on\nEVIL=1'
    [ "$status" -ne 0 ]
    [ ! -e "$SSHPOCKET_CONF" ]
}

@test "ayar: panel STATUS'u çevirir, süreyi değiştirir ve q ile çıkar" {
    export SISTEM_PATH="$ROOT/sistem"
    clear() { :; }
    run bash -c 'source "'"$H"'/Settings.sh"; clear(){ :; }; SettingsAction' <<< $'1\n2\n3\nq'
    [ "$status" -eq 0 ]
    grep -q '^STATUS=off$' "$SSHPOCKET_CONF"
    grep -q '^STATUS_TIMEOUT=3$' "$SSHPOCKET_CONF"
}

@test "ayar: durum kontrolü süre ayarını nc'ye geçirir" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\necho "$@" > "%s/nc.args"\nexit 0\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/nc"
    chmod +x "$BATS_TEST_TMPDIR/bin/nc"
    d="$BATS_TEST_TMPDIR/s/x"; mkdir -p "$d"
    printf 'IP=192.0.2.1\nUSER=u\nPORT=22\n' > "$d/server.env"
    printf 'STATUS_TIMEOUT=4\n' > "$SSHPOCKET_CONF"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run ssh_module_status "X" "$d"
    [ "$output" = "🟢" ]
    grep -q -- '-w 4' "$BATS_TEST_TMPDIR/nc.args"
}

@test "ayar: menüde durum varsayılan AÇIK, ayarla kapatılabilir" {
    source "$H/RegisterModules.sh"; source "$H/Menu.sh"
    Fake_status() { printf '🟢'; }
    RegisterModules "FAKE" "MainMenu" "Fake"
    run Menu "MainMenu" <<< "0"
    [[ "$output" == *"🟢 FAKE"* ]]
    printf 'STATUS=off\n' > "$SSHPOCKET_CONF"
    run Menu "MainMenu" <<< "0"
    [[ "$output" != *"🟢"* ]]
}

@test "ayar: IFS değişmiş bağlamda da çalışır (menü içinden çağrı)" {
    printf 'STATUS=off\n' > "$SSHPOCKET_CONF"
    IFS=$'\n'
    [ "$(settings_get STATUS)" = "off" ]
    IFS='|'
    [ "$(settings_get STATUS_TIMEOUT)" = "1" ]
}
