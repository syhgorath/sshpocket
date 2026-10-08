#!/usr/bin/env bats
# Depoya yanlışlıkla gizli bilgi/yanlış biçimli güven noktası girmesini engeller.
load test_helper

@test "release_signers: her anahtar satırı beklenen biçimde (yalnızca PUBLIC ed25519)" {
    run grep -v '^[[:space:]]*#' "$ROOT/sistem/release_signers"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^sshpocket-release\ namespaces=\"sshpocket-release\"\ ssh-ed25519\ [A-Za-z0-9+/]+=*$ ]]
    done <<< "$output"
}
@test "release_signers: ssh-keygen satırı gerçek bir anahtar olarak ayrıştırır" {
    key=$(grep -v '^[[:space:]]*#' "$ROOT/sistem/release_signers" | head -n 1 | cut -d' ' -f3,4)
    [ -n "$key" ]
    run bash -c "printf '%s\n' '$key' | ssh-keygen -lf /dev/stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ED25519"* ]]
}
@test "izlenen hiçbir dosyada özel anahtar bloğu yok" {
    command -v git >/dev/null || skip "git yok"
    git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || skip "git deposu değil"
    run git -C "$ROOT" grep -lE 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY' -- . ':!test/repo_hygiene.bats'
    [ "$status" -ne 0 ]
}
@test "izlenen dosyalar arasında .env, anahtar veya sır dosyası yok" {
    git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || skip "git deposu değil"
    run bash -c "git -C '$ROOT' ls-files | grep -E '(^|/)\.env$|(^|/)id_(ed25519|rsa|ecdsa)[^.]*$|\.pem$|\.secrets$|sshpocket_release$'"
    [ "$status" -ne 0 ]
}
