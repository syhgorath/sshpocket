#!/usr/bin/env bats
# Gerçek bir Ubuntu 26.04 (systemd'li Docker LAB'ı) sunucusuna karşı paket akışı: sshpocket → ssh → ansible → ufw/sshd/systemd.
#   ./test/e2e/lab/up.sh && bats test/e2e/components.bats && ./test/e2e/lab/down.sh
# LAB yoksa/çalışmıyorsa testler ATLANIR. Varsayılan `bats test` bu klasörü ÇALIŞTIRMAZ.
# Testler LAB'ın DURUMUNA göre atlar (temiz/uygulanmış), bu yüzden sıra bağımsızdır; ama tam akış için up.sh ile SIFIRDAN başlayın.
# Gerekenler: docker (Colima/Docker Desktop), expect, ~/.cache/sshpocket altında kurulu linux-hardening venv'i
#   (yoksa: E2E_INSTALL_VENV=e ile ilk çalıştırma onaylı kurar; PyPI'dan ~10 MB indirir).
load ../test_helper

setup() {
    LABDIR="$ROOT/test/e2e/lab"; STATE="$LABDIR/.state"
    command -v docker >/dev/null || skip "docker yok"
    command -v expect >/dev/null || skip "expect yok"
    [ -f "$STATE/kh" ] || skip "önce ./test/e2e/lab/up.sh"
    [ "$(docker inspect -f '{{.State.Running}}' sshpocket-lab 2>/dev/null)" = "true" ] || skip "sshpocket-lab konteyneri çalışmıyor"
    PORT="${LAB_PORT:-2223}"
    LAB_SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=8 -o UserKnownHostsFile="$STATE/kh" -p "$PORT" -i "$STATE/id_lab" tester@127.0.0.1)
}

# lab_run <eylem> → çıktı (CR temizlenmiş) ve çıkış kodu; ANSI ve Ansible gürültüsü kalır, aramalar buna göre yapılır
lab_run() { run "$LABDIR/run.sh" "$@"; output="$(printf '%s' "$output" | tr -d '\r')"; }
in_lab() { docker exec sshpocket-lab sh -c "$1"; }
applied() { in_lab 'test -e /etc/ssh/sshd_config.d/00-hardening.conf' 2>/dev/null; }
fresh_or_skip() { ! applied || skip "LAB zaten uygulanmış; sıfırdan başlamak için up.sh"; }
applied_or_skip() { applied || skip "LAB'a henüz apply yapılmamış"; }

@test "lab: sshd'ye anahtarla girilir, sudo parolasızdır ve işletim sistemi Ubuntu 26.04" {
    run "${LAB_SSH[@]}" 'sudo -n true && . /etc/os-release && echo "$PRETTY_NAME"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ubuntu 26.04"* ]] || false
}

@test "rollback_status (temiz sunucu): installed=no ve sonuç satırı ayrıştırılır" {
    fresh_or_skip
    lab_run rollback_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Profil: ubuntu-26.04"* ]] || false
    [[ "$output" == *"installed=no"* ]] || false
    [[ "$output" == *"failed=0"* ]] || false
}

@test "apply, taze bir preview olmadan REDDEDİLİR ve sunucu değişmez" {
    fresh_or_skip
    rm -rf "$STATE/userdata"
    lab_run apply
    [ "$status" -eq 190 ]
    [[ "$output" == *"önce 'preview'"* ]] || false
    run in_lab 'test -e /etc/ssh/sshd_config.d/00-hardening.conf'
    [ "$status" -ne 0 ]
}

@test "preview: başarılı olur ve sunucuda HİÇBİR ŞEY değişmez" {
    fresh_or_skip
    lab_run preview
    [ "$status" -eq 0 ]
    [[ "$output" == *"failed=0"* ]] || false
    run in_lab 'dpkg -s dma >/dev/null 2>&1 || test -e /etc/ssh/sshd_config.d/00-hardening.conf || test -e /etc/modprobe.d/60-hardening-usb.conf'
    [ "$status" -ne 0 ]
    grep -q '|preview|ok$' "$STATE/userdata/linux-hardening/lab/results"
}

@test "apply (preview sonrası): başarılı olur; SSH, ufw ve servisler beklenen duruma gelir; güvenlik ağı disarm edilir" {
    fresh_or_skip
    grep -q '|preview|ok$' "$STATE/userdata/linux-hardening/lab/results" 2>/dev/null || skip "önce preview testi"
    lab_run apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"failed=0"* ]] || false
    run in_lab 'sshd -T | grep -E "^(permitrootlogin no|passwordauthentication no|allowtcpforwarding no|maxauthtries 3)$" | wc -l'
    [ "$output" = "4" ]
    run in_lab 'ufw status verbose'
    [[ "$output" == *"Default: deny (incoming)"* ]] || false
    [[ "$output" == *"22/tcp"*"ALLOW IN"*"172.17.0.0/16"* ]] || false
    run in_lab 'systemctl is-active fail2ban ufw'
    [ "${lines[0]}" = "active" ]
    run in_lab 'systemctl is-active hardening-rollback.timer'
    [ "$output" = "inactive" ]
    run in_lab 'dpkg -s postfix >/dev/null 2>&1'
    [ "$status" -ne 0 ]
    # erişim hâlâ var (yeni bağlantı doğrulaması + disarm çalıştı)
    run "${LAB_SSH[@]}" echo ERISIM-VAR
    [ "$status" -eq 0 ]
}

@test "rollback_status (apply sonrası): installed=yes armed=no ve sonuç saklanır" {
    applied_or_skip
    lab_run rollback_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"installed=yes"* ]] || false
    [[ "$output" == *"armed=no"* ]] || false
    [ -f "$STATE/userdata/linux-hardening/lab/result.rollback_status" ]
}

@test "ERİŞİM AĞI TUZAĞI: izin verilmeyen bir ağdan SSH zaman aşımına uğrar; ufw kapatılınca aynı istemci girer" {
    applied_or_skip
    docker network create sshpocket-other >/dev/null 2>&1 || true
    docker network connect sshpocket-other sshpocket-lab >/dev/null 2>&1 || true
    local ip
    ip=$(docker inspect -f '{{(index .NetworkSettings.Networks "sshpocket-other").IPAddress}}' sshpocket-lab)
    [ -n "$ip" ]
    client() { cat "$STATE/id_lab" | docker run --rm -i --network sshpocket-other --entrypoint /bin/sh sshpocket-lab:ubuntu26 -c \
        "cat > /tmp/k && chmod 600 /tmp/k && ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -i /tmp/k tester@$ip echo ERISIM-VAR"; }
    run client
    [ "$status" -ne 0 ]
    [[ "$output" == *"timed out"* ]] || false
    in_lab 'ufw disable' >/dev/null
    run client
    in_lab 'ufw --force enable' >/dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERISIM-VAR"* ]] || false
}

# ---------- hata yolları: sunucuya dokunulmaz, temiz ret ----------
@test "sunucu erişilemezse (konteyner duraklatıldı): 'algılanamadı' ile durur, Ansible başlamaz" {
    docker pause sshpocket-lab >/dev/null
    lab_run rollback_status
    docker unpause sshpocket-lab >/dev/null
    [ "$status" -eq 190 ]
    [[ "$output" == *"işletim sistemi algılanamadı"* ]] || false
    [[ "$output" != *"PLAY RECAP"* ]] || false
}

@test "host key tanınmıyorsa (known_hosts boş) çalıştırılmaz" {
    cp "$STATE/kh" "$STATE/kh.bak"; : > "$STATE/kh"
    lab_run rollback_status
    cp "$STATE/kh.bak" "$STATE/kh"; rm -f "$STATE/kh.bak"
    [ "$status" -eq 190 ]
    [[ "$output" == *"host key'i tanınmıyor"* ]] || false
    [[ "$output" != *"PLAY RECAP"* ]] || false
}

@test "host key DEĞİŞMİŞSE (sahte anahtar) bağlantı reddedilir; host key doğrulaması kapatılmaz" {
    cp "$STATE/kh" "$STATE/kh.bak"
    local fk="$BATS_TEST_TMPDIR/fakehost"
    ssh-keygen -q -t ed25519 -N '' -f "$fk"
    { printf '[127.0.0.1]:%s ' "$PORT"; cut -d' ' -f1,2 "$fk.pub"; } > "$STATE/kh"
    lab_run rollback_status
    cp "$STATE/kh.bak" "$STATE/kh"; rm -f "$STATE/kh.bak"
    [ "$status" -eq 190 ]
    [[ "$output" == *"algılanamadı"* ]] || false
    [[ "$output" != *"PLAY RECAP"* ]] || false
}
