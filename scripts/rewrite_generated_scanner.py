#!/usr/bin/env python3
"""Adapt a generated scanner to current string indexing.

Older cparsegen output calls String.slice and String.byteAt. Those methods
are gone. This rewrite turns byte reads into indexes and half-open slices
into an inclusive span that stays empty when the exclusive end is not after
the start. Output that already uses indexing is left unchanged.
"""

import pathlib
import sys

HELPER = """    int64 byteSpanBound(int64 value, int64 length) {
        int64 index = value
        if (index < 0) { index = index + length }
        if (index < 0) { return(0) }
        if (index > length) { return(length) }
        return(index)
    }
    String byteSpan(String text, int64 first, int64 last) {
        int64 lower = byteSpanBound(first, text.length)
        int64 end = byteSpanBound(last, text.length)
        if (end <= lower) { return("") }
        return(text[lower..(end - 1)])
    }
"""


def _ident(ch):
    return ch.isalnum() or ch == "_"


def _skip_back(text, index):
    while index >= 0 and text[index] in " \t\r\n":
        index -= 1
    return index


def _match_back(text, index, opener, closer):
    depth = 0
    while index >= 0:
        if text[index] == opener:
            depth += 1
        elif text[index] == closer:
            depth -= 1
            if depth == 0:
                return index - 1
        index -= 1
    raise ValueError("unbalanced delimiter")


def _receiver_start(text, dot):
    index = _skip_back(text, dot - 1)
    while True:
        if index >= 0 and _ident(text[index]):
            while index >= 0 and _ident(text[index]):
                index -= 1
        elif index >= 0 and text[index] == ")":
            index = _match_back(text, index, ")", "(")
        elif index >= 0 and text[index] == "]":
            index = _match_back(text, index, "]", "[")
        else:
            return index + 1
        previous = _skip_back(text, index)
        if previous >= 0 and text[previous] == ".":
            index = _skip_back(text, previous - 1)
            continue
        return index + 1


def _arguments(text, open_paren):
    index = open_paren + 1
    depth = 1
    start = index
    args = []
    while index < len(text):
        ch = text[index]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                args.append(text[start:index].strip())
                return args, index
        elif ch == "," and depth == 1:
            args.append(text[start:index].strip())
            start = index + 1
        index += 1
    raise ValueError("unclosed call")


def rewrite(text):
    if ".slice(" not in text and ".byteAt(" not in text:
        return text
    replacements = []
    index = 0
    in_string = None
    while index < len(text):
        if in_string:
            if in_string == '"' and text[index] == "\\":
                index += 2
                continue
            if text[index] == in_string:
                in_string = None
            index += 1
            continue
        if text.startswith("//", index) or (
                text[index] == "#" and (index == 0 or text[index - 1] == "\n")):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end + 1
            continue
        if text[index] in "\"'":
            in_string = text[index]
            index += 1
            continue
        kind = None
        if text.startswith(".byteAt(", index):
            kind = "byte"
            name_length = 8
        elif text.startswith(".slice(", index):
            kind = "slice"
            name_length = 7
        if kind is None:
            index += 1
            continue
        args, close = _arguments(text, index + name_length - 1)
        start = _receiver_start(text, index)
        receiver = text[start:index].strip()
        if kind == "byte":
            if len(args) != 1:
                raise ValueError("byteAt expects one argument")
            replacement = f"{receiver}[{args[0]}]"
        else:
            if len(args) != 2:
                raise ValueError("slice expects two arguments")
            replacement = f"byteSpan({receiver}, {args[0]}, {args[1]})"
        replacements.append((start, close + 1, replacement))
        index = close + 1
    pieces = []
    cursor = 0
    for start, end, replacement in replacements:
        pieces.append(text[cursor:start])
        pieces.append(replacement)
        cursor = end
    updated = "".join(pieces) + text[cursor:]
    if "byteSpan(" in updated and "String byteSpan(" not in updated:
        needle = "class InputScanner {\n"
        if needle not in updated:
            raise ValueError("generated scanner has no InputScanner class")
        updated = updated.replace(needle, needle + HELPER + "\n", 1)
    return updated


def main(argv):
    if len(argv) != 2:
        print("usage: rewrite_generated_scanner.py PARSER.cw", file=sys.stderr)
        return 2
    path = pathlib.Path(argv[1])
    original = path.read_text()
    updated = rewrite(original)
    if updated != original:
        path.write_text(updated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
