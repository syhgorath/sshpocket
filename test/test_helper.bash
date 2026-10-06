# Ortak test yardımcıları
bats_require_minimum_version 1.5.0
ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
H="$ROOT/sistem/Helpers"

load_helpers() {
    # shellcheck source=/dev/null
    source "$H/Validate.sh"
    # shellcheck source=/dev/null
    source "$H/ModuleFiles.sh"
    # shellcheck source=/dev/null
    source "$H/SSHModule.sh"
}

# İçinde sistem/ kopyası olan izole bir çalışma alanı (eject kapalı, sahte komutlar PATH başında)
make_sandbox() {
    SANDBOX="$BATS_TEST_TMPDIR/sb"
    mkdir -p "$SANDBOX/bin"
    cp -R "$ROOT/sistem" "$ROOT/start.sh" "$SANDBOX/"
    printf 'EjectUSB(){ :; }\n' > "$SANDBOX/sistem/Helpers/Eject.sh"
}
