#!/usr/bin/env bats
load test_helper
setup() {
    load_helpers
    export SSHPOCKET_MODULES_DIR="$BATS_TEST_TMPDIR/Modules"
    mkdir -p "$SSHPOCKET_MODULES_DIR"
    module_write_files "$SSHPOCKET_MODULES_DIR" "web1" "192.0.2.5" "deploy" "2222"
    printf 'KEY' > "$SSHPOCKET_MODULES_DIR/web1/id_ed25519_web1"
    printf 'PUB' > "$SSHPOCKET_MODULES_DIR/web1/id_ed25519_web1.pub"
    # Keychain'e dokunulmasın
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/security"
    chmod +x "$BATS_TEST_TMPDIR/bin/security"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    MM="$ROOT/sistem/ModuleManager.sh"
}

@test "list modülleri gösterir" {
    run bash "$MM" list
    [[ "$output" == *"web1"* ]]
    [[ "$output" == *"deploy@192.0.2.5:2222"* ]]
}
@test "remove: doğru adla onaylanırsa siler" {
    run bash "$MM" remove web1 <<< "web1"
    [ "$status" -eq 0 ]
    [ ! -e "$SSHPOCKET_MODULES_DIR/web1" ]
}
@test "remove: yanlış onayda silmez" {
    run bash "$MM" remove web1 <<< "hayir"
    [ "$status" -ne 0 ]
    [ -d "$SSHPOCKET_MODULES_DIR/web1" ]
}
@test "remove: path traversal reddedilir" {
    mkdir -p "$BATS_TEST_TMPDIR/hedef"
    run bash "$MM" remove "../hedef" <<< "../hedef"
    [ "$status" -ne 0 ]
    [ -d "$BATS_TEST_TMPDIR/hedef" ]
}
@test "rename: dosyaları, .env'i ve key'leri taşır" {
    run bash "$MM" rename web1 web2
    [ "$status" -eq 0 ]
    [ ! -e "$SSHPOCKET_MODULES_DIR/web1" ]
    [ -f "$SSHPOCKET_MODULES_DIR/web2/Web2Module.sh" ]
    [ -f "$SSHPOCKET_MODULES_DIR/web2/id_ed25519_web2" ]
    [ -f "$SSHPOCKET_MODULES_DIR/web2/id_ed25519_web2.pub" ]
    run _ssh_env_get "$SSHPOCKET_MODULES_DIR/web2/.env" WEB2_IP
    [ "$output" = "192.0.2.5" ]
}
@test "rename: hedef varsa veya ad geçersizse dokunmaz" {
    module_write_files "$SSHPOCKET_MODULES_DIR" "web2" "h" "u" "22"
    run bash "$MM" rename web1 web2;  [ "$status" -ne 0 ]
    run bash "$MM" rename web1 "Bad"; [ "$status" -ne 0 ]
    [ -d "$SSHPOCKET_MODULES_DIR/web1" ]
}
@test "bilinmeyen komut kullanım gösterir" {
    run bash "$MM" nope
    [ "$status" -ne 0 ]
    [[ "$output" == *"Kullanım"* ]]
}
