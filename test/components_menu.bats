#!/usr/bin/env bats
# Aşama 3, PR E1: sunucu menüsünde "🛡️ Paketler" (sahte paket/çalıştırıcı; ağ yok)
load test_helper

setup() {
    load_helpers
    export SISTEM_PATH="$ROOT/sistem"
    for f in Servers Components ComponentsInstall ComponentsManifest ComponentsRun ComponentsGates ComponentsVars ComponentsMenu; do source "$H/$f.sh"; done
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

# ---------- denetim puanı satırı ----------
@test "başlık: pakete ait denetim özeti varsa 'Hazırlık' bölümünde puan ve fark gösterilir; yoksa satır çıkmaz" {
    export SSHPOCKET_STATE_DIR="$T/state"
    run comp_menu_actions demo web1 <<<"0"
    [[ "$output" != *"📊"* ]] || false
    mkdir -p "$T/state/demo/web1/out/web1/a" "$T/state/demo/web1/out/web1/b"
    printf '{"date":"2026-01-01T00:00:00Z","hardening_index":61}' > "$T/state/demo/web1/out/web1/a/summary.json"
    printf '{"date":"2026-01-02T00:00:00Z","hardening_index":83}' > "$T/state/demo/web1/out/web1/b/summary.json"
    run comp_menu_actions demo web1 <<<"0"
    [[ "$output" == *"📊 Lynis: 83 ("*") · önceki 61 (+22)"* ]] || false
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

@test "hazırlık: zorunlu değişken eksikken SALT OKUNUR durum eylemi (status) AÇIK ve çalışır; preview/apply/audit ⛔" {
    # yalnızca bu test için pakete ön koşul olmayan, salt okunur bir 'status' eylemi eklenir (ortak fikstür değişmez)
    python3 - "$T/m.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["actions"]["status"]={"cmd":"ansible-playbook s.yml","effects":[]}
json.dump(d,open(p,"w"),ensure_ascii=False)
PY
    INFO=$(comp_manifest_info "$T/m.json" demo 1.0.0)
    rm -f "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"status — 🔍 salt okunur"* ]] || false
    [[ "$output" != *"status — 🔍 salt okunur  ⛔"* ]] || false
    [[ "$output" == *"preview — 🔍 salt okunur  ⛔"* ]] || false
    [[ "$output" == *"apply — "*"⛔"* ]] || false
    [[ "$output" == *"audit — "*"⛔"* ]] || false
    [[ "$output" == *"Salt okunur durum eylemleri açıktır"* ]] || false
    # eylem sırası: preview=2 apply=3 wipe=4 audit=5 status=6 (bildirim sırası); status seçilince çalışır, kapı çıkmaz
    run comp_menu_actions demo web1 <<<$'6\n\n0'
    [ "$status" -eq 0 ]
    [ "$(cat "$T/runs")" = "demo status web1" ]
    [[ "$output" != *"Önce zorunlu değişkenleri tamamlayın"* ]] || false
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

@test "değişkenler: platforma uymayan değişkenler gizlenir, gruplar etiketle gösterilir, gizlenen sayısı yazılır" {
    python3 - "$T/comps/demo/1.0.0/component.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["platform_var"]="plat"
d["vars"]=[{"name":"allow_from","type":"list[cidr]","required":True},
           {"name":"plat","type":"enum","values":["generic","proxmox-host"],"default":"generic"},
           {"name":"genel_a","type":"bool","default":True},
           {"name":"pve_x","type":"bool","default":False,"platforms":["proxmox-host"],"group":"Proxmox"},
           {"name":"ag_z","type":"bool","default":False,"group":"Ağ"}]
json.dump(d,open(p,"w"))
PY
    run comp_menu_actions demo web1 <<<$'1\n0\n0'
    [[ "$output" == *"genel_a"* && "$output" == *"[Ağ] ag_z"* ]] || false
    [[ "$output" != *"pve_x"* ]] || false
    [[ "$output" == *"1 değişken bu sunucunun platformuna uygun olmadığı için gizlendi"* ]] || false
    printf 'allow_from=10.99.0.0/24\nplat=proxmox-host\n' > "$D/demo.vars"
    run comp_menu_actions demo web1 <<<$'1\n0\n0'
    [[ "$output" == *"[Proxmox] pve_x"* ]] || false
    [[ "$output" != *"gizlendi"* ]] || false
}

@test "eylemler: platforma uymayan eylemler menüde gizlenir, sayısı yazılır; platform uyunca görünür" {
    python3 - "$T/comps/demo/1.0.0/component.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["platform_var"]="plat"
d["vars"]=[{"name":"allow_from","type":"list[cidr]","required":True},
           {"name":"plat","type":"enum","values":["generic","proxmox-host"],"default":"generic"},
           {"name":"scan_dir","type":"path"}]
d["actions"]["pve_check"]={"cmd":"ansible-playbook p.yml --check","effects":[],"platforms":["proxmox-host"]}
json.dump(d,open(p,"w"))
PY
    INFO=$(comp_manifest_info "$T/comps/demo/1.0.0/component.json" demo 1.0.0)
    run comp_menu_actions demo web1 <<<"0"
    [[ "$output" != *"pve_check"* ]] || false
    [[ "$output" == *"1 eylem bu sunucunun platformuna uygun olmadığı için gizlendi"* ]] || false
    printf 'allow_from=10.99.0.0/24\nplat=proxmox-host\n' > "$D/demo.vars"
    run comp_menu_actions demo web1 <<<"0"
    [[ "$output" == *"pve_check"* ]] || false
    [[ "$output" != *"gizlendi"* ]] || false
}

# ---------- değişkenler ekranı: arama, grup, değiştirdiklerim, kısaltma ----------
@test "süzgeç: küçük pakette arama satırları çıkmaz; eşik aşılınca çıkar ve numaralandırma 'ara' satırlarından sonra başlar" {
    run comp_menu_actions demo web1 <<<$'1\n0\n0'
    [[ "$output" != *"🔎 Ara"* ]] || false
    export COMP_MENU_VARS_FILTER_MIN=2
    run comp_menu_actions demo web1 <<<$'1\n0\n0'
    [[ "$output" == *"🔎 Ara: (yok)"* && "$output" == *"Yalnızca değiştirdiklerim: kapalı (1)"* && "$output" == *"Gösterilen: 5 / 5"* ]] || false
    [[ "$output" != *"Grup:"* ]] || false      # pakette grup yoksa grup satırı çıkmaz
    # ilk değişken (allow_from) artık 3. satır: 1=ara 2=değiştirdiklerim
    run comp_menu_actions demo web1 <<<$'1\n4\n\n0\n0'
    [[ "$output" == *"rb_enabled"* ]] || false
}

@test "süzgeç: arama ad/açıklamada büyük-küçük harfsiz çalışır; temizle satırı çıkar ve süzgeci kaldırır" {
    export COMP_MENU_VARS_FILTER_MIN=2
    run comp_menu_actions demo web1 <<<$'1\n1\nTIMEOUT\n0\n0'
    [[ "$output" == *"🔎 Ara: TIMEOUT"* && "$output" == *"Gösterilen: 1 / 5"* && "$output" == *"↩ Süzgeci temizle"* ]] || false
    run comp_menu_actions demo web1 <<<$'1\n1\nyokböyle\n0\n0'
    [[ "$output" == *"Süzgece uyan değişken yok."* ]] || false
    # arama + temizle (son satır): yeniden 5 / 5
    run comp_menu_actions demo web1 <<<$'1\n1\ntimeout\n4\n0\n0'
    [[ "$output" == *"Gösterilen: 5 / 5"* ]] || false
}

@test "süzgeç: 'yalnızca değiştirdiklerim' dosyada değeri yazılı olanları gösterir (✏️ işaretli)" {
    export COMP_MENU_VARS_FILTER_MIN=2
    run comp_menu_actions demo web1 <<<$'1\n2\n0\n0'
    [[ "$output" == *"Yalnızca değiştirdiklerim: açık (1)"* && "$output" == *"Gösterilen: 1 / 5"* && "$output" == *"✏️  allow_from = 10.99.0.0/24"* ]] || false
}

@test "süzgeç: grup seçimi yalnızca o grubu gösterir; '(grupsuz)' grupsuzları gösterir" {
    python3 - "$T/comps/demo/1.0.0/component.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
for v in d["vars"]:
    v["group"]="Ağ" if v["name"]=="allow_from" else ("Zaman" if v["name"].startswith("rb_") else None)
    if v["group"] is None: del v["group"]
json.dump(d,open(p,"w"))
PY
    INFO=$(comp_manifest_info "$T/comps/demo/1.0.0/component.json" demo 1.0.0)
    export COMP_MENU_VARS_FILTER_MIN=2
    run comp_menu_actions demo web1 <<<$'1\n2\n2\n0\n0'
    [[ "$output" == *"📂 Grup: Ağ"* && "$output" == *"Gösterilen: 1 / 5"* ]] || false
    run comp_menu_actions demo web1 <<<$'1\n2\n4\n0\n0'
    [[ "$output" == *"📂 Grup: (grupsuz)"* && "$output" == *"Gösterilen: 2 / 5"* ]] || false
}

@test "süzgeç: süzülmüş listeden seçilen satır doğru değişkeni düzenler" {
    export COMP_MENU_VARS_FILTER_MIN=2
    run comp_menu_actions demo web1 <<<$'1\n1\ntimeout\n4\n600\n\n0\n0'
    [ "$(vget rb_timeout)" = "600" ]
}

@test "kısaltma: uzun değerler 40 karaktere kısaltılır; kısa değerler değişmez" {
    run _comp_menu_clip "kısa"
    [ "$output" = "kısa" ]
    long=$(python3 -c "print('a'*60)")
    run _comp_menu_clip "$long"
    [ "$(python3 -c 'import sys; print(len(sys.argv[1]))' "$output")" = 40 ]
    [[ "$output" == *"…" ]] || false
    run _comp_menu_clip "$long" 10
    [ "$(python3 -c 'import sys; print(len(sys.argv[1]))' "$output")" = 10 ]
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

# =====================================================================
# E3: Geçmiş, ön koşul tazeliği ve son sonuç (F)
# =====================================================================
setup_state() {
    export SSHPOCKET_STATE_DIR="$T/state" COMP_REQUIRES_TTL=1800
    source "$H/ComponentsGates.sh"; source "$H/ComponentsExec.sh"
}
# actions listesi: 1 Değişkenler, 2 preview, 3 apply, 4 wipe, 5 audit, 6 Geçmiş (son)

@test "gates: requires_age en son başarılı kaydın yaşını verir; fail/başka sürüm/gelecek/kayıt yok sayılmaz" {
    setup_state
    run comp_gate_requires_age demo web1 1.0.0 preview; [ "$status" -ne 0 ]
    now=$(date +%s); mkdir -p "$T/state/demo/web1"
    printf '%s|1.0.0|preview|ok\n%s|1.0.0|preview|ok\n%s|1.0.0|preview|fail\n%s|0.9.0|preview|ok\n%s|1.0.0|preview|ok\n' \
        $((now - 600)) $((now - 120)) $((now - 10)) $((now - 5)) $((now + 3600)) > "$T/state/demo/web1/results"
    run comp_gate_requires_age demo web1 1.0.0 preview
    [ "$status" -eq 0 ]
    [ "$output" -ge 119 ]          # ayrı satırlar: bash'te "a && b" zincirinde ilk koşulun başarısızlığı testi düşürmez
    [ "$output" -le 125 ]
    run comp_gate_requires_age demo web1 1.0.0 apply; [ "$status" -ne 0 ]
    run comp_gate_requires_age demo "../x" 1.0.0 preview; [ "$status" -ne 0 ]
}

@test "eylem etiketi: önkoşul kaydı yoksa '(önce: preview)'; taze ise ✅ yaş; süresi dolmuşsa ⏳" {
    setup_state
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"apply — ✏️  değişiklik yapar  (önce: preview)"* ]] || false
    comp_gate_record demo web1 1.0.0 preview ok
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"(önce: preview ✅ "* ]] || false
    printf '%s|1.0.0|preview|ok\n' $(( $(date +%s) - 3000 )) > "$T/state/demo/web1/results"
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"(önce: preview ⏳ süresi doldu)"* ]] || false
}

@test "geçmiş: son çalıştırmalar (yalnızca bu paket), ön koşul tazeliği ve günlük yolu gösterilir" {
    setup_state
    printf '2026-10-16T14:17:49Z|demo|1.0.0|preview|ok\n2026-10-16T14:20:00Z|baska|1.0.0|yabanciaction|ok\n2026-10-16T14:38:32Z|demo|1.0.0|apply|fail\n' > "$D/components.log"
    comp_gate_record demo web1 1.0.0 preview ok
    mkdir -p "$T/state/demo/web1"; echo "ansible cikti" > "$T/state/demo/web1/last-run.log"
    run comp_menu_actions demo web1 <<<$'6\nh\n\n0'
    [ "$status" -eq 0 ]
    [[ "$output" == *"2026-10-16T14:17:49Z  preview"* ]] || false
    [[ "$output" == *"2026-10-16T14:38:32Z  apply"* ]] || false
    [[ "$output" == *"❌ başarısız"* ]] || false
    [[ "$output" != *"yabanciaction"* ]] || false          # başka paketin kaydı görünmez
    [[ "$output" == *"apply için preview: ✅ taze"* ]] || false
    [[ "$output" == *"last-run.log"* ]] || false
}

@test "geçmiş: kayıt yoksa nazik mesajlar; günlüğün son satırları istenirse gösterilir ve denetim karakterleri temizlenir" {
    setup_state
    run comp_menu_actions demo web1 <<<$'6\n\n0'
    [[ "$output" == *"(kayıt yok)"* ]] || false
    [[ "$output" == *"apply için preview: ❌ başarılı kayıt yok"* ]] || false
    mkdir -p "$T/state/demo/web1"; printf 'satir1\n\033[31mkirmizi\033[0m\n' > "$T/state/demo/web1/last-run.log"
    run comp_menu_actions demo web1 <<<$'6\ne\n\n0'
    [[ "$output" == *"satir1"* ]] || false
    [[ "$output" == *"[31mkirmizi"* ]] || false
    [[ "$output" != *$'\033'* ]] || false
}

@test "geçmiş: süresi dolmuş preview açıkça belirtilir" {
    setup_state
    mkdir -p "$T/state/demo/web1"
    printf '%s|1.0.0|preview|ok\n' $(( $(date +%s) - 4000 )) > "$T/state/demo/web1/results"
    run comp_menu_actions demo web1 <<<$'6\nh\n\n0'
    [[ "$output" == *"apply için preview: ⏳ süresi doldu"* ]] || false
}

# ---------- F: son bilinen durum ----------
@test "exec: durum eyleminin sonucu saklanır (epoch + anahtar=değer, izin 600) ve okunur" {
    setup_state
    mkdir -p "$T/state/demo/web1"
    COMP_EXEC_RESULT=$'armed=yes\ntimer=active\nremaining_seconds=42'
    comp_exec_save_result "$T/state/demo/web1" status
    [ "$(stat -c %a "$T/state/demo/web1/result.status" 2>/dev/null || stat -f %Lp "$T/state/demo/web1/result.status")" = "600" ]
    run comp_exec_last_result demo web1 status
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" =~ ^[0-9]+$ ]]
    [ "${lines[1]}" = "armed=yes" ]
    [ "${lines[3]}" = "remaining_seconds=42" ]
    run comp_exec_last_result demo web1 yok;   [ "$status" -ne 0 ]
    run comp_exec_last_result demo web1 "a/b"; [ "$status" -ne 0 ]
    COMP_EXEC_RESULT=""; comp_exec_save_result "$T/state/demo/web1" other
    [ ! -e "$T/state/demo/web1/result.other" ]
    run comp_exec_save_result "$T/state/demo/web1" "../x"; [ "$status" -ne 0 ]
    [ "$(ls "$T/state/demo/web1")" = "result.status" ]                                  # geçici dosya kalmadı
}

@test "hazırlık: durum eyleminin son bilinen sonucu yaşıyla gösterilir; henüz çalışmadıysa belirtilir" {
    setup_state
    # status eylemi olan bildirim
    python3 - "$T/comps/demo/1.0.0/component.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["actions"]["status"]={"cmd":"ansible-playbook s.yml","effects":[],"outputs":{"format":"keyvalue-line","keys":["armed","timer"]}}
json.dump(d,open(p,"w"))
PY
    cp "$T/comps/demo/1.0.0/component.json" "$T/m.json"
    INFO=$(comp_manifest_info "$T/m.json" demo 1.0.0)
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"ℹ️  status: henüz çalıştırılmadı"* ]] || false
    mkdir -p "$T/state/demo/web1"
    COMP_EXEC_RESULT=$'armed=no\ntimer=inactive'; comp_exec_save_result "$T/state/demo/web1" status
    run comp_menu_actions demo web1 <<<$'0'
    [[ "$output" == *"ℹ️  status ("*"önce): armed=no timer=inactive"* ]] || false
}

# ---------- kapsama (üst üste binen ağlar) ----------
@test "cidr: mevcut daha geniş bir ağın içindeki öneri eklenmez ('Zaten kapsanıyor')" {
    setup_net; comp_vars_set "$D/demo.vars" allow_from "10.99.0.0/16"
    run comp_menu_actions demo web1 <<<$'1\n1\n1\ne\n192.168.1.0/24\nk\n\n0\n0'
    [[ "$output" == *"Zaten kapsanıyor: 10.99.0.0/16"* ]] || false
    [ "$(vget allow_from)" = "10.99.0.0/16,192.168.1.0/24" ]
}

@test "cidr: daha geniş ağ eklenince kapsadığı dar girdiler yerine geçer ve kullanıcı bilgilendirilir" {
    setup_net; comp_vars_set "$D/demo.vars" allow_from "10.99.0.4/32,192.168.1.0/24"
    run comp_menu_actions demo web1 <<<$'1\n1\ne\n10.99.0.0/24\nk\n\n0\n0'
    [[ "$output" == *"kapsadığı için kaldırıldı: 10.99.0.4/32"* ]] || false
    [ "$(vget allow_from)" = "192.168.1.0/24,10.99.0.0/24" ]
}
