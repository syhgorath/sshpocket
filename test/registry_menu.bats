#!/usr/bin/env bats
load test_helper
setup() {
    # shellcheck source=/dev/null
    source "$H/RegisterModules.sh"
    # shellcheck source=/dev/null
    source "$H/Menu.sh"
}

@test "modül kaydı ve gruba göre listeleme" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    RegisterModules "TWO" "MainMenu" "TwoModule"
    RegisterModules "OTHER" "Other" "OtherModule"
    run GetModulesInGroup "MainMenu"
    [ "$output" = "OneModule TwoModule" ]
    run GetModulesInGroup "Other"
    [ "$output" = "OtherModule" ]
}
@test "etiket ve varlık sorguları" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    run GetModuleLabel "OneModule"; [ "$output" = "ONE" ]
    run ModuleExists "OneModule";   [ "$status" -eq 0 ]
    run ModuleExists "Yok";         [ "$status" -ne 0 ]
}
@test "etiket/grup eksikse hata" {
    run RegisterModules "" "MainMenu"
    [ "$status" -ne 0 ]
}
@test "menü: numara seçimi fonksiyon adını döndürür" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    RegisterModules "TWO" "MainMenu" "TwoModule"
    run --separate-stderr Menu "MainMenu" <<< "2"
    [ "$output" = "TwoModule" ]
}
@test "menü: 0 çıkış, geçersiz girdi tekrar sorar" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    run --separate-stderr Menu "MainMenu" <<< $'x\n9\n0'
    [ "$output" = "exit" ]
}
@test "menü: SSHPOCKET_STATUS=1 durum simgesini gösterir" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    OneModule_status() { printf 'OK'; }
    SSHPOCKET_STATUS=1 run Menu "MainMenu" <<< "0"
    [[ "$output" == *"OK ONE"* ]]
}
@test "menü: girdi biterse (EOF) sonsuz döngüye girmez" {
    RegisterModules "ONE" "MainMenu" "OneModule"
    run --separate-stderr timeout 5 bash -c 'source "$1/Menu.sh"; source "$1/RegisterModules.sh"; RegisterModules ONE MainMenu OneModule; Menu MainMenu < /dev/null' _ "$H"
    [ "$status" -eq 0 ]
    [ "$output" = "exit" ]
}
