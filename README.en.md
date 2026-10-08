# sshpocket

[![ci](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml/badge.svg)](https://github.com/syhgorath/sshpocket/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

🇹🇷 [Türkçe](README.md) · 🇬🇧 English

A modular SSH launcher menu for macOS that you can carry on a USB drive (or run from any folder).
Every server is a *module*: drop a module folder in and it shows up in the menu automatically.

> **Status: raw / early stage.** 🛠️
> This grew out of a personal HomeLab tool. It was reworked together with
> [Claude](https://claude.com/claude-code) and is much better than where it started, but there is
> still plenty to improve: rough edges, missing tests and unwritten features are expected.
> Any problems are down to the project being unfinished, so please be kind 😄 — issues and PRs are
> very welcome. Tested on macOS only. Read the code before using it on your own servers;
> you use it at your own risk (see [LICENSE](LICENSE)).

> **It does not auto-start.** macOS, Linux and modern Windows do not run scripts when a USB drive
> is plugged in (by design). Start it manually: `./start.sh`, or double-click `start.command` in Finder.

## Quick start

```bash
./start.sh                          # start the menu
```

Everything is available from the main menu: connect to a server, **➕ Add a new server**,
**📥 Import from ~/.ssh/config** and **🛠️ Manage servers** (list/remove/rename).
The same tools work from the command line:

```bash
bash sistem/ModuleGenerator.sh      # create a new server module
bash sistem/ImportSSHConfig.sh      # import hosts from ~/.ssh/config
bash sistem/ModuleManager.sh list   # list modules (also: remove / rename)
```

The generator asks for IP/user/port, can create an ed25519 key and stores the passphrase in the
**macOS Keychain**.

> Note: the interface text and code comments are currently in Turkish; translations are welcome.

## Features

- **Modular:** one folder per server; the menu builds itself.
- **Keychain:** passphrases are never written to disk.
- **Send your key to the server:** `ssh-copy-id` from the menu or the generator.
- **`~/.ssh/config` import:** turns existing hosts into modules. Private keys are **not copied**;
  the `IdentityFile` path is stored as `<PREFIX>_KEY` in the module's `.env`.
- **Use an existing key:** set `<PREFIX>_KEY=/path/to/key` in `.env`.
- **Status marks:** `SSHPOCKET_STATUS=1 ./start.sh` shows 🟢 (port open) / 🔴 (unreachable) / ⚪ (not configured),
  checked in parallel.
- **Module menu:** Connect · Send key to server · **Update details** (IP/user/port/key path) ·
  **Update/delete the Keychain passphrase** (verifies it by unlocking the key after saving). The update options
  stay available even when the settings are broken or the key is missing.
- **Module management:** `ModuleManager.sh list | remove <name> | rename <old> <new>`.
- **Several users/keys for one server:** make one module per identity (e.g. `web_root`, `web_deploy`).
- 84 automated tests (Bats) + ShellCheck run in CI on every push.

## Sending the key to the server

**2) Send public key to server** in a module's menu (or the generator's last step) runs `ssh-copy-id`:

- If the key is already authorized it says so and does nothing.
- Otherwise `ssh-copy-id` tries your agent/default keys first and falls back to your **password**.
  You can also point it to a different key file for the login.
- The password is only ever typed into `ssh`'s own prompt; this tool never sees it.
- Setting `PasswordAuthentication no` on the server is **deliberately not automated.** Do it by hand
  after you have confirmed that key login works, or you may lock yourself out.

## Security model

- **Passphrases are never written to disk.** They live in the Keychain (`USBMonitor_<PREFIX>_Passphrase`)
  and are handed to `ssh-add` via `SSH_ASKPASS`.
- `.env` holds only IP, user, port (and optionally a key path) — **never secrets**.
- Do **not** keep TOTP/2FA secrets in this folder; keep them in your phone's authenticator.
- `.env`, `id_ed25519*` and `usb_logs/` are git-ignored.
- IP/user/port are validated before any command runs (the user cannot start with `-`).
- The server's host key is confirmed by you on first connect (no auto-accept).
- If you carry private keys on a USB drive, encrypt the drive (encrypted APFS volume).
- To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Layout

```
start.sh / start.command   entry points
sistem/Main.sh             menu loop
sistem/Autoload.sh         auto-loads everything under Modules/
sistem/ModuleGenerator.sh  new module (+ key generation, Keychain, ssh-copy-id)
sistem/ImportSSHConfig.sh  import from ~/.ssh/config
sistem/ModuleManager.sh    list / remove / rename
sistem/Helpers/            logging, menu, registry, validation, SSH, eject helpers
sistem/Modules/<name>/     per server: <Name>Module.sh, .env, id_ed25519_<name>
test/                      Bats tests (bats test)
```

## Development

```bash
brew install shellcheck bats-core
shellcheck -x -s bash start.sh start.command sistem/*.sh sistem/Helpers/*.sh sistem/Modules/*/*.sh
bats test
```

See [CONTRIBUTING.md](CONTRIBUTING.md) to contribute and [ROADMAP.md](ROADMAP.md) for what is planned.

## License

MIT, see [LICENSE](LICENSE).
