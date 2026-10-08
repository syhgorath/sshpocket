#!/usr/bin/env bash
# BuiltinMenu.sh - Ana menüdeki yerleşik eylemler (sunucu ekle / içe aktar / yönet)
# Gerektirir: Main.sh değişkenleri (SISTEM_PATH), RegisterModules, Autoload

# Yerleşik eylemleri menüye kaydeder (sunucu modüllerinden SONRA çağrılmalı)
RegisterBuiltinMenu() {
    RegisterModules "➕ Yeni sunucu ekle" "MainMenu" "AddServerAction"
    RegisterModules "📥 ~/.ssh/config'ten içe aktar" "MainMenu" "ImportSSHConfigAction"
    RegisterModules "🛠️  Sunucuları yönet (listele/sil/yeniden adlandır)" "MainMenu" "ManageServersAction"
    RegisterModules "⬆️  Güncellemeleri kontrol et / güncelle" "MainMenu" "UpdateAction"
}

# Kayıt defterini sıfırlayıp modülleri yeniden yükler (yeni/silinen modüller hemen yansısın)
ReloadModules() {
    # shellcheck disable=SC2034  # RegisterModules.sh içinde kullanılır
    MODULE_REGISTRY=""
    # shellcheck disable=SC2034
    MODULE_COUNT=0
    Autoload "$SISTEM_PATH/Modules" >/dev/null
    RegisterBuiltinMenu
}

# Fonksiyon adı yerleşik eylem mi? (--auto modunda atlanır)
IsBuiltinAction() {
    case "$1" in
        AddServerAction|ImportSSHConfigAction|ManageServersAction|UpdateAction) return 0 ;;
        *) return 1 ;;
    esac
}

AddServerAction() {
    clear
    bash "$SISTEM_PATH/ModuleGenerator.sh"
    ReloadModules
}

ImportSSHConfigAction() {
    clear
    bash "$SISTEM_PATH/ImportSSHConfig.sh"
    ReloadModules
}

ManageServersAction() {
    local choice name new
    clear
    echo "=== Sunucuları yönet ==="
    echo ""
    bash "$SISTEM_PATH/ModuleManager.sh" list
    echo ""
    echo "  1) Sil"
    echo "  2) Yeniden adlandır"
    echo "  0) Geri"
    if ! read -r -p "Seçim [0]: " choice; then return 0; fi
    case "${choice:-0}" in
        1)
            read -r -p "Silinecek modül adı: " name
            if [ -n "$name" ]; then bash "$SISTEM_PATH/ModuleManager.sh" remove "$name"; fi
            ;;
        2)
            read -r -p "Eski ad: " name
            read -r -p "Yeni ad: " new
            if [ -n "$name" ] && [ -n "$new" ]; then
                bash "$SISTEM_PATH/ModuleManager.sh" rename "$name" "$new"
            fi
            ;;
    esac
    ReloadModules
}

# İmzalı güncelleme (ayrı süreç). Sürüm değiştiyse temiz bir yeniden başlatma yapılır.
UpdateAction() {
    local after
    clear
    bash "$SISTEM_PATH/Update.sh"
    after=$(head -n 1 "$SISTEM_PATH/../VERSION" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$after" ] && [ "$after" != "$SCRIPT_VERSION" ]; then
        echo ""
        read -r -p "Yeni sürümle yeniden başlatmak için Enter..." _ || true
        exec bash "$SISTEM_PATH/Main.sh"
    fi
}
