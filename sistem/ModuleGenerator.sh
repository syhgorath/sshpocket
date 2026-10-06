#!/usr/bin/env bash
# ModuleGenerator.sh - Yeni SSH modülü oluşturur
# Kullanım: bash sistem/ModuleGenerator.sh
# Passphrase asla dosyaya yazılmaz; macOS Keychain'e kaydedilir.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/Modules"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}=== Yeni SSH Modülü ===${NC}"
echo ""

read -r -p "Modül adı (küçük harf/rakam/_, harfle başlar, örn: myserver): " module_name
module_name=$(echo "$module_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')
if ! [[ "$module_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo -e "${RED}❌ Geçersiz ad (harfle başlamalı)${NC}"; exit 1
fi

module_dir="$MODULES_DIR/$module_name"
if [ -e "$module_dir" ]; then
    echo -e "${RED}❌ Modül zaten var: $module_dir${NC}"
    echo "   (Üzerine yazılmaz; önce klasörü kendiniz silin.)"
    exit 1
fi

upper=$(echo "$module_name" | tr '[:lower:]' '[:upper:]')
func="$(echo "${module_name:0:1}" | tr '[:lower:]' '[:upper:]')${module_name:1}Module"

read -r -p "SSH IP/host: " ssh_ip
read -r -p "SSH kullanıcı: " ssh_user
read -r -p "SSH port [22]: " ssh_port
ssh_port="${ssh_port:-22}"

if ! [[ "$ssh_ip" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    echo -e "${RED}❌ Geçersiz IP/host${NC}"; exit 1
fi
if ! [[ "$ssh_user" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo -e "${RED}❌ Geçersiz kullanıcı${NC}"; exit 1
fi
if ! [[ "$ssh_port" =~ ^[0-9]+$ ]] || [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; then
    echo -e "${RED}❌ Geçersiz port${NC}"; exit 1
fi

mkdir -p "$module_dir"
key="$module_dir/id_ed25519_${module_name}"

echo ""
read -r -p "Yeni ed25519 SSH key oluşturulsun mu? (y/n) " create_key
if [ "$create_key" = "y" ] || [ "$create_key" = "Y" ]; then
    echo -e "${YELLOW}Passphrase belirleyin (ssh-keygen soracak; boş bırakmanız önerilmez):${NC}"
    ssh-keygen -t ed25519 -a 100 -C "$module_name" -f "$key" || { echo -e "${RED}❌ Key oluşturulamadı${NC}"; exit 1; }
    chmod 600 "$key"
    echo ""
    echo -e "${GREEN}Public key (sunucudaki ~/.ssh/authorized_keys'e ekleyin):${NC}"
    cat "${key}.pub"
    echo ""
    read -r -p "Passphrase Keychain'e kaydedilsin mi? (y/n) " save_kc
    if [ "$save_kc" = "y" ] || [ "$save_kc" = "Y" ]; then
        # -w son argüman: passphrase komut satırında görünmez, güvenli sorulur
        security add-generic-password -U -a "USBMonitor_${upper}_Passphrase" -s "USBMonitor" -w \
            && echo -e "${GREEN}✅ Keychain'e kaydedildi${NC}" \
            || echo -e "${RED}❌ Keychain kaydı başarısız${NC}"
    fi
else
    echo -e "${YELLOW}💡 Mevcut key'i şuraya koyun: $key${NC}"
    echo "   Passphrase'i Keychain'e eklemek için:"
    echo "   security add-generic-password -U -a USBMonitor_${upper}_Passphrase -s USBMonitor -w"
fi

# Gizli bilgi içermeyen .env + şablon
cat > "$module_dir/.env.example" <<EOF
# SSH Bağlantı Bilgileri (gizli bilgi buraya YAZILMAZ)
${upper}_IP=
${upper}_USER=
${upper}_PORT=22
EOF
cat > "$module_dir/.env" <<EOF
# SSH Bağlantı Bilgileri (gizli bilgi buraya YAZILMAZ)
${upper}_IP=${ssh_ip}
${upper}_USER=${ssh_user}
${upper}_PORT=${ssh_port}
EOF
chmod 600 "$module_dir/.env"

# İnce modül dosyası: mantık Helpers/SSHModule.sh'te
cat > "$module_dir/${func}.sh" <<EOF
#!/usr/bin/env bash
# ${func}.sh - ${module_name} SSH bağlantı modülü
# Ayarlar: .env (${upper}_IP, ${upper}_USER, ${upper}_PORT) | Key: id_ed25519_${module_name} | Passphrase: Keychain

RegisterModules "${upper}" "MainMenu" "${func}"

_${upper}_MODULE_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

${func}() {
    ssh_module_run "${upper}" "\$_${upper}_MODULE_DIR"
}
EOF
chmod +x "$module_dir/${func}.sh"

# Key varsa hedef sunucuya göndermeyi öner
if [ -f "$key" ]; then
    echo ""
    read -r -p "Public key şimdi sunucuya gönderilsin mi? (y/n) " do_copy
    if [ "$do_copy" = "y" ] || [ "$do_copy" = "Y" ]; then
        # shellcheck source=Helpers/SSHKeyCopy.sh
        source "$SCRIPT_DIR/Helpers/SSHKeyCopy.sh"
        ssh_copy_key "$ssh_user" "$ssh_ip" "$ssh_port" "$key" || true
    fi
fi

echo ""
echo -e "${GREEN}✅ Modül oluşturuldu: $module_dir${NC}"
echo "   Menüde '${upper}' olarak görünür (start.sh ile başlatın)."
