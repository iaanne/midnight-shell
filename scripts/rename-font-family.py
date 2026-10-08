#!/usr/bin/env python3
"""Renames the family strings inside a TrueType font's name table.

Used to re-brand the bundled variable font under a unique family so that a
system-wide install of the upstream font can never collide with it in Qt's
font database (duplicate families resolve to an arbitrary foundry).

Records are rewritten in place: every replacement must shrink (or keep) the
string, which keeps the shared string storage layout valid. The name table
checksum in the table directory and head.checkSumAdjustment are recomputed.

Usage:
  rename-font-family.py FONT --replace "Google Sans Flex=Caelestia Sans" \
      --replace GoogleSansFlex=CaelestiaSans
  rename-font-family.py FONT --replace ... --check   # verify only, no writes

Exits non-zero on a layout conflict, a growth that would need relocation, or
leftover old strings in --check mode.
"""

from __future__ import annotations

import argparse
import struct
import sys

NAME_RECORD = struct.Struct(">HHHHHH")


def read_tables(data: bytes) -> dict[bytes, tuple[int, int]]:
    sfnt, num_tables = struct.unpack(">IH", data[:6])
    if sfnt not in (0x00010000, 0x4F54544F, 0x74727565):
        sys.exit(f"not a TrueType/OpenType font: sfnt version {sfnt:#x}")
    tables: dict[bytes, tuple[int, int]] = {}
    for i in range(num_tables):
        tag, _chk, offset, length = struct.unpack(">4sIII", data[12 + 16 * i : 28 + 16 * i])
        tables[tag] = (offset, length)
    return tables


def decode_string(raw: bytes, pid: int, eid: int) -> str | None:
    if pid in (0, 3) or (pid == 1 and eid != 0):
        if len(raw) % 2:
            return None
        return raw.decode("utf-16-be", errors="strict")
    return raw.decode("latin-1", errors="strict")


def encode_string(text: str, pid: int, eid: int) -> bytes:
    if pid in (0, 3) or (pid == 1 and eid != 0):
        return text.encode("utf-16-be")
    return text.encode("latin-1")


def name_records(data: bytes, table: tuple[int, int]) -> list[dict]:
    base, _ = table
    fmt, count, storage_off = struct.unpack(">HHH", data[base : base + 6])
    if fmt not in (0, 1):
        sys.exit(f"unsupported name table format {fmt}")
    records = []
    for i in range(count):
        pos = base + 6 + 12 * i
        pid, eid, lid, nid, length, offset = NAME_RECORD.unpack(data[pos : pos + 12])
        records.append(
            {"pos": pos, "pid": pid, "eid": eid, "lid": lid, "nid": nid,
             "offset": base + storage_off + offset, "length": length}
        )
    return records


def table_checksum(chunk: bytes, zero_head_adjustment: bool = False) -> int:
    if zero_head_adjustment:
        chunk = chunk[:8] + b"\x00\x00\x00\x00" + chunk[12:]
    padded = chunk + b"\x00" * (-len(chunk) % 4)
    return sum(struct.unpack(f">{len(padded) // 4}I", padded)) & 0xFFFFFFFF


def file_checksum(data: bytes) -> int:
    padded = data + b"\x00" * (-len(data) % 4)
    return sum(struct.unpack(f">{len(padded) // 4}I", padded)) & 0xFFFFFFFF


def apply_replacements(text: str, replacements: list[tuple[str, str]]) -> str:
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def rewrite(data: bytearray, replacements: list[tuple[str, str]], check: bool) -> int:
    tables = read_tables(data)
    if b"name" not in tables:
        sys.exit("font has no name table")
    records = name_records(data, tables[b"name"])
    old_tokens = [old for old, _ in replacements]

    for r in records:
        raw = bytes(data[r["offset"] : r["offset"] + r["length"]])
        r["text"] = decode_string(raw, r["pid"], r["eid"])

    if check:
        found = 0
        for r in records:
            text = r["text"] or ""
            if any(t in text for t in old_tokens):
                print(f"  nameID {r['nid']} still contains an old token: {text!r}")
                found += 1
        return found

    # Records may share one storage range; rewrite each unique range once and
    # update every member's length. Different ranges that partially overlap
    # cannot be rewritten safely and abort the run.
    groups: dict[tuple[int, int], list[dict]] = {}
    for r in records:
        groups.setdefault((r["offset"], r["length"]), []).append(r)

    changed: list[tuple[int, int, bytes, list[dict], str, str]] = []
    for (offset, length), members in groups.items():
        hit = [r for r in members if r["text"] and any(t in r["text"] for t in old_tokens)]
        if not hit:
            continue
        if len(hit) != len(members):
            sys.exit(f"shared storage at offset {offset} decodes inconsistently across records")
        news = {encode_string(apply_replacements(r["text"], replacements), r["pid"], r["eid"]) for r in hit}
        if len(news) != 1:
            sys.exit(f"shared storage at offset {offset}: conflicting replacements")
        new_raw = news.pop()
        old_text = hit[0]["text"]
        if len(new_raw) > length:
            sys.exit(
                f"nameID {hit[0]['nid']}: {old_text!r} grows the string; "
                "in-place rename only supports shrinking replacements"
            )
        new_text = decode_string(new_raw, hit[0]["pid"], hit[0]["eid"])
        changed.append((offset, length, new_raw, members, old_text, new_text or ""))

    changed_offsets = {offset for offset, *_ in changed}
    ranges = sorted(groups)
    for i, (o1, l1) in enumerate(ranges):
        for o2, l2 in ranges[i + 1 :]:
            if o2 < o1 + l1 and (o1 in changed_offsets or o2 in changed_offsets):
                sys.exit(
                    f"overlapping name storage ranges {o1}:{o1 + l1} and {o2}:{o2 + l2} "
                    "cannot be rewritten safely"
                )

    rewritten = 0
    for offset, _length, new_raw, members, old_text, new_text in changed:
        data[offset : offset + len(new_raw)] = new_raw
        for r in members:
            struct.pack_into(">H", data, r["pos"] + 8, len(new_raw))
            print(f"  nameID {r['nid']}: {old_text!r} -> {new_text!r}")
            rewritten += 1

    # Re-verify no old token survived.
    for r in records:
        raw = bytes(data[r["offset"] : r["offset"] + r["length"]])
        text = decode_string(raw, r["pid"], r["eid"]) or ""
        if any(t in text for t in old_tokens):
            sys.exit(f"nameID {r['nid']} still contains an old token: {text!r}")

    # Refresh the name table checksum and head.checkSumAdjustment.
    n_off, n_len = tables[b"name"]
    struct.pack_into(">I", data, table_dir_pos(data, b"name") + 4, table_checksum(bytes(data[n_off : n_off + n_len])))

    h_off, h_len = tables[b"head"]
    dir_pos = table_dir_pos(data, b"head")
    struct.pack_into(">I", data, h_off + 8, 0)
    struct.pack_into(
        ">I", data, dir_pos + 4, table_checksum(bytes(data[h_off : h_off + h_len]), zero_head_adjustment=True)
    )
    adjustment = (0xB1B0AFBA - file_checksum(bytes(data))) & 0xFFFFFFFF
    struct.pack_into(">I", data, h_off + 8, adjustment)
    return rewritten


def table_dir_pos(data: bytes, tag: bytes) -> int:
    num_tables = struct.unpack(">H", data[4:6])[0]
    for i in range(num_tables):
        pos = 12 + 16 * i
        if data[pos : pos + 4] == tag:
            return pos
    sys.exit(f"table {tag!r} missing")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("font", help="path to the TrueType/OpenType font file")
    parser.add_argument(
        "--replace",
        action="append",
        default=[],
        metavar="OLD=NEW",
        help="rename token inside name table strings; repeatable, applied longest-first",
    )
    parser.add_argument("--check", action="store_true", help="report leftover OLD tokens without writing")
    args = parser.parse_args()

    replacements: list[tuple[str, str]] = []
    for spec in args.replace:
        if "=" not in spec:
            sys.exit(f"--replace expects OLD=NEW, got {spec!r}")
        old, new = spec.split("=", 1)
        if not old or not new:
            sys.exit(f"--replace expects non-empty OLD and NEW, got {spec!r}")
        replacements.append((old, new))
    if not replacements:
        sys.exit("at least one --replace OLD=NEW is required")
    replacements.sort(key=lambda pair: len(pair[0]), reverse=True)

    with open(args.font, "rb") as fh:
        data = bytearray(fh.read())

    if args.check:
        leftover = rewrite(data, replacements, check=True)
        if leftover:
            sys.exit(f"{leftover} name record(s) still carry old family strings")
        print(f"{args.font}: no old family strings remain")
        return

    changed = rewrite(data, replacements, check=False)
    with open(args.font, "wb") as fh:
        fh.write(data)
    print(f"{args.font}: {changed} name record(s) rewritten")


if __name__ == "__main__":
    main()
