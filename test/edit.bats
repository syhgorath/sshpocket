#!/usr/bin/env bats
load test_helper
setup() {
    load_helpers
    MD="$BATS_TEST_TMPDIR/web1"
    mkdir -p "$MD" "$BATS_TEST_TMPDIR/bin"
    ENVF="$MD/.env"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    LOG="$BATS_TEST_TMPDIR/security.log"
    # Sahte 'security': çağrıları kaydeder; STUB_SEC_EXISTS=1 ise kayıt "var" sayılır
    cat > "$BATS_TEST_TMPDIR/bin/security" <<STUB
#!/bin/bash
echo "\$*" >> "$LOG"
if [ "\$1" = "find-generic-password" ]; then [ "\${STUB_SEC_EXISTS:-0}" = 1 ]; exit \$?; fi
exit 0
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/security"
    # Sahte 'ssh-add': durumu dosyada tutan mini agent
    cat > "$BATS_TEST_TMPDIR/bin/ssh-add" <<STUB
#!/bin/bash
S="$BATS_TEST_TMPDIR/agent"
case "\$1" in
  -l) cat "\$S" 2>/dev/null; [ -s "\$S" ]; exit \$? ;;
  -d) rm -f "\$S"; exit 0 ;;
  *)  [ "\${STUB_ADD_FAIL:-0}" = 1 ] && exit 1; ssh-keygen -lf "\$1" > "\$S"; exit 0 ;;
esac
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/ssh-add"
}

# ---------- _ssh_env_set ----------
@test "env_set: mevcut değeri değiştirir, yorum ve diğer satırlar korunur" {
    printf '# başlık\nWEB1_IP=1.1.1.1\nWEB1_USER=pi\n# not\n' > "$ENVF"
    _ssh_env_set "$ENVF" WEB1_IP 2.2.2.2
    run cat "$ENVF"
    [ "${lines[0]}" = "# başlık" ]
    [ "${lines[1]}" = "WEB1_IP=2.2.2.2" ]
    [ "${lines[2]}" = "WEB1_USER=pi" ]
    [ "${lines[3]}" = "# not" ]
}
@test "env_set: yoksa sona ekler" {
    printf 'WEB1_IP=1.1.1.1\n' > "$ENVF"
    _ssh_env_set "$ENVF" WEB1_PORT 2200
    run _ssh_env_get "$ENVF" WEB1_PORT
    [ "$output" = "2200" ]
}
@test "env_set: yorum satırındaki anahtar değiştirilmez" {
    printf '# WEB1_IP=eski\nWEB1_IP=1.1.1.1\n' > "$ENVF"
    _ssh_env_set "$ENVF" WEB1_IP 9.9.9.9
    run cat "$ENVF"
    [ "${lines[0]}" = "# WEB1_IP=eski" ]
    [ "${lines[1]}" = "WEB1_IP=9.9.9.9" ]
}
@test "env_set: özel karakterler olduğu gibi yazılır (kabuk yorumlamaz)" {
    : > "$ENVF"
    _ssh_env_set "$ENVF" WEB1_KEY '/x/$HOME/a&b"c'"'"'d\e'
    grep -qxF 'WEB1_KEY=/x/$HOME/a&b"c'"'"'d\e' "$ENVF"
}
@test "env_set: dosya yoksa oluşturur ve izin 600 olur" {
    _ssh_env_set "$ENVF" WEB1_IP 1.2.3.4
    [ "$(ls -l "$ENVF" | cut -c1-10)" = "-rw-------" ]
    run _ssh_env_get "$ENVF" WEB1_IP
    [ "$output" = "1.2.3.4" ]
}

# ---------- ssh_module_edit ----------
@test "edit: Enter hepsini değiştirmez" {
    printf 'WEB1_IP=1.1.1.1\nWEB1_USER=pi\nWEB1_PORT=2200\n' > "$ENVF"
    run ssh_module_edit WEB1 "$MD" <<< $'\n\n\n\n'
    [ "$status" -eq 0 ]
    run _ssh_env_get "$ENVF" WEB1_IP;   [ "$output" = "1.1.1.1" ]
    run _ssh_env_get "$ENVF" WEB1_USER; [ "$output" = "pi" ]
    run _ssh_env_get "$ENVF" WEB1_PORT; [ "$output" = "2200" ]
}
@test "edit: yeni değerler kaydedilir" {
    printf 'WEB1_IP=1.1.1.1\nWEB1_USER=pi\nWEB1_PORT=22\n' > "$ENVF"
    run ssh_module_edit WEB1 "$MD" <<< $'10.0.0.9\nroot\n2222\n/yol/anahtar'
    [ "$status" -eq 0 ]
    run _ssh_env_get "$ENVF" WEB1_IP;   [ "$output" = "10.0.0.9" ]
    run _ssh_env_get "$ENVF" WEB1_USER; [ "$output" = "root" ]
    run _ssh_env_get "$ENVF" WEB1_PORT; [ "$output" = "2222" ]
    run _ssh_env_get "$ENVF" WEB1_KEY;  [ "$output" = "/yol/anahtar" ]
}
@test "edit: '-' key yolunu varsayılana döndürür" {
    printf 'WEB1_IP=1.1.1.1\nWEB1_USER=pi\nWEB1_PORT=22\nWEB1_KEY=/eski\n' > "$ENVF"
    run ssh_module_edit WEB1 "$MD" <<< $'\n\n\n-'
    run _ssh_env_get "$ENVF" WEB1_KEY
    [ -z "$output" ]
}
@test "edit: geçersiz değer kaydedilmez, dosya aynı kalır" {
    printf 'WEB1_IP=1.1.1.1\nWEB1_USER=pi\nWEB1_PORT=22\n' > "$ENVF"
    cp "$ENVF" "$BATS_TEST_TMPDIR/oncesi"
    run ssh_module_edit WEB1 "$MD" <<< $'\n-oProxyCommand=x\n\n'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Kaydedilmedi"* ]]
    cmp "$ENVF" "$BATS_TEST_TMPDIR/oncesi"
}
@test "edit: .env yoksa oluşturur" {
    run ssh_module_edit WEB1 "$MD" <<< $'192.0.2.5\ndeploy\n\n'
    [ "$status" -eq 0 ]
    run _ssh_env_get "$ENVF" WEB1_USER
    [ "$output" = "deploy" ]
    run _ssh_env_get "$ENVF" WEB1_PORT
    [ "$output" = "22" ]
}

# ---------- ssh_keychain_manage ----------
@test "keychain: kaydet -> add-generic-password -U, passphrase komut satırında yok" {
    run ssh_keychain_manage WEB1 "$MD/yok_key" <<< "1"
    [[ "$output" == *"Keychain'e kaydedildi"* ]]
    grep -qxF 'add-generic-password -U -a USBMonitor_WEB1_Passphrase -s USBMonitor -w' "$LOG"
}
@test "keychain: sil -> delete-generic-password" {
    run ssh_keychain_manage WEB1 "$MD/yok_key" <<< "2"
    grep -q 'delete-generic-password -a USBMonitor_WEB1_Passphrase -s USBMonitor' "$LOG"
}
@test "keychain: 0 hiçbir şey yazmaz/silmez" {
    run ssh_keychain_manage WEB1 "$MD/yok_key" <<< "0"
    ! grep -qE 'add-generic|delete-generic' "$LOG"
}
@test "keychain: durum 'var/yok' gösterilir" {
    STUB_SEC_EXISTS=1 run ssh_keychain_manage WEB1 "$MD/k" <<< "0"
    [[ "$output" == *"✅ var"* ]]
    STUB_SEC_EXISTS=0 run ssh_keychain_manage WEB1 "$MD/k" <<< "0"
    [[ "$output" == *"❌ yok"* ]]
}
@test "keychain: kayıttan sonra key agent'a eklenirse doğrulanır" {
    ssh-keygen -q -t ed25519 -N "" -f "$MD/k"
    SSH_ASKPASS_REQUIRE=force run ssh_keychain_manage WEB1 "$MD/k" <<< "1"
    [[ "$output" == *"passphrase doğru"* ]]
}
@test "keychain: agent'a eklenemezse uyarır" {
    ssh-keygen -q -t ed25519 -N "" -f "$MD/k"
    STUB_ADD_FAIL=1 run ssh_keychain_manage WEB1 "$MD/k" <<< "1"
    [[ "$output" == *"yanlış olabilir"* ]]
}
