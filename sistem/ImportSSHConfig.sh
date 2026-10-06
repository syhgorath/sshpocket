#!/usr/bin/env bash
# ImportSSHConfig.sh - ~/.ssh/config'teki sunucuları modül olarak içe aktarır
# Kullanım: bash sistem/ImportSSHConfig.sh [config_dosyası]
# Private key'ler KOPYALANMAZ; IdentityFile yolu modülün .env'ine <ÖNEK>_KEY olarak yazılır.
# SSHPOCKET_MODULES_DIR ile Modules klasörü değiştirilebilir (testler için).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SSHPOCKET_MODULES_DIR:-$SCRIPT_DIR/Modules}"
CONFIG="${1:-$HOME/.ssh/config}"

# shellcheck source=Helpers/Validate.sh
source "$SCRIPT_DIR/Helpers/Validate.sh"
# shellcheck source=Helpers/ModuleFiles.sh
source "$SCRIPT_DIR/Helpers/ModuleFiles.sh"
# shellcheck source=Helpers/SSHConfigImport.sh
source "$SCRIPT_DIR/Helpers/SSHConfigImport.sh"

if [ ! -f "$CONFIG" ]; then
    echo "⚠️  Config bulunamadı: $CONFIG"; exit 1
fi

aliases=(); hosts=(); users=(); ports=(); keys=()
while IFS='|' read -r a h u p k; do
    [ -n "$a" ] || continue
    aliases+=("$a"); hosts+=("$h"); users+=("${u:-$USER}"); ports+=("${p:-22}"); keys+=("$k")
done < <(ssh_config_hosts "$CONFIG")

if [ "${#aliases[@]}" -eq 0 ]; then
    echo "Joker içermeyen Host kaydı bulunamadı."; exit 0
fi

echo "Bulunan sunucular ($CONFIG):"
for i in "${!aliases[@]}"; do
    printf '  %2d) %-20s %s@%s:%s\n' "$((i + 1))" "${aliases[$i]}" "${users[$i]}" "${hosts[$i]}" "${ports[$i]}"
done
echo ""
read -r -p "İçe aktarılacaklar (örn: 1,3  |  a = hepsi  |  Enter = iptal): " pick
[ -n "$pick" ] || { echo "İptal edildi."; exit 0; }

selected=()
if [ "$pick" = "a" ] || [ "$pick" = "A" ]; then
    for i in "${!aliases[@]}"; do selected+=("$i"); done
else
    IFS=', ' read -r -a nums <<< "$pick"
    for n in "${nums[@]}"; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#aliases[@]}" ]; then
            selected+=("$((n - 1))")
        else
            echo "⚠️  Geçersiz seçim atlandı: $n"
        fi
    done
fi

imported=0
for i in ${selected[@]+"${selected[@]}"}; do
    name=$(ssh_config_module_name "${aliases[$i]}")
    if [ -e "$MODULES_DIR/$name" ]; then
        echo "⏭️  $name zaten var, atlandı"; continue
    fi
    key="${keys[$i]}"
    if module_write_files "$MODULES_DIR" "$name" "${hosts[$i]}" "${users[$i]}" "${ports[$i]}" "$key"; then
        echo "✅ $name ($(module_prefix "$name"))${key:+  key: $key}"
        imported=$((imported + 1))
    else
        echo "⚠️  $name içe aktarılamadı (geçersiz değer)"
    fi
done

echo ""
echo "$imported modül oluşturuldu. Passphrase'i Keychain'e eklemek için (varsa):"
echo "  security add-generic-password -U -a USBMonitor_<ÖNEK>_Passphrase -s USBMonitor -w"
