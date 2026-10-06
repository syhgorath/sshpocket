#!/usr/bin/env bats
load test_helper
setup() {
    make_sandbox
    # diskutil/ssh/ssh-copy-id sahte: gerçek bir şeye dokunulmaz
    printf '#!/bin/bash\nexit 1\n' > "$SANDBOX/bin/diskutil"
    printf '#!/bin/bash\n[ "${STUB_AUTHORIZED:-0}" = 1 ] && exit 0\nexit 255\n' > "$SANDBOX/bin/ssh"
    printf '#!/bin/bash\necho "[ssh-copy-id] $*"\n' > "$SANDBOX/bin/ssh-copy-id"
    chmod +x "$SANDBOX/bin/"*
    export PATH="$SANDBOX/bin:$PATH" TERM=xterm
    MOD="$SANDBOX/sistem/Modules/example"
    printf 'EXAMPLE_IP=192.0.2.10\nEXAMPLE_USER=pi\nEXAMPLE_PORT=2222\n' > "$MOD/.env"
    ssh-keygen -q -t ed25519 -N "" -f "$MOD/id_ed25519_example"
}
strip() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }

@test "ana menü örnek modülü listeler ve 0 ile çıkar" {
    run bash -c "printf '0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g'"
    [[ "$output" == *"1) EXAMPLE"* ]]
    [[ "$output" == *"Exiting"* ]]
}
@test "geçersiz kullanıcı .env'de reddedilir" {
    printf 'EXAMPLE_IP=192.0.2.10\nEXAMPLE_USER=pi;id\nEXAMPLE_PORT=22\n' > "$MOD/.env"
    run bash -c "printf '1\n\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"geçersiz kullanıcı"* ]]
}
@test "key eksikse net hata" {
    rm "$MOD/id_ed25519_example"
    run bash -c "printf '1\n\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"SSH key bulunamadı"* ]]
}
@test "özel EXAMPLE_KEY yolu kullanılır" {
    mv "$MOD/id_ed25519_example" "$BATS_TEST_TMPDIR/ozel_key"
    printf 'EXAMPLE_KEY=%s\n' "$BATS_TEST_TMPDIR/ozel_key" >> "$MOD/.env"
    run bash -c "printf '1\n2\nn\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" != *"SSH key bulunamadı"* ]]
    [[ "$output" == *"Hedef:       pi@192.0.2.10:2222"* ]]
    [[ "$output" == *"ozel_key"* ]]
}
@test "key gönderme: yeni key ssh-copy-id'ye gider" {
    run bash -c "printf '1\n2\ny\n\n\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"[ssh-copy-id] -i"*"id_ed25519_example.pub -p 2222 pi@192.0.2.10"* ]]
    [[ "$output" == *"ELLE yapın"* ]]
}
@test "key gönderme: zaten yetkiliyse ssh-copy-id çağrılmaz" {
    STUB_AUTHORIZED=1 run bash -c "printf '1\n2\ny\n\n0\n' | STUB_AUTHORIZED=1 bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"zaten yetkili"* ]]
    [[ "$output" != *"[ssh-copy-id]"* ]]
}
@test "key gönderme: iptal edilirse ssh-copy-id çağrılmaz" {
    run bash -c "printf '1\n2\nn\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" != *"[ssh-copy-id]"* ]]
}
@test "key gönderme: olmayan giriş key'i dosyası reddedilir" {
    run bash -c "printf '1\n2\ny\n/yok/key\n0\n' | bash '$SANDBOX/sistem/Main.sh' 2>&1"
    [[ "$output" == *"Dosya yok"* ]]
    [[ "$output" != *"[ssh-copy-id]"* ]]
}
