#!/usr/bin/env bash
# askpass.sh - ssh-add için SSH_ASKPASS yardımcısı
# Passphrase'i Keychain'den okuyup stdout'a yazar; diske hiçbir şey yazılmaz.
exec security find-generic-password -a "${ASKPASS_ACCOUNT:?}" -s "${ASKPASS_SERVICE:-USBMonitor}" -w
