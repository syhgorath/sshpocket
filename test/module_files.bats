#!/usr/bin/env bats
load test_helper
setup() { load_helpers; MD="$BATS_TEST_TMPDIR/Modules"; mkdir -p "$MD"; }

@test "modül dosyaları üretilir" {
    run module_write_files "$MD" "web1" "192.0.2.5" "deploy" "2222"
    [ "$status" -eq 0 ]
    [ -f "$MD/web1/.env" ]
    [ -f "$MD/web1/.env.example" ]
    [ -x "$MD/web1/Web1Module.sh" ]
}
@test ".env içeriği ve izinleri (600)" {
    module_write_files "$MD" "web1" "192.0.2.5" "deploy" "2222"
    run _ssh_env_get "$MD/web1/.env" WEB1_IP;   [ "$output" = "192.0.2.5" ]
    run _ssh_env_get "$MD/web1/.env" WEB1_USER; [ "$output" = "deploy" ]
    run _ssh_env_get "$MD/web1/.env" WEB1_PORT; [ "$output" = "2222" ]
    # platformdan bağımsız: ls -l çıktısının ilk sütunu (macOS ve Linux'ta aynı biçim)
    perms=$(ls -l "$MD/web1/.env" | cut -c1-10)
    [ "$perms" = "-rw-------" ]
}
@test ".env.example gizli bilgi/gerçek değer içermez" {
    module_write_files "$MD" "web1" "192.0.2.5" "deploy" "2222"
    ! grep -q '192.0.2.5' "$MD/web1/.env.example"
    ! grep -q 'deploy' "$MD/web1/.env.example"
}
@test "özel key yolu .env'e yazılır" {
    module_write_files "$MD" "web1" "h" "u" "22" "/home/x/.ssh/id_ed25519"
    run _ssh_env_get "$MD/web1/.env" WEB1_KEY
    [ "$output" = "/home/x/.ssh/id_ed25519" ]
}
@test "üretilen modül geçerli bash ve doğru fonksiyonları tanımlar" {
    module_write_files "$MD" "web1" "h" "u" "22"
    run bash -n "$MD/web1/Web1Module.sh"; [ "$status" -eq 0 ]
    grep -q 'RegisterModules "WEB1" "MainMenu" "Web1Module"' "$MD/web1/Web1Module.sh"
    grep -q '^Web1Module_status()' "$MD/web1/Web1Module.sh"
}
@test "geçersiz girdilerde hiçbir şey yazılmaz" {
    run module_write_files "$MD" "Web1" "h" "u" "22";        [ "$status" -ne 0 ]
    run module_write_files "$MD" "web1" "h" "-oEvil" "22";   [ "$status" -ne 0 ]
    run module_write_files "$MD" "web1" "h" "u" "99999";     [ "$status" -ne 0 ]
    [ ! -e "$MD/web1" ]; [ ! -e "$MD/Web1" ]
}
@test "yardımcı fonksiyonlar" {
    run module_prefix "my_srv"; [ "$output" = "MY_SRV" ]
    run module_func_name "my_srv"; [ "$output" = "My_srvModule" ]
}
@test "ssh_module_status: ayar yoksa ⚪" {
    run ssh_module_status "WEB1" "$MD/yok"
    [ "$output" = "⚪" ]
}
