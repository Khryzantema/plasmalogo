#!/usr/bin/env python3
"""Minimal gettext tooling for a Plasma applet, without needing gettext installed.

    tools/i18n.py extract    -> po/<domain>.pot from i18n()/i18nc()/i18np()/i18ncp() calls
    tools/i18n.py update     -> merge the .pot into every po/*.po (keeps existing translations)
    tools/i18n.py compile    -> package/contents/locale/<lang>/LC_MESSAGES/<domain>.mo

The domain is "plasma_applet_<Id>", the one Plasma loads for applets
(translations are looked up in the package's contents/locale directory).
"""

import glob
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = os.path.join(ROOT, "package")
PO_DIR = os.path.join(ROOT, "po")

STRING = r'"((?:[^"\\]|\\.)*)"'
CALL = re.compile(r'\b(i18n|i18nc|i18np|i18ncp)\(\s*' + STRING + r'(?:\s*,\s*' + STRING + r')?(?:\s*,\s*' + STRING + r')?')


def domain():
    with open(os.path.join(PACKAGE, "metadata.json"), encoding="utf-8") as f:
        return "plasma_applet_" + json.load(f)["KPlugin"]["Id"]


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def po_quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"'


# ---------------------------------------------------------------- extract

def extract():
    entries = {}  # (ctx, msgid, plural) -> [locations]
    for path in sorted(glob.glob(os.path.join(PACKAGE, "contents", "**", "*.qml"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                for m in CALL.finditer(line):
                    kind, a, b, c = m.group(1), m.group(2), m.group(3), m.group(4)
                    ctx, msgid, plural = None, a, None
                    if kind == "i18nc":
                        ctx, msgid = a, b
                    elif kind == "i18np":
                        plural = b
                    elif kind == "i18ncp":
                        ctx, msgid, plural = a, b, c
                    if msgid is None or (kind in ("i18np", "i18ncp") and plural is None):
                        print(f"warning: could not parse {kind}() at {rel}:{lineno}", file=sys.stderr)
                        continue
                    key = (ctx and unescape(ctx), unescape(msgid), plural and unescape(plural))
                    entries.setdefault(key, []).append(f"{rel}:{lineno}")

    os.makedirs(PO_DIR, exist_ok=True)
    out = os.path.join(PO_DIR, domain() + ".pot")
    with open(out, "w", encoding="utf-8") as f:
        f.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n\n')
        for (ctx, msgid, plural), locations in entries.items():
            f.write("#: " + " ".join(locations) + "\n")
            if ctx is not None:
                f.write("msgctxt " + po_quote(ctx) + "\n")
            f.write("msgid " + po_quote(msgid) + "\n")
            if plural is not None:
                f.write("msgid_plural " + po_quote(plural) + "\n")
                f.write('msgstr[0] ""\nmsgstr[1] ""\n\n')
            else:
                f.write('msgstr ""\n\n')
    print(f"{out}: {len(entries)} strings")


# ---------------------------------------------------------------- .po parsing

def parse_po(path):
    """Returns (header, [entry]) where entry = dict(ctx, msgid, plural, msgstr: list, comments)."""
    entries, cur, field = [], None, None

    def flush():
        if cur is not None and cur.get("msgid") is not None:
            entries.append(cur)

    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                flush()
                cur, field = None, None
                continue
            if cur is None:
                cur = {"ctx": None, "msgid": None, "plural": None, "msgstr": {}, "comments": [], "fuzzy": False}
            if line.startswith("#"):
                cur["comments"].append(line)
                if line.startswith("#,") and "fuzzy" in line:
                    cur["fuzzy"] = True
                continue
            m = re.match(r'(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+(".*")$', line)
            if m:
                key, index, value = m.group(1), m.group(2), unescape(m.group(3)[1:-1])
                if key == "msgctxt":
                    field = ("ctx", None)
                elif key == "msgid":
                    field = ("msgid", None)
                elif key == "msgid_plural":
                    field = ("plural", None)
                else:
                    field = ("msgstr", int(index) if index is not None else 0)
                if field[0] == "msgstr":
                    cur["msgstr"][field[1]] = value
                else:
                    cur[field[0]] = value
            elif line.startswith('"') and field is not None:
                value = unescape(line[1:-1])
                if field[0] == "msgstr":
                    cur["msgstr"][field[1]] += value
                else:
                    cur[field[0]] += value
    flush()
    header = next((e for e in entries if e["msgid"] == "" and e["ctx"] is None), None)
    return header, [e for e in entries if e is not header]


def key_of(e):
    return (e["ctx"], e["msgid"], e["plural"])


def nplurals(header):
    """Number of plural forms declared in the .po header (Plural-Forms: nplurals=N; ...)."""
    m = re.search(r"nplurals\s*=\s*(\d+)", header["msgstr"].get(0, "") if header else "")
    return int(m.group(1)) if m else 2


# ---------------------------------------------------------------- update

def update():
    pot = os.path.join(PO_DIR, domain() + ".pot")
    _, template = parse_po(pot)
    for po in sorted(glob.glob(os.path.join(PO_DIR, "*.po"))):
        header, old = parse_po(po)
        known = {key_of(e): e for e in old}
        forms_count = nplurals(header)
        with open(po, "w", encoding="utf-8") as f:
            f.write('msgid ""\nmsgstr ""\n')
            for line in (header["msgstr"].get(0, "") if header else "").splitlines(keepends=True):
                f.write(po_quote(line) + "\n")
            f.write("\n")
            missing = 0
            for e in template:
                t = known.get(key_of(e))
                f.write("\n".join(c for c in e["comments"] if c.startswith("#:")) + "\n")
                if e["ctx"] is not None:
                    f.write("msgctxt " + po_quote(e["ctx"]) + "\n")
                f.write("msgid " + po_quote(e["msgid"]) + "\n")
                if e["plural"] is not None:
                    f.write("msgid_plural " + po_quote(e["plural"]) + "\n")
                    forms = t["msgstr"] if t else {}
                    for i in range(forms_count):
                        f.write(f"msgstr[{i}] " + po_quote(forms.get(i, "")) + "\n")
                    missing += not all(forms.get(i) for i in range(forms_count))
                else:
                    value = t["msgstr"].get(0, "") if t else ""
                    f.write("msgstr " + po_quote(value) + "\n")
                    missing += not value
                f.write("\n")
        print(f"{po}: {len(template)} strings, {missing} untranslated")


# ---------------------------------------------------------------- compile

def write_mo(path, messages):
    """messages: dict of original bytes -> translated bytes (gettext .mo, no hash table)."""
    keys = sorted(messages)
    ids = b"".join(k + b"\0" for k in keys)
    strs = b"".join(messages[k] + b"\0" for k in keys)
    n = len(keys)
    header_size = 7 * 4
    orig_table = header_size
    trans_table = orig_table + n * 8
    ids_start = trans_table + n * 8
    strs_start = ids_start + len(ids)

    offsets, pos = [], 0
    for k in keys:
        offsets.append((len(k), ids_start + pos))
        pos += len(k) + 1
    toffsets, pos = [], 0
    for k in keys:
        v = messages[k]
        toffsets.append((len(v), strs_start + pos))
        pos += len(v) + 1

    with open(path, "wb") as f:
        f.write(struct.pack("<7I", 0x950412DE, 0, n, orig_table, trans_table, 0, 0))
        for length, offset in offsets:
            f.write(struct.pack("<2I", length, offset))
        for length, offset in toffsets:
            f.write(struct.pack("<2I", length, offset))
        f.write(ids)
        f.write(strs)


def compile_all():
    dom = domain()
    for po in sorted(glob.glob(os.path.join(PO_DIR, "*.po"))):
        lang = os.path.splitext(os.path.basename(po))[0]
        header, entries = parse_po(po)
        forms_count = nplurals(header)
        messages = {b"": (header["msgstr"].get(0, "") if header else "").encode("utf-8")}
        count = 0
        for e in entries:
            if e["fuzzy"]:
                continue
            if e["plural"] is not None:
                forms = [e["msgstr"].get(i, "") for i in range(forms_count)]
            else:
                forms = [e["msgstr"].get(0, "")]
            # Incomplete entries fall back to English instead of showing empty text.
            if not all(forms):
                continue
            key = e["msgid"] if e["plural"] is None else e["msgid"] + "\0" + e["plural"]
            if e["ctx"] is not None:
                key = e["ctx"] + "\x04" + key
            messages[key.encode("utf-8")] = "\0".join(forms).encode("utf-8")
            count += 1
        out_dir = os.path.join(PACKAGE, "contents", "locale", lang, "LC_MESSAGES")
        os.makedirs(out_dir, exist_ok=True)
        out = os.path.join(out_dir, dom + ".mo")
        write_mo(out, messages)
        print(f"{out}: {count} translations")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    {"extract": extract, "update": update, "compile": compile_all}.get(command, lambda: sys.exit(__doc__))()
