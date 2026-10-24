#!/usr/bin/env python3
"""Adapt cparsegen's generated Cwhip parser to the numeric-v2 type names."""

from pathlib import Path
import re
import sys


source = Path(sys.argv[1])
generated = source.read_text()
source.write_text(re.sub(r"\bint\b", "int64", generated))
