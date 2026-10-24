"""Conformance checks for the installed CVM bytecode package."""

import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GOLDEN = bytes.fromhex(
    "43 56 4d 00 01 00 00 00 20 00 00 00 07 00 00 00 "
    "00 00 00 00 20 00 00 00 b7 00 00 00 00 00 00 00 "
    "01 00 00 00 90 00 00 00 06 00 00 00 06 00 00 00 "
    "02 00 00 00 96 00 00 00 1c 00 00 00 01 00 00 00 "
    "03 00 00 00 b2 00 00 00 00 00 00 00 00 00 00 00 "
    "04 00 00 00 b2 00 00 00 00 00 00 00 00 00 00 00 "
    "05 00 00 00 b2 00 00 00 00 00 00 00 00 00 00 00 "
    "06 00 00 00 b2 00 00 00 00 00 00 00 00 00 00 00 "
    "07 00 00 00 b2 00 00 00 05 00 00 00 05 00 00 00 "
    "01 2a 00 00 00 1f "
    "00 00 00 00 00 00 00 00 06 00 00 00 00 00 00 00 "
    "00 00 00 00 01 00 00 00 01 00 00 00 "
    "6d 61 69 6e 00"
)


def decode_golden(data):
    """Decode the normative container independently of the CWhip reader."""
    magic, major, minor, header_size, flags, section_count, reserved, entry, directory, size, tail = (
        struct.unpack_from("<4sHHHHHHIIII", data)
    )
    if (magic, major, minor, header_size, flags, reserved, directory, size, tail) != (
        b"CVM\0", 1, 0, 32, 0, 0, 32, len(data), 0
    ):
        raise AssertionError("unexpected golden header")
    if section_count != 7 or entry != 0:
        raise AssertionError("unexpected section count or entry index")
    sections = {}
    for index in range(section_count):
        kind, section_flags, offset, length, count = struct.unpack_from(
            "<HHIII", data, 32 + index * 16
        )
        sections[kind] = (section_flags, offset, length, count)
    if sections != {
        1: (0, 144, 6, 6),
        2: (0, 150, 28, 1),
        3: (0, 178, 0, 0),
        4: (0, 178, 0, 0),
        5: (0, 178, 0, 0),
        6: (0, 178, 0, 0),
        7: (0, 178, 5, 5),
    }:
        raise AssertionError("unexpected section directory")
    name, code_offset, code_length, type_offset, params, locals_, stack, func_flags, result_type, padding = (
        struct.unpack_from("<IIIIHHHHB3s", data, 150)
    )
    if (name, code_offset, code_length, type_offset, params, locals_, stack, func_flags, result_type, padding) != (
        0, 0, 6, 0, 0, 0, 1, 0, 1, b"\0\0\0"
    ):
        raise AssertionError("unexpected function record")
    return {
        "code": data[144:150],
        "function_name": data[178:183].split(b"\0", 1)[0],
    }


class CvmLibraryTests(unittest.TestCase):
    def test_installed_package_consumer_and_golden(self):
        spec = (ROOT / "doc/BYTECODE-ASSEMBLY.md").read_text()
        golden_section = spec.split("### 2.3 Numeric golden example", 1)[1].split(
            "\n### ", 1
        )[0]
        published_header = bytes.fromhex(
            golden_section.split("```text\n", 1)[1].split("\n```", 1)[0]
        )
        self.assertEqual(published_header, GOLDEN[:32])

        sdk = os.environ.get("CWHIP_SDK")
        if not sdk:
            self.skipTest("CWHIP_SDK must identify the installed Cwhip SDK")
        compiler = Path(sdk) / "bin/cwhip"
        if not compiler.is_file():
            self.fail(f"Cwhip compiler not found: {compiler}")

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            install_prefix = root / "installed-cvm"
            subprocess.run(
                ["cmake", "--install", os.environ["CVM_BUILD_DIR"], "--prefix", str(install_prefix)],
                check=True,
                capture_output=True,
                text=True,
            )
            installed_package = install_prefix / "share/cwhip/modules/cvm"
            self.assertTrue((installed_package / "1.0.0/cwhip-package.toml").is_file())
            self.assertIn(
                'sdk-abi = "numeric-v2"',
                (installed_package / "1.0.0/cwhip-package.toml").read_text(),
            )
            consumer = root / "external-consumer"
            module_path = consumer / "modules/cvm"
            module_path.parent.mkdir(parents=True)
            shutil.copytree(installed_package, module_path)
            consumer_source = consumer / "consumer.cw"
            shutil.copy2(ROOT / "tests/cvm_consumer.cw", consumer_source)
            executable = root / "cvm-consumer"
            env = os.environ.copy()
            env["CWHIP_SDK"] = sdk
            subprocess.run(
                [
                    str(compiler),
                    "-M", str(consumer / "modules"),
                    str(consumer_source),
                    "-o", str(executable),
                ],
                cwd=consumer,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            result = subprocess.run(
                [str(executable)],
                cwd=consumer,
                capture_output=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
            self.assertEqual(result.stderr, bytes(range(256)))
            self.assertEqual(result.stdout, GOLDEN)
            self.assertEqual(len(GOLDEN), 183)
            self.assertEqual(
                decode_golden(result.stdout),
                {"code": bytes.fromhex("01 2a 00 00 00 1f"), "function_name": b"main"},
            )


if __name__ == "__main__":
    unittest.main()
