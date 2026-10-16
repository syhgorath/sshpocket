#!/usr/bin/env bats
# Aşama 3, PR E1: sunucu menüsünde "🛡️ Paketler" (sahte paket/çalıştırıcı; ağ yok)
load test_helper

setup() {
    load_helpers
    export SISTEM_PATH="$ROOT/sistem"
    for f in Servers Components ComponentsInstall ComponentsManifest ComponentsMenu; do source "$H/$f.sh"; done
    T="$BATS_TEST_TMPDIR"
    export SSHPOCKET_COMPONENTS_DIR="$T/comps"
    D="$T/srv/web1"; mkdir -p "$D"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$D/server.env"
    touch "$D/id_ed25519_web1"
    cat > "$T/m.json" <<'JSON'
{"id":"demo","version":"1.0.0","sshpocket_api":1,"runner":"ansible",
 "profiles":[{"id":"ubuntu-26.04","status":"supported"}],
 "actions":{
  "preview":{"cmd":"ansible-playbook a.yml --check","effects":[],"warnings":["Önizleme ufw değişikliğini göstermez."]},
  "apply":{"cmd":"ansible-playbook a.yml","effects":["changes-config"],"requires":["preview"],"confirm":"type-server-name"},
  "wipe":{"cmd":"ansible-playbook w.yml","effects":["destructive"]}}}
JSON
    INFO=$(comp_manifest_info "$T/m.json" demo 1.0.0)
    # paket katmanı sahte (kendi testleri var)
    comp_ids() { echo demo; }
    comp_installed_version() { [ "$1" = demo ] && printf '1.0.0'; }
    comp_prepare() { [ "$1" = demo ] && printf '%s\n' "$INFO"; }
    comp_cli_run() { echo "$*" >> "$T/runs"; return "${FAKE_RUN_RC:-0}"; }
    clear() { :; }
}

# ---------- erişilebilirlik ----------
@test "available: yeni biçimli sunucu + kurulu paket varsa evet; eski biçim ya da paket yoksa hayır" {
    run comp_menu_available "$D"; [ "$status" -eq 0 ]
    L="$T/legacy"; mkdir -p "$L"; printf 'WEB1_IP=1.1.1.1\n' > "$L/.env"
    run comp_menu_available "$L"; [ "$status" -ne 0 ]                     # eski biçim: servers/ dışı
    comp_installed_version() { return 0; }                                 # kurulu sürüm yok
    run comp_menu_available "$D"; [ "$status" -ne 0 ]
    comp_ids() { :; }
    run comp_menu_available "$D"; [ "$status" -ne 0 ]
}

# ---------- eylem listesi ----------
@test "eylemler: etki rozeti, ön koşul ve ilk uyarı gösterilir; geri hiçbir şey çalıştırmaz" {
    run comp_menu_actions demo web1 <<<"0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"preview — 🔍 salt okunur"* ]] || false
    [[ "$output" == *"apply — ✏️  değişiklik yapar  (önce: preview)"* ]] || false
    [[ "$output" == *"wipe — ☠️  yıkıcı"* ]] || false
    [ ! -e "$T/runs" ]
}

@test "eylemler: seçilen eylem doğru paket/eylem/sunucu ile çalıştırılır; sonra liste döner" {
    run comp_menu_actions demo web1 <<<$'1\n\n2\n\n0'
    [ "$status" -eq 0 ]
    [ "$(sed -n 1p "$T/runs")" = "demo preview web1" ]
    [ "$(sed -n 2p "$T/runs")" = "demo apply web1" ]
    [ "$(wc -l < "$T/runs" | tr -d ' ')" = "2" ]
}

@test "eylemler: geçersiz/aralık dışı giriş bir şey çalıştırmaz; q ve boş girdi geri döner" {
    for bad in 9 abc -1 "1;id"; do
        rm -f "$T/runs"
        run comp_menu_actions demo web1 <<<"$bad"
        [ "$status" -eq 0 ]
        [ ! -e "$T/runs" ] || { echo "ÇALIŞTI: $bad"; return 1; }
    done
    run comp_menu_actions demo web1 <<<"q";  [ ! -e "$T/runs" ]
    run comp_menu_actions demo web1 </dev/null; [ ! -e "$T/runs" ]
}

@test "eylemler: eylem başarısız olsa da menü döngüsü sürer (Enter sonrası listeye döner)" {
    FAKE_RUN_RC=2 run comp_menu_actions demo web1 <<<$'1\n\n0'
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$T/runs" | tr -d ' ')" = "1" ]
}

@test "eylemler: paket doğrulanamazsa (comp_prepare başarısız) çalıştırmadan çıkar" {
    comp_prepare() { return 1; }
    run comp_menu_actions demo web1 <<<"1"
    [ "$status" -ne 0 ]
    [ ! -e "$T/runs" ]
}

# ---------- paket seçimi ----------
@test "sunucu girişi: tek paket varsa doğrudan eylem listesine gider; kurulu paket yoksa bilgi verir" {
    run comp_menu_server WEB1 "$D" <<<"0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"preview — 🔍 salt okunur"* ]] || false
    comp_installed_version() { return 0; }
    run comp_menu_server WEB1 "$D" <<<"0"
    [[ "$output" == *"Kurulu paket yok"* ]] || false
}

@test "sunucu girişi: birden çok paketten seçim yapılır" {
    comp_ids() { printf 'demo\nother\n'; }
    comp_installed_version() { printf '1.0.0'; }
    comp_prepare() { printf '%s\n' "$INFO"; }
    run comp_menu_server WEB1 "$D" <<<$'1\n1\n\n0\n0'
    [ "$status" -eq 0 ]
    [[ "$output" == *"demo 1.0.0"* ]] || false
    [[ "$output" == *"other 1.0.0"* ]] || false
    [ "$(sed -n 1p "$T/runs")" = "demo preview web1" ]
}

# ---------- sunucu menüsü entegrasyonu ----------
@test "sunucu menüsü: paket varsa '6) Paketler' görünür ve 6 comp_menu_server'ı çağırır" {
    comp_menu_server() { echo "MENU:$1:$2" >> "$T/menucalls"; }
    run ssh_module_run WEB1 "$D" <<<$'6\n\n0'
    [[ "$output" == *"6) 🛡️  Paketler"* ]] || false
    [ "$(cat "$T/menucalls")" = "MENU:WEB1:$D" ]
}

@test "sunucu menüsü: paket yoksa 6) görünmez ve 6 girmek menüden çıkarır (hiçbir şey çalışmaz)" {
    comp_installed_version() { return 0; }
    comp_menu_server() { echo "MENU" >> "$T/menucalls"; }
    run ssh_module_run WEB1 "$D" <<<$'6\n0'
    [[ "$output" != *"Paketler (sertleştirme"* ]] || false
    [ ! -e "$T/menucalls" ]
}
