#!/usr/bin/env python3
"""Checks QML files for assignments to properties a component cannot have.

Quickshell refuses to load the *entire* config over a single unknown binding,
and no other checker here can see this: the shell does not type check at runtime
before it compiles, and the other two scripts do not resolve types at all.

Only the shape that can be decided without Qt is reported: a component whose
inheritance chain bottoms out in `QtObject`. QtObject contributes no properties,
so a data holder such as `MenuItem`, `PageRegistry`, `NexusState` or
`WidgetCatalog` has exactly what it declares itself. Binding `visible`,
`enabled`, `x`, `width` or any other part of Item's API on one of those is
always an error — the shape that cost three separate start-up failures during
the desktop widgets port (see DESKTOP_WIDGETS_VERIFICATION.md, 0.6).

Components rooted in a visual Qt type are deliberately left alone: they inherit
properties this script cannot know without Qt. That is qmllint's job, and 0.6
requires it.

By default every *.qml under the repo root is checked, skipping build trees,
hidden directories and nested checkouts. Pass --file to check a single file, or
--file - to check a buffer read from stdin. Findings go to stderr, and the exit
status is 1 when there are any (2 for a missing file).
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

RED = "\033[0;31m"
YELLOW = "\033[0;33m"
BOLD = "\033[1m"
RESET = "\033[0m"

REPO_ROOT = Path(__file__).resolve().parent.parent

RULE = "undeclared-property"

# The root object of a file: `TypeName {` starting at column 0. This is the
# object whose API the file defines.
ROOT_OBJECT = re.compile(r"^([A-Z][\w.]*)\s*\{\s*$")
# Any object, at any indentation: `TypeName {` alone on its line, so a binding
# whose value is an inline object (`contentItem: Rect {`) never matches. Used to
# find the places the API is consumed, most of which are children.
OBJECT = re.compile(r"^(\s*)([A-Z][\w.]*)\s*\{\s*$")
# A property assignment at the object's own level: `name: ...`.
ASSIGNMENT = re.compile(r"^(\s+)([A-Za-z_]\w*)\s*:")
# A property declaration; the name is the word before the colon, or the last
# word when there is no initializer (`property string text`). A type with
# whitespace in it (`list<MenuItem>`, `QtObject`) is skipped by the non-greedy
# match on the last word.
PROPERTY = re.compile(r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w.]+\s*(?:<[^>]*>)?\s*(\w+)\s*(?::.*)?$")
SIGNAL = re.compile(r"^\s*signal\s+(\w+)")
# Signal handlers (onClicked) are not property assignments.
HANDLER = re.compile(r"^on[A-Z]")
# Available on every QObject.
UNIVERSAL = frozenset({"id", "objectName"})


def disable_colour() -> None:
    """Blank every escape code so the report is plain text."""
    global RED, YELLOW, BOLD, RESET
    RED = YELLOW = BOLD = RESET = ""


@dataclass
class Violation:
    path: str
    line: int
    col: int
    name: str
    type_name: str
    declared: tuple[str, ...]

    def __str__(self) -> str:
        known = ", ".join(self.declared) if self.declared else "nothing"
        return (
            f"{RED}[{RULE}]{RESET} {self.path}:{self.line}:{self.col}: "
            f'{BOLD}"{self.name}"{RESET} is not a property of {BOLD}{self.type_name}{RESET}, '
            f"which is rooted in QtObject and declares {known}"
        )


@dataclass
class Component:
    """One *.qml file's root object: the type it instantiates, and its API."""

    root: str
    declared: set[str] = field(default_factory=set)


def code_lines(lines: list[str]) -> list[str]:
    """Strip string literals and comments, keeping positions and braces.

    Braces inside strings and comments must not count towards nesting, and a
    block comment can hide them across lines.
    """
    out: list[str] = []
    in_block = False
    for line in lines:
        buf: list[str] = []
        quote = ""
        i = 0
        while i < len(line):
            ch = line[i]
            if in_block:
                if ch == "*" and line[i + 1 : i + 2] == "/":
                    in_block = False
                    i += 2
                    continue
                i += 1
                continue
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = ""
                    buf.append(" ")
                i += 1
                continue
            if ch in "\"'`":
                quote = ch
                buf.append(" ")
                i += 1
                continue
            if ch == "/" and line[i + 1 : i + 2] in ("/", "*"):
                if line[i + 1] == "/":
                    break
                in_block = True
                i += 2
                continue
            buf.append(ch)
            i += 1
        out.append("".join(buf))
    return out


def block_end(code: list[str], start: int) -> int:
    """Index of the line closing the object that opens at start."""
    depth = 0
    j = start
    while j < len(code):
        depth += code[j].count("{") - code[j].count("}")
        if depth == 0 and j > start:
            break
        j += 1
    return min(j, len(code) - 1)


def blocks(code: list[str]):
    """Yield (start, end, type name) for every object in the file.

    Nested objects are yielded by their own iteration; a block's assignments are
    only ever compared at its own level, so an object's ancestors and children
    are both out of scope there.
    """
    for i, line in enumerate(code):
        match = OBJECT.match(line)
        if match:
            yield i, block_end(code, i), match.group(2).split(".")[-1]


def root_object(code: list[str]):
    """Yield (start, end, type name) for a file's root object, which is first."""
    for i, line in enumerate(code):
        match = ROOT_OBJECT.match(line)
        if match:
            yield i, block_end(code, i), match.group(1).split(".")[-1]
            return


def declared_names(code: list[str], start: int, end: int) -> set[str]:
    """Collect the properties and signals declared by one object."""
    names: set[str] = set()
    depth = 0
    for i in range(start, end + 1):
        if i > start and depth == 1:
            match = PROPERTY.match(code[i])
            if match:
                names.add(match.group(1))
            else:
                match = SIGNAL.match(code[i])
                if match:
                    names.add(match.group(1))
        depth += code[i].count("{") - code[i].count("}")
    return names


def source_files() -> list[Path]:
    """Every *.qml under the repo root, minus trees that are not source."""
    nested = {path.parent for path in REPO_ROOT.glob("*/.git")}
    files: list[Path] = []
    for path in sorted(REPO_ROOT.rglob("*.qml")):
        parts = path.relative_to(REPO_ROOT).parts
        if "build" in parts or any(part.startswith(".") for part in parts[:-1]):
            continue
        if any(path.parent in nested or nested_root in path.parents for nested_root in nested):
            continue
        files.append(path)
    return files


def read(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def build_table(files: list[Path]) -> dict[str, Component]:
    """Map every component name to its API, merging files that share a name.

    The merge is a union: duplicates only make the table more permissive, which
    risks a missed finding, never a wrong one.
    """
    table: dict[str, Component] = {}
    for path in files:
        code = code_lines(read(path))
        # A QML component is named after its file; its root object's type is the
        # one it extends.
        name = path.stem
        for start, end, root_type in root_object(code):
            names = declared_names(code, start, end)
            component = table.get(name)
            if component is None:
                table[name] = Component(root_type, names)
            else:
                component.declared |= names
    return table


def resolve(type_name: str, table: dict[str, Component]) -> tuple[list[str], str]:
    """Follow the inheritance chain to the first type the repo does not own."""
    chain: list[str] = []
    current = type_name
    while current in table and current not in chain:
        chain.append(current)
        current = table[current].root
    return chain, current


def check_lines(lines: list[str], name: str, table: dict[str, Component]) -> list[Violation]:
    code = code_lines(lines)
    violations: list[Violation] = []
    for start, end, type_name in blocks(code):
        if type_name not in table:
            continue
        chain, terminal = resolve(type_name, table)
        if terminal != "QtObject":
            # A visual Qt ancestor brings properties this script cannot see.
            continue
        known: set[str] = set()
        for entry in chain:
            known |= table[entry].declared
        depth = 0
        for i in range(start, end + 1):
            if i > start and depth == 1:
                match = ASSIGNMENT.match(lines[i])
                if match:
                    property_name = match.group(2)
                    if property_name not in known and property_name not in UNIVERSAL and not HANDLER.match(property_name):
                        violations.append(
                            Violation(name, i + 1, match.start(2) + 1, property_name, type_name, tuple(sorted(known - UNIVERSAL)))
                        )
            depth += code[i].count("{") - code[i].count("}")
    return violations


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--file",
        metavar="PATH",
        help="check only this file instead of every *.qml under the repo root; "
        "pass - to read the source from stdin (for unsaved editor buffers)",
    )
    return parser.parse_args(argv)


def report(violations: list[Violation], checked: int) -> int:
    err = sys.stderr
    print(f"{BOLD}Checking {checked} source file(s) for undeclared properties...{RESET}\n", file=err)
    for violation in violations:
        print(violation, file=err)
    print(file=err)
    if not violations:
        print(f"{BOLD}No issues found.{RESET}", file=err)
        return 0
    print(f"{BOLD}Found {len(violations)} error(s).{RESET}", file=err)
    return 1


def main() -> int:
    args = parse_args()

    if not sys.stderr.isatty():
        disable_colour()

    table = build_table(source_files())

    if args.file == "-":
        violations = check_lines(sys.stdin.read().splitlines(), "<stdin>", table)
        return report(violations, 1)

    if args.file:
        path = Path(args.file)
        if not path.is_file():
            print(f"{RED}no such file: {path}{RESET}", file=sys.stderr)
            return 2
        violations = check_lines(read(path), rel(path), table)
        return report(violations, 1)

    files = source_files()
    violations = [v for path in files for v in check_lines(read(path), rel(path), table)]
    return report(violations, len(files))


if __name__ == "__main__":
    sys.exit(main())
