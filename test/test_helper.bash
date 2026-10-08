# Ortak test yardımcıları
bats_require_minimum_version 1.5.0
# Kök dizin: bu dosyanın konumundan (test/ ve test/e2e/ altındaki testler için de doğru)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$ROOT/sistem/Helpers"

load_helpers() {
    # shellcheck source=/dev/null
    source "$H/Validate.sh"
    # shellcheck source=/dev/null
    source "$H/ModuleFiles.sh"
    # shellcheck source=/dev/null
    source "$H/SSHModule.sh"
    # shellcheck source=/dev/null
    source "$H/SSHHelper.sh"
    # shellcheck source=/dev/null
    source "$H/SSHModuleEdit.sh"
}

# İçinde sistem/ kopyası olan izole bir çalışma alanı (eject kapalı, sahte komutlar PATH başında)
make_sandbox() {
    SANDBOX="$BATS_TEST_TMPDIR/sb"
    mkdir -p "$SANDBOX/bin"
    cp -R "$ROOT/sistem" "$ROOT/start.sh" "$SANDBOX/"
    printf 'EjectUSB(){ :; }\n' > "$SANDBOX/sistem/Helpers/Eject.sh"
}
