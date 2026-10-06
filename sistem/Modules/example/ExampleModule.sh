#!/usr/bin/env bash
# ExampleModule.sh - Örnek SSH bağlantı modülü
# Kendi modülünüzü oluşturmak için:  bash sistem/ModuleGenerator.sh
# (ya da bu klasörü kopyalayıp adları/önekleri değiştirin)
#
# Ayarlar: .env (EXAMPLE_IP, EXAMPLE_USER, EXAMPLE_PORT)
# Key:     id_ed25519_example
# Passphrase: Keychain (hesap: USBMonitor_EXAMPLE_Passphrase)

RegisterModules "EXAMPLE" "MainMenu" "ExampleModule"

_EXAMPLE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ExampleModule() {
    ssh_module_run "EXAMPLE" "$_EXAMPLE_MODULE_DIR"
}
