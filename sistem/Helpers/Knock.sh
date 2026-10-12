#!/usr/bin/env bash
# Knock.sh - Klasik port knocking, İSTEMCİ tarafı (docs/components-design.md §6.7)
#
# server.env:    KNOCK=keychain   KNOCK_PROTO=tcp|udp (varsayılan tcp)   KNOCK_DELAY_MS=0-5000 (varsayılan 300)
# Knock dizisi (örn. 7000,8000,9000) DÜZ METİN DOSYADA TUTULMAZ: Keychain hesabı USBMonitor_<ÖNEK>_Knock.
# Gönderim bash'in /dev/tcp|/dev/udp'siyle yapılır: portlar hiçbir sürecin komut satırında görünmez.
# Not: klasik knocking şifreli değildir (ağı dinleyen kaydedip tekrar oynatabilir); tarama gizleme katmanıdır.
# Gerektirir: SSHHelper.sh (SSH_KEYCHAIN_SERVICE), Servers.sh (srv_get/srv_set)

knock_account() { echo "USBMonitor_${1}_Knock"; }

# "7000,8000,9000": 1-10 port, her biri 1-65535 tamsayı
knock_ports_valid() {
    local seq="$1" p n=0 old_ifs="$IFS"
    [[ "$seq" =~ ^[0-9]+(,[0-9]+)*$ ]] || return 1
    IFS=,
    for p in $seq; do
        n=$((n + 1))
        if [ "$((10#$p))" -lt 1 ] || [ "$((10#$p))" -gt 65535 ]; then IFS="$old_ifs"; return 1; fi
    done
    IFS="$old_ifs"
    [ "$n" -ge 1 ] && [ "$n" -le 10 ]
}

# Bu sunucuda knock etkin mi? Parametreler: önek, modül klasörü
knock_enabled() {
    [ "$(srv_get "$2" "$1" KNOCK 2>/dev/null)" = "keychain" ]
}

knock_has_sequence() {
    security find-generic-password -a "$(knock_account "$1")" -s "$SSH_KEYCHAIN_SERVICE" >/dev/null 2>&1
}

# Keychain'deki diziyi yazdırır (yoksa dönüş 1)
knock_get_sequence() {
    security find-generic-password -a "$(knock_account "$1")" -s "$SSH_KEYCHAIN_SERVICE" -w 2>/dev/null
}

# Tek vuruş (testte işlev değiştirilir). 1 sn içinde tamamlanmazsa öldürülür (kapalı porta SYN zaten gitmiştir).
_knock_send_one() {
    local ip="$1" port="$2" proto="$3" pid killer
    (
        exec 3<>"/dev/$proto/$ip/$port" || exit 0
        if [ "$proto" = "udp" ]; then printf 'x' >&3; fi
    ) 2>/dev/null &
    pid=$!
    ( sleep 1; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
    killer=$!
    wait "$pid" 2>/dev/null || true
    kill "$killer" 2>/dev/null || true
    wait "$killer" 2>/dev/null || true
    return 0
}

# knock_send <ip> <port,port,...> <tcp|udp> <gecikme-ms>
knock_send() {
    local ip="$1" seq="$2" proto="$3" delay="$4" p secs old_ifs="$IFS"
    secs=$(printf '%d.%03d' "$((delay / 1000))" "$((delay % 1000))")
    IFS=,
    for p in $seq; do
        IFS="$old_ifs"
        _knock_send_one "$ip" "$((10#$p))" "$proto"
        [ "$delay" -gt 0 ] && sleep "$secs"
        IFS=,
    done
    IFS="$old_ifs"
}

# Bağlanmadan önce çağrılır. Knock etkin değilse hiçbir şey yapmaz (dönüş 0).
# Parametreler: önek, modül klasörü, ip. Hata (Keychain/ayar bozuk) = dönüş 1, bağlantı denenmemeli.
knock_pre_connect() {
    local prefix="$1" dir="$2" ip="$3" seq proto delay
    knock_enabled "$prefix" "$dir" || return 0
    proto=$(srv_get "$dir" "$prefix" KNOCK_PROTO 2>/dev/null); proto="${proto:-tcp}"
    delay=$(srv_get "$dir" "$prefix" KNOCK_DELAY_MS 2>/dev/null); delay="${delay:-300}"
    case "$proto" in tcp|udp) ;; *) echo "⚠️  KNOCK_PROTO geçersiz ($proto): tcp veya udp olmalı" >&2; return 1 ;; esac
    if ! [[ "$delay" =~ ^[0-9]+$ ]] || [ "$delay" -gt 5000 ]; then
        echo "⚠️  KNOCK_DELAY_MS geçersiz ($delay): 0-5000 olmalı" >&2; return 1
    fi
    seq=$(knock_get_sequence "$prefix") || { echo "⚠️  Knock dizisi Keychain'de yok; menüden 'Knock ayarları'nı yapın" >&2; return 1; }
    if ! knock_ports_valid "$seq"; then echo "⚠️  Keychain'deki knock dizisi geçersiz" >&2; return 1; fi
    echo "🚪 Knock gönderiliyor ($proto)..."
    knock_send "$ip" "$seq" "$proto" "$delay"
    return 0
}

# Menü: knock ayarları. Parametreler: önek, modül klasörü
knock_manage() {
    local prefix="$1" dir="$2" choice seq proto delay account
    account=$(knock_account "$prefix")
    echo ""
    if knock_enabled "$prefix" "$dir" && knock_has_sequence "$prefix"; then
        echo "Knock: ✅ etkin ($(srv_get "$dir" "$prefix" KNOCK_PROTO 2>/dev/null || true), gecikme $(srv_get "$dir" "$prefix" KNOCK_DELAY_MS 2>/dev/null || true) ms; dizi Keychain'de)"
    else
        echo "Knock: ❌ kapalı"
    fi
    echo "  1) Diziyi kaydet / güncelle"
    echo "  2) Kapat (Keychain kaydını sil)"
    echo "  0) Geri (q)"
    read -r -p "Seçim [0]: " choice || return 0
    case "${choice:-0}" in
        1)
            read -r -p "Protokol [tcp/udp, Enter = tcp]: " proto || return 0
            proto="${proto:-tcp}"
            case "$proto" in tcp|udp) ;; *) echo "⚠️  Geçersiz protokol"; return 1 ;; esac
            read -r -p "Vuruşlar arası bekleme ms [0-5000, Enter = 300]: " delay || return 0
            delay="${delay:-300}"
            if ! [[ "$delay" =~ ^[0-9]+$ ]] || [ "$delay" -gt 5000 ]; then echo "⚠️  Geçersiz süre"; return 1; fi
            echo "Knock dizisini (örn. 7000,8000,9000) sıradaki istemde girin; ekranda görünmez:"
            if ! security add-generic-password -U -a "$account" -s "$SSH_KEYCHAIN_SERVICE" -w; then
                echo "⚠️  Kaydedilemedi"; return 1
            fi
            seq=$(knock_get_sequence "$prefix")
            if ! knock_ports_valid "$seq"; then
                security delete-generic-password -a "$account" -s "$SSH_KEYCHAIN_SERVICE" >/dev/null 2>&1
                echo "⚠️  Dizi geçersiz (1-10 port, 1-65535, virgülle) ve silindi"; return 1
            fi
            srv_set "$dir" "$prefix" KNOCK keychain
            srv_set "$dir" "$prefix" KNOCK_PROTO "$proto"
            srv_set "$dir" "$prefix" KNOCK_DELAY_MS "$delay"
            echo "✅ Knock etkin: bağlanmadan önce otomatik gönderilir"
            ;;
        2)
            security delete-generic-password -a "$account" -s "$SSH_KEYCHAIN_SERVICE" >/dev/null 2>&1
            srv_set "$dir" "$prefix" KNOCK ""
            echo "✅ Knock kapatıldı"
            ;;
    esac
}
