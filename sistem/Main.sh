#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# USB path'i belirle
USB_PATH="$(cd "$(dirname "$0")/.." && pwd)"
SISTEM_PATH="$USB_PATH/sistem"

SCRIPT_NAME="${SCRIPT_NAME:-sshpocket}"
SCRIPT_VERSION="${SCRIPT_VERSION:-2.0.0}"

USB_NAME=$(basename "$USB_PATH")
USB_UUID="N/A"
if command -v diskutil >/dev/null 2>&1; then
    USB_UUID=$(diskutil info "$USB_PATH" 2>/dev/null | awk -F': *' '/Volume UUID/ {print $2; exit}')
    USB_UUID="${USB_UUID:-N/A}"
fi

# Log dosyası
USB_LOG_FILE="$USB_PATH/usb_logs/system_$(date +%Y%m%d).log"
mkdir -p "$(dirname "$USB_LOG_FILE")"

# Helper'lar (sıra önemli)
source "$SISTEM_PATH/Helpers/Log.sh"
source "$SISTEM_PATH/Helpers/RegisterModules.sh"
source "$SISTEM_PATH/Helpers/Menu.sh"
source "$SISTEM_PATH/Helpers/CheckRoot.sh"
source "$SISTEM_PATH/Helpers/Eject.sh"
source "$SISTEM_PATH/Helpers/SSHHelper.sh"
source "$SISTEM_PATH/Helpers/SSHModule.sh"
source "$SISTEM_PATH/Autoload.sh"

# Modülleri yükle
if [ -d "$SISTEM_PATH/Modules" ]; then
    Autoload "$SISTEM_PATH/Modules"
else
    Log "WARN" "Modules directory not found: $SISTEM_PATH/Modules"
fi

Log "INFO" "=== Registered Modules ($MODULE_COUNT) ==="
if [ -n "$MODULE_REGISTRY" ]; then
    echo "$MODULE_REGISTRY" | while IFS='|' read -r func label group; do
        Log "INFO" "Function: $func | Label: $label | Group: $group"
    done
fi
echo ""

# --auto / --one-click / -y: MainMenu'deki ilk modülü direkt çalıştır
case "${1:-}" in
    --auto|--one-click|-y)
        first_module=$(GetModulesInGroup "MainMenu" | awk '{print $1}')
        if [ -n "$first_module" ] && declare -F "$first_module" >/dev/null 2>&1; then
            Log "INFO" "Auto-executing: $first_module"
            "$first_module"
            exit $?
        fi
        ;;
esac

# Ana menü döngüsü
while true; do
    clear
    echo -e "\033[0;32m========= ${SCRIPT_NAME} v${SCRIPT_VERSION} =========\033[0m"
    echo "USB: $USB_NAME | UUID: $USB_UUID"
    echo "Path: $USB_PATH"
    echo ""

    if [ -z "$(GetModulesInGroup "MainMenu")" ]; then
        Log "ERROR" "MainMenu grubunda modül yok"
        echo ""
        echo "⚠️  Modül bulunamadı. Yeni modül eklemek için:"
        echo "  bash \"$SISTEM_PATH/ModuleGenerator.sh\""
        echo ""
        read -r -p "Çıkmak için Enter..."
        EjectUSB "$USB_PATH"
        exit 1
    fi

    selected=$(Menu "MainMenu")
    selected=$(echo -n "$selected" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -z "$selected" ] || [ "$selected" = "exit" ]; then
        Log "INFO" "Exiting..."
        EjectUSB "$USB_PATH"
        exit 0
    fi

    if declare -F "$selected" >/dev/null 2>&1; then
        Log "INFO" "Executing module: $selected"
        "$selected"
    else
        Log "ERROR" "Function not found: '$selected'"
    fi
    echo ""
    read -r -p "Devam etmek için Enter..."
done
