#!/usr/bin/env python3
# component_run.py - paket değişkenlerinin doğrulanması ve değişken dosyasının üretimi (docs/package-standard.md §6-§7)
#
# Kullanım: python3 -I component_run.py vars <component.json> <değerler-dosyası> <çıktı.json> [--set ad=değer ...]
# Değerler dosyası düz "ad=değer" satırlarıdır (# yorum, boş satır serbest; liste = virgülle ayrılmış). Hiçbir şey
# eval edilmez. --set, dosyadaki değeri ezer (çalıştırıcının zorladığı değerler: örn. outputs.dir_var).
# Çıkış 0: geçerli; çıktı.json izin 600 ile YENİ dosya olarak yazılır. stdout'a yalnızca "warn=<ad>" (warn_if
# eşleşmesi) ve "ok" yazılır; DEĞERLER stdout'a basılmaz. Çıkış 1: geçersiz; nedenler stderr'e. Yalnızca stdlib.
import ipaddress
import json
import os
import re
import sys

MAX_BYTES = 256 * 1024
MAX_VALUES_BYTES = 64 * 1024
RE_NAME = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
RE_CTRL = re.compile(r"[\x00-\x1f\x7f]")
RE_INT = re.compile(r"^-?[0-9]{1,12}$")
RE_LIST = re.compile(r"^list\[(.+)\]$")

errors = []


def err(msg):
    errors.append(msg)


def read_json(path):
    try:
        if os.path.getsize(path) > MAX_BYTES:
            err("component.json çok büyük")
            return None
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        err("component.json okunamadı: %s" % e)
        return None


def parse_values(path):
    out = {}
    if path in ("", "/dev/null"):
        return out
    try:
        if os.path.getsize(path) > MAX_VALUES_BYTES:
            err("değerler dosyası çok büyük")
            return out
        with open(path, "r", encoding="utf-8") as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        return out
    except (OSError, UnicodeDecodeError) as e:
        err("değerler dosyası okunamadı: %s" % e)
        return out
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if "=" not in s:
            err("değerler dosyası satır %d: 'ad=değer' biçiminde değil" % i)
            continue
        k, v = s.split("=", 1)
        k = k.strip()
        if not RE_NAME.match(k):
            err("değerler dosyası satır %d: geçersiz değişken adı" % i)
            continue
        if k in out:
            err("değerler dosyası: yinelenen değişken: %s" % k)
            continue
        out[k] = v.strip()
    return out


def scalar(t, raw, spec, name):
    """raw -> tür değeri; geçersizse err() ve None."""
    if t in ("string", "path"):
        if RE_CTRL.search(raw) or len(raw) > 1024:
            err("%s: değer geçersiz (denetim karakteri/çok uzun)" % name)
            return None
        return raw
    if t == "bool":
        low = raw.lower()
        if low in ("true", "yes"):
            return True
        if low in ("false", "no"):
            return False
        err("%s: true/false olmalı" % name)
        return None
    if t == "int":
        if not RE_INT.match(raw):
            err("%s: tamsayı olmalı" % name)
            return None
        n = int(raw)
        lo, hi = spec.get("min"), spec.get("max")
        if isinstance(lo, int) and not isinstance(lo, bool) and n < lo:
            err("%s: %d en az %d olmalı" % (name, n, lo))
            return None
        if isinstance(hi, int) and not isinstance(hi, bool) and n > hi:
            err("%s: %d en çok %d olmalı" % (name, n, hi))
            return None
        return n
    if t == "cidr":
        try:
            ipaddress.ip_network(raw, strict=False)
        except ValueError:
            err("%s: geçerli bir CIDR değil" % name)
            return None
        return raw
    if t == "enum":
        vals = spec.get("values") or []
        if raw not in vals:
            err("%s: izin verilen değerlerden biri olmalı" % name)
            return None
        return raw
    err("%s: bilinmeyen tür" % name)
    return None


def typed(t, raw, spec, name):
    m = RE_LIST.match(t)
    if m:
        items = [x.strip() for x in raw.split(",")] if raw.strip() else []
        if any(x == "" for x in items):
            err("%s: listede boş öğe var" % name)
            return None
        res = []
        for x in items:
            v = scalar(m.group(1), x, spec, name)
            if v is None:
                return None
            res.append(v)
        return res
    return scalar(t, raw, spec, name)


def main(argv):
    if len(argv) < 5 or argv[1] != "vars":
        print("kullanım: component_run.py vars <component.json> <değerler> <çıktı.json> [--set ad=değer ...]", file=sys.stderr)
        return 2
    manifest, values_path, out_path = argv[2], argv[3], argv[4]
    forced = {}
    rest = argv[5:]
    while rest:
        if rest[0] != "--set" or len(rest) < 2 or "=" not in rest[1]:
            print("--set ad=değer bekleniyordu", file=sys.stderr)
            return 2
        k, v = rest[1].split("=", 1)
        forced[k] = v
        rest = rest[2:]

    d = read_json(manifest)
    declared = {}
    if isinstance(d, dict):
        for v in d.get("vars", []) if isinstance(d.get("vars", []), list) else []:
            if isinstance(v, str):
                v = {"name": v, "type": "string"}
            if isinstance(v, dict) and isinstance(v.get("name"), str):
                declared[v["name"]] = v
    elif d is not None:
        err("component.json nesne olmalı")

    values = parse_values(values_path)
    values.update(forced)
    for k in sorted(values):
        if k not in declared:
            err("%s: pakette tanımlı bir değişken değil" % k)

    result, warns = {}, []
    for name, spec in declared.items():
        t = spec.get("type", "string")
        if name in values and values[name] != "":
            v = typed(t, values[name], spec, name)
            if v is None:
                continue                     # neden zaten bildirildi
        elif "default" in spec:
            v = spec["default"]
        elif name in values and RE_LIST.match(t):
            v = []                           # "ad=" → boş liste (zorunluysa aşağıda reddedilir)
        else:
            v = None
        if v is None or (spec.get("required") is True and v == []):
            if spec.get("required") is True:
                err("%s: zorunlu değişken eksik" % name)
            continue
        result[name] = v
        if "warn_if" in spec and isinstance(v, bool) and v == spec["warn_if"]:
            warns.append(name)

    if errors:
        for m in errors:
            print("HATA: %s" % m, file=sys.stderr)
        return 1
    try:
        fd = os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write("\n")
    except OSError as e:
        print("HATA: değişken dosyası yazılamadı: %s" % e, file=sys.stderr)
        return 1
    for w in sorted(warns):
        print("warn=%s" % w)
    print("ok")
    return 0


sys.exit(main(sys.argv))
