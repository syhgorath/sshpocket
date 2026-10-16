#!/usr/bin/env bats
# Aşama 3, PR E1: sunucu menüsünde "🛡️ Paketler" (sahte paket/çalıştırıcı; ağ yok)
load test_helper

setup() {
    load_helpers
    export SISTEM_PATH="$ROOT/sistem"
    for f in Servers Components ComponentsInstall ComponentsManifest ComponentsRun ComponentsVars ComponentsMenu; do source "$H/$f.sh"; done
    T="$BATS_TEST_TMPDIR"
    export SSHPOCKET_COMPONENTS_DIR="$T/comps" SSHPOCKET_SERVERS_DIR="$T/srv"
    D="$T/srv/web1"; mkdir -p "$D" "$T/comps/demo/1.0.0"
    printf 'IP=192.0.2.7\nUSER=deploy\nPORT=22\n' > "$D/server.env"
    touch "$D/id_ed25519_web1"
    cat > "$T/m.json" <<'JSON'
{"id":"demo","version":"1.0.0","sshpocket_api":1,"runner":"ansible",
 "profiles":[{"id":"ubuntu-26.04","status":"supported"}],
 "actions":{
  "preview":{"cmd":"ansible-playbook a.yml --check","effects":[],"warnings":["Önizleme ufw değişikliğini göstermez."]},
  "apply":{"cmd":"ansible-playbook a.yml","effects":["changes-config"],"requires":["preview"],"confirm":"type-server-name"},
  "wipe":{"cmd":"ansible-playbook w.yml","effects":["destructive"]},
  "audit":{"cmd":"ansible-playbook u.yml","effects":["installs-package"],"confirm":"yes-no","outputs":{"dir_var":"scan_dir"}}},
 "vars":[
  {"name":"allow_from","type":"list[cidr]","required":true,"description":"SSH'a izin verilen ağlar"},
  {"name":"scan_dir","type":"path","description":"Çıktı klasörü"},
  {"name":"rb_enabled","type":"bool","default":true,"warn_if":false,"description":"geri alma güvenlik ağı"},
  {"name":"rb_timeout","type":"int","default":300,"min":30,"max":3600,"description":"geri alma süresi"},
  {"name":"mode","type":"enum","values":["a","b"],"default":"a"}]}
JSON
    cp "$T/m.json" "$T/comps/demo/1.0.0/component.json"
    printf 'allow_from=10.99.0.0/24\n' > "$D/demo.vars"      # varsayılan: zorunlu değişken tamam (eylemler açık)
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
    run comp_menu_actions demo web1 <<<$'2\n\n3\n\n0'
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
    FAKE_RUN_RC=2 run comp_menu_actions demo web1 <<<$'2\n\n0'
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
    run comp_menu_server WEB1 "$D" <<<$'1\n2\n\n0\n0'
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

# =====================================================================
# E2b: hazırlık bloğu, değişken ekranı, CIDR editörü
# =====================================================================
vget() { comp_vars_get "$D/demo.vars" "$1"; }

setup_net() {
    comp_net_local() { echo "10.99.0.4/32"; }
    comp_net_seen_by_server() { return 1; }
}

# ---------- hazırlık ----------
@test "hazırlık: zorunlu değişken eksikse ❌ gösterilir, eylemler ⛔ kapalıdır ve çalıştırılmaz" {
    rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'2\n\n0'
    [ "$status" -eq 0 ]
    [[ "$output" == *"❌ allow_from"* ]] || false
    [[ "$output" == *"preview — 🔍 salt okunur  ⛔"* ]] || false
    [[ "$output" == *"Önce zorunlu değişkenleri tamamlayın"* ]] || false
    [ ! -e "$T/runs" ]
}

@test "hazırlık: zorunlu değişkenler tamamsa ✅ gösterilir ve eylem çalışır" {
    run comp_menu_actions demo web1 <<<$'2\n\n0'
    [[ "$output" == *"✅ Zorunlu değişkenler tamam"* ]] || false
    [ "$(cat "$T/runs")" = "demo preview web1" ]
}

# ---------- değişken ekranı ----------
@test "değişkenler: değer, varsayılan ve otomatik (zorlanan) değişkenler doğru etiketlenir" {
    run comp_menu_actions demo web1 <<<$'1\n0\n0'
    [ "$status" -eq 0 ]
    [[ "$output" == *"allow_from = 10.99.0.0/24"* ]] || false
    [[ "$output" == *"scan_dir — otomatik"* ]] || false
    [[ "$output" == *"rb_enabled = (varsayılan: true)"* ]] || false
    [[ "$output" == *"rb_timeout = (varsayılan: 300)"* ]] || false
    [[ "$output" == *"mode = (varsayılan: a)"* ]] || false
}

@test "değişkenler: geçerli değer kaydedilir; geçersiz (aralık) kaydedilmez ve neden gösterilir" {
    run comp_menu_actions demo web1 <<<$'1\n4\n600\n\n0\n0'
    [ "$(vget rb_timeout)" = "600" ]
    run comp_menu_actions demo web1 <<<$'1\n4\n5\n\n0\n0'
    [[ "$output" == *"en az 30"* ]] || false
    [ "$(vget rb_timeout)" = "600" ]                      # eski değer korunur
}

@test "değişkenler: '-' siler (varsayılana döner); boş Enter değiştirmez" {
    comp_vars_set "$D/demo.vars" rb_timeout 600
    run comp_menu_actions demo web1 <<<$'1\n4\n\n0\n0'
    [ "$(vget rb_timeout)" = "600" ]
    run comp_menu_actions demo web1 <<<$'1\n4\n-\n\n0\n0'
    run vget rb_timeout
    [ "$status" -ne 0 ]
}

@test "değişkenler: warn_if değeri onay ister (H = yazmaz, e = yazar)" {
    run comp_menu_actions demo web1 <<<$'1\n3\nfalse\nh\n0\n0'
    [[ "$output" == *"riskli"* ]] || false
    run vget rb_enabled; [ "$status" -ne 0 ]
    run comp_menu_actions demo web1 <<<$'1\n3\nfalse\ne\n\n0\n0'
    [ "$(vget rb_enabled)" = "false" ]
}

@test "değişkenler: otomatik (dir_var) değişken seçilince açıklama gösterilir, hiçbir şey yazılmaz" {
    run comp_menu_actions demo web1 <<<$'1\n2\n\n0\n0'
    [[ "$output" == *"çalıştırıcı tarafından belirlenir"* ]] || false
    run vget scan_dir; [ "$status" -ne 0 ]
}

@test "değişkenler: girdi yarıda biterse (EOF) takılmaz ve dosyaya yazılmaz" {
    run comp_menu_actions demo web1 <<<$'1\n4\n'
    [ "$status" -eq 0 ]
    run vget rb_timeout; [ "$status" -ne 0 ]
}

# ---------- CIDR editörü ----------
@test "cidr: öneri eklenir; listede tek ağ varsa uyarı çıkar ve 'H' ile o haliyle kaydedilir" {
    setup_net; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\n1\nk\nh\n\n0\n0'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bu bilgisayarın sunucuya bağlandığı adres: 10.99.0.4/32"* ]] || false
    [[ "$output" == *"tahmini /24"* ]] || false
    [[ "$output" == *"yalnızca bir ağ var"* ]] || false
    [ "$(vget allow_from)" = "10.99.0.0/24" ]
}

@test "cidr: iki ağ eklenince tek-ağ uyarısı çıkmaz; liste virgülle kaydedilir" {
    setup_net; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\n1\ne\n192.168.1.0/24\nk\n\n0\n0'
    [[ "$output" != *"yalnızca bir ağ var"* ]] || false
    [ "$(vget allow_from)" = "10.99.0.0/24,192.168.1.0/24" ]
}

@test "cidr: tek ağda 'e' denirse kaydedilmez, düzenlemeye devam edilir (ikinci ağ eklenip kaydedilir)" {
    setup_net; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\n1\nk\ne\ne\n192.168.1.0/24\nk\n\n0\n0'
    [ "$(vget allow_from)" = "10.99.0.0/24,192.168.1.0/24" ]
}

@test "cidr: geçersiz elle girilen CIDR eklenmez; iptal (0) dosyayı değiştirmez" {
    setup_net; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\ne\n10.0.0.0/99\n0\n0\n0'
    [[ "$output" == *"⚠️"* ]] || false
    run vget allow_from; [ "$status" -ne 0 ]
    [ ! -e "$D/demo.vars" ] || ! grep -q allow_from "$D/demo.vars"
}

@test "cidr: sil (d), temizle (t); boş liste kaydedilemez" {
    setup_net
    comp_vars_set "$D/demo.vars" allow_from "10.0.0.0/24,172.16.0.0/16"
    run comp_menu_actions demo web1 <<<$'1\n1\nd\n1\nk\nh\n\n0\n0'
    [ "$(vget allow_from)" = "172.16.0.0/16" ]
    comp_vars_set "$D/demo.vars" allow_from "10.0.0.0/24,172.16.0.0/16"
    run comp_menu_actions demo web1 <<<$'1\n1\nt\nk\n0\n0\n0'
    [[ "$output" == *"Liste boş olamaz"* ]] || false
    [ "$(vget allow_from)" = "10.0.0.0/24,172.16.0.0/16" ]
}

@test "cidr: aynı öneri iki kez eklenmez" {
    setup_net; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\n1\n1\ne\n192.168.1.0/24\nk\n\n0\n0'
    [[ "$output" == *"Zaten listede"* ]] || false
    [ "$(vget allow_from)" = "10.99.0.0/24,192.168.1.0/24" ]
}

@test "cidr: 'v' sunucunun gördüğü adresi sorgular ve önerileri günceller; sorgu başarısızsa uyarır" {
    setup_net; rm -f "$D/demo.vars"
    comp_net_seen_by_server() { echo "10.50.0.9"; }
    run comp_menu_actions demo web1 <<<$'1\n1\nv\n1\ne\n192.168.1.0/24\nk\n\n0\n0'
    [[ "$output" == *"Sunucu seni şu adresten görüyor: 10.50.0.9"* ]] || false
    [ "$(vget allow_from)" = "10.50.0.0/24,192.168.1.0/24" ]
    rm -f "$D/demo.vars"; comp_net_seen_by_server() { return 1; }
    run comp_menu_actions demo web1 <<<$'1\n1\nv\n0\n0\n0'
    [[ "$output" == *"Sunucudan sorgulanamadı"* ]] || false
}

@test "cidr: yerel adres belirlenemezse öneri yok ama elle ekleme çalışır" {
    comp_net_local() { return 1; }; rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n1\ne\n192.168.1.0/24\nk\nh\n\n0\n0'
    [[ "$output" == *"adresi belirlenemedi"* ]] || false
    [ "$(vget allow_from)" = "192.168.1.0/24" ]
}

@test "cidr: Main.sh ortamındaki IFS (satır sonu/sekme) liste birleştirmeyi ve üyelik kontrolünü bozmaz" {
    setup_net; rm -f "$D/demo.vars"
    IFS=$'\n\t'
    run comp_menu_actions demo web1 <<<$'1\n1\n1\n1\ne\n192.168.1.0/24\nk\n\n0\n0'
    [ "$(vget allow_from)" = "10.99.0.0/24,192.168.1.0/24" ]
    [ "$(grep -c '^allow_from=' "$D/demo.vars")" = "1" ]
}
