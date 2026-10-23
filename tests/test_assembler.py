"""Installed assembler conformance; expected bytes never use the CVM encoder."""

import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest

from test_cvm_library import GOLDEN, decode_golden


ROOT = Path(__file__).resolve().parents[1]
PREAMBLE = ".version 1.0\n.entry main\n"
MINIMAL = (ROOT / "tests/fixtures/minimal.asm").read_text()


def independent_container(code, funcs, types=b"", globals_=b"", arrays=b"", data=b"", strings=b"main\0", entry=0):
    sections = [code, funcs, types, globals_, arrays, data, strings]
    counts = [len(code), len(funcs) // 28, len(types), len(globals_) // 12,
              len(arrays) // 20, len(data), len(strings)]
    offset = 144
    directory = bytearray()
    for kind, (section, count) in enumerate(zip(sections, counts), 1):
        directory += struct.pack("<HHIII", kind, 0, offset, len(section), count)
        offset += len(section)
    header = struct.pack("<4sHHHHHHIIII", b"CVM\0", 1, 0, 32, 0, 7, 0, entry, 32, offset, 0)
    return header + directory + b"".join(sections)


def function(name, start, length, type_start=0, params=0, locals_=0, stack=1, result=1):
    return struct.pack("<IIIIHHHHB3s", name, start, length, type_start,
                       params, locals_, stack, 0, result, b"\0\0\0")


def sections(binary):
    """Read directory independently and insist on a packed, exact file."""
    assert binary[:4] == b"CVM\0"
    assert struct.unpack_from("<I", binary, 24)[0] == len(binary)
    offset = 144
    result = {}
    for index in range(7):
        kind, flags, start, length, count = struct.unpack_from("<HHIII", binary, 32 + index * 16)
        assert kind == index + 1 and flags == 0 and start == offset
        result[kind] = binary[start:start + length]
        offset += length
    assert offset == len(binary)
    return result


@unittest.skipUnless(os.environ.get("CWHIP_SDK") and os.environ.get("CVM_BUILD_DIR"),
                     "requires a configured CVM build and installed binary-I/O SDK")
class AssemblerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.prefix = cls.root / "install"
        subprocess.run(["cmake", "--install", os.environ["CVM_BUILD_DIR"],
                        "--prefix", str(cls.prefix)], check=True, capture_output=True)
        cls.assembler = cls.prefix / "bin/cvm-as"
        cls.env = {"PATH": "/usr/bin:/bin", "HOME": str(cls.root)}
        # Compile a separate installed-package consumer; no source-tree imports.
        consumer = cls.root / "consumer"
        consumer.mkdir()
        shutil.copytree(cls.prefix / "share/cwhip/modules", consumer / "modules")
        shutil.copy2(ROOT / "tests/file_consumer.cw", consumer / "consumer.cw")
        sdk = Path(os.environ["CWHIP_SDK"])
        cls.consumer = cls.root / "file-consumer"
        result = subprocess.run([str(sdk / "bin/cwhip"), "-M", str(consumer / "modules"),
                                 str(consumer / "consumer.cw"), "-o", str(cls.consumer)],
                                cwd=consumer, capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)

    def setUp(self):
        self.case = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(self.case.cleanup)
        self.work = Path(self.case.name)
        self.input = self.work / "input.asm"
        self.output = self.work / "output.cvm"

    def assemble(self, source, success=True, output=None):
        self.input.write_bytes(source if isinstance(source, bytes) else source.encode())
        result = subprocess.run([str(self.assembler), str(self.input), "-o",
                                 str(output or self.output)],
                                cwd=self.work, env=self.env, capture_output=True, timeout=30)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
            self.assertEqual(result.stdout, b"")
            self.assertEqual(result.stderr, b"")
            binary = (output or self.output).read_bytes()
            # Every accepted fixture must reload through the SDK adapter and
            # pass the existing public structural validator.
            loaded = subprocess.run([str(self.consumer), str(self.work / "bytes.bin"),
                                     str(output or self.output)],
                                    cwd=self.work, env=self.env, capture_output=True, timeout=30)
            self.assertEqual(loaded.returncode, 0, loaded.stderr.decode(errors="replace"))
            self.assertEqual((self.work / "bytes.bin").read_bytes(), bytes(range(256)))
            sections(binary)
            return binary
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertTrue(result.stderr)
        return result.stderr.decode(errors="replace")

    def reject(self, source, message):
        self.output.write_bytes(b"do not truncate on assembly failure")
        diagnostic = self.assemble(source, success=False)
        self.assertIn(message, diagnostic)
        self.assertRegex(diagnostic, re.escape(str(self.input)) + r":\d+:\d+: ")
        self.assertEqual(self.output.read_bytes(), b"do not truncate on assembly failure")
        return diagnostic

    def test_minimal_exact_published_golden(self):
        binary = self.assemble(MINIMAL)
        self.assertEqual(binary, GOLDEN)
        self.assertEqual(decode_golden(binary)["code"], b"\x01\x2a\0\0\0\x1f")
        self.assertEqual(self.assemble(MINIMAL.replace("\n", "\r\n").rstrip()), GOLDEN)

    def test_approved_hello_complete_golden(self):
        source = (ROOT / "tests/fixtures/hello.asm").read_text()
        spec = (ROOT / "doc/BYTECODE-ASSEMBLY.md").read_text()
        self.assertIn(source.strip(), spec)
        code = bytes.fromhex("07 00 00 01 00 00 00 00 01 0c 00 00 00 21 02 1a "
                             "01 14 00 00 00 01 16 00 00 00 0b 1f")
        array = struct.pack("<IHBBIII", 5, 65535, 2, 1, 13, 0, 0)
        expected = independent_container(code, function(0, 0, len(code), stack=3),
                                         arrays=array, data=b"Hello, CVM!\n\0",
                                         strings=b"main\0greeting\0")
        self.assertEqual(self.assemble(source), expected)

    def test_approved_loop_complete_golden(self):
        source = (ROOT / "tests/fixtures/loop.asm").read_text()
        self.assertIn(source.strip(), (ROOT / "doc/BYTECODE-ASSEMBLY.md").read_text())
        loop = bytes.fromhex(
            "01 00 00 00 00 04 01 00 1a 01 00 00 00 00 04 02 00 1a "
            "03 01 00 03 00 00 14 1c 3b 00 00 00 "
            "03 02 00 03 01 00 0b 04 02 00 1a "
            "03 01 00 01 01 00 00 00 0b 04 01 00 1a 1b 12 00 00 00 03 02 00 1f"
        )
        main = bytes.fromhex("01 0a 00 00 00 1d 00 00 21 00 01 00 00 00 00 1f")
        funcs = function(0, 0, 63, params=1, locals_=2, stack=2)
        funcs += function(7, 63, 16, type_start=3)
        self.assertEqual(self.assemble(source), independent_container(
            loop + main, funcs, types=b"\1\1\1", strings=b"sum_to\0main\0", entry=1))

    def test_forward_symbols_types_and_initializers(self):
        source = PREAMBLE + r"""
.func main() -> i32
    .local x: u8
    .local f: file
    .array local: i32[3] = {-2147483648, +0x7fffffff}
    jmp next
next:
    const.u8 '\xff'
    stloc x
    pop
    ldglobal later
    stglobal later
    pop
    array bytes
    const.i32 0
    const.i32 1
    sys stdout_write
    pop
    call forward
    ret.i32
.end
.global later: i32 = -0x80000000
.global byte: u8 = '\x80'
.array bytes: u8[4] = {0, 128, 255}
.array zero: u8[2]
.array empty: i32[2] = {}
.func forward() -> i32
    array local_unused
    alen
    pop
    const.i32 42
    ret.i32
.end
.array local_unused: i32[1]
"""
        binary = self.assemble(source)
        parsed = sections(binary)
        self.assertEqual(parsed[3], b"\2\3")
        self.assertEqual(parsed[6], struct.pack("<iii", -2147483648, 2147483647, 0)
                         + bytes([0, 128, 255, 0]) + bytes(8))
        self.assertEqual(struct.unpack_from("<I", parsed[1], 1)[0], 5)
        # First array is owned by main, zero initializer is represented by sentinel.
        self.assertEqual(struct.unpack_from("<H", parsed[5], 4)[0], 0)
        self.assertEqual(struct.unpack_from("<I", parsed[5], 2 * 20 + 12)[0], 0xffffffff)
        self.assertEqual(struct.unpack_from("<i", parsed[4], 8)[0], -2147483648)
        self.assertEqual(struct.unpack_from("<i", parsed[4], 20)[0], 128)

    def test_all_opcode_and_service_names_independent_bytes(self):
        # Unreachable instructions are encoding-checked but not stack verified.
        # Literal bytes below are independent of the public opcode schema.
        source = PREAMBLE + """.global g: i32 = 0
.array a: u8[1]
.func main() -> i32
.local x: i32
const.i32 42
ret.i32
nop
const.u8 255
ldloc x
stloc x
ldglobal g
stglobal g
array a
alen
aget
aset
add.i32
sub.i32
mul.i32
div.i32
rem.i32
neg.i32
eq.i32
ne.i32
lt.i32
le.i32
gt.i32
ge.i32
to.u8
to.i32
dup
pop
jmp done
jz done
call nothing
"""
        services = ["stdout_i32", "stdout_byte", "stdout_write", "stdin_byte",
                    "file_open_read", "file_open_write", "file_read", "file_write", "file_close",
                    "file_open", "file_read_handle", "file_write_handle", "file_close_handle"]
        source += "".join(f"sys {name}\n" for name in services)
        source += """done:
ret.i32
.end
.func nothing() -> void
ret
.end
.func byte(p:u8) -> u8
ldloc p
ret.u8
.end
.func handle(f:file) -> file
ldloc f
ret.file
.end
"""
        binary = self.assemble(source)
        code = sections(binary)[1]
        prefix = bytes.fromhex(
            "01 2a 00 00 00 1f 00 02 ff 03 00 00 04 00 00 05 00 00 "
            "06 00 00 07 00 00 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 "
            "14 15 16 17 18 19 1a"
        )
        end = len(prefix) + 5 + 5 + 3 + 26
        expected = prefix + b"\x1b" + struct.pack("<I", end)
        expected += b"\x1c" + struct.pack("<I", end) + b"\x1d\1\0"
        expected += b"".join(bytes([0x21, value]) for value in range(13))
        expected += bytes.fromhex("1f 1e 03 00 00 20 03 00 00 22")
        self.assertEqual(code, expected)

    def test_escapes_utf8_and_semicolon_preservation(self):
        source = PREAMBLE + r""".array text: u8[20] = "\\\"\'\n\r\t\0\x00\x80\xff;"
.array utf: u8[8] = "é😊"
.func main() -> i32
const.i32 '\''
ret.i32 ; UTF-8 comment: café
.end
"""
        parsed = sections(self.assemble(source))
        self.assertEqual(parsed[6], b"\\\"'\n\r\t\0\0\x80\xff;\0" + bytes(8)
                         + "é😊".encode() + bytes(2))
        self.assertEqual(parsed[1], bytes.fromhex("01 27 00 00 00 1f"))
        all_escapes = "".join(f"\\x{value:02x}" for value in range(256))
        source = PREAMBLE + f'.array all: u8[257] = "{all_escapes}"\n.func' + MINIMAL.split(".func", 1)[1]
        self.assertEqual(sections(self.assemble(source))[6], bytes(range(256)) + b"\0")
        invalid = '.array text: u8[20] = "é\\q"'
        diagnostic = self.reject(PREAMBLE + invalid + "\n", "unknown escape")
        expected_column = invalid.encode().index(b"q") + 1
        self.assertIn(f":3:{expected_column}:", diagnostic)

    def test_reachable_service_arities_stack_maxima_and_forward_calls(self):
        source = PREAMBLE + """.array bytes: u8[8]
.func main() -> i32
call input
ret.i32
.end
.func input() -> i32
sys stdin_byte
ret.i32
.end
.func open() -> file
array bytes
sys file_open_read
ret.file
.end
.func create() -> file
array bytes
sys file_open_write
ret.file
.end
.func read(f:file) -> i32
ldloc f
array bytes
const.i32 0
const.i32 8
sys file_read
ret.i32
.end
.func write(f:file) -> i32
ldloc f
array bytes
const.i32 0
const.i32 8
sys file_write
ret.i32
.end
.func close(f:file) -> void
ldloc f
sys file_close
ret
.end
.func byte() -> void
const.u8 65
sys stdout_byte
ret
.end
.func nothing() -> void
ret
.end
"""
        funcs = sections(self.assemble(source))[2]
        self.assertEqual([struct.unpack_from("<H", funcs, i * 28 + 20)[0]
                          for i in range(9)], [1, 1, 1, 1, 4, 4, 1, 1, 0])
        integer_source = PREAMBLE + """.array bytes: u8[8]
.func main() -> i32
array bytes
array bytes
sys file_open
ret.i32
.end
.func read(h:i32) -> i32
ldloc h
array bytes
const.i32 8
sys file_read_handle
ret.i32
.end
.func write(h:i32) -> i32
ldloc h
array bytes
const.i32 8
sys file_write_handle
ret.i32
.end
.func close(h:i32) -> void
ldloc h
sys file_close_handle
ret
.end
"""
        funcs = sections(self.assemble(integer_source))[2]
        self.assertEqual([struct.unpack_from("<H", funcs, i * 28 + 20)[0]
                          for i in range(4)], [2, 3, 3, 1])
        # A matching depth is not proof of a matching guest value type.
        self.assemble(MINIMAL.replace("const.i32 42", "const.u8 42"))

    def test_later_function_branch_base_numeric_edges_and_many_lines(self):
        source = PREAMBLE + """.func first() -> void
ret
.end
.func main() -> i32
jmp later
later:
const.i32 -2147483648
pop
const.i32 +0x7fffffff
ret.i32
.end
"""
        parsed = sections(self.assemble(source))
        self.assertEqual(parsed[1], bytes.fromhex(
            "1e 1b 05 00 00 00 01 00 00 00 80 1a 01 ff ff ff 7f 1f"))
        self.assertEqual(struct.unpack_from("<I", parsed[2], 28 + 4)[0], 1)
        source = MINIMAL.replace("    const.i32", "nop\n" * 2000 + "    const.i32")
        parsed = sections(self.assemble(source))
        self.assertEqual(parsed[1], bytes(2000) + GOLDEN[144:150])
        self.assertEqual(struct.unpack_from("<H", parsed[2], 20)[0], 1)

    def test_invalid_counts_ranges_types_and_escapes(self):
        cases = [
            ("const.i32", "wrong operand count"),
            ("nop 1", "wrong operand count"),
            ("const.i32 1, 2", "wrong operand count"),
            ("const.i32 x", "expected literal"),
            ("const.i32 2147483648", "out of range"),
            ("const.i32 -2147483649", "out of range"),
            ("const.i32 999999999999999999999999", "out of range"),
            ("const.u8 -1", "out of range"),
            ("const.u8 256", "out of range"),
            ("ldloc 0", "expected named"),
            ("jmp 0", "expected named"),
            ("sys 0", "expected named"),
            ("sys nonexistent", "unknown service"),
            ("NOP", "unknown instruction"),
            (r"const.u8 '\q'", "unknown escape"),
            (r"const.u8 '\x0'", "two hexadecimal"),
            (r"const.u8 '\xgg'", "invalid hexadecimal"),
            ("const.u8 'ab'", "one byte"),
            ("const.u8 'é'", "one byte"),
        ]
        for instruction, message in cases:
            with self.subTest(instruction=instruction):
                self.reject(PREAMBLE + f".func main() -> i32\n{instruction}\n.end\n", message)
        declarations = [
            (".array a: file[1]", "i32 or u8"),
            (".array a: u8[0]", "capacity"),
            (".array a: u8[-1]", "capacity"),
            (".array a: u8[4294967296]", "out of range"),
            (".array a: i32[4294967295] = {}", "byte length"),
            (".array a: u8[1] = {0, 1}", "exceeds capacity"),
            ('.array a: u8[1] = "a"', "including NUL"),
            ('.array a: i32[2] = "a"', "requires u8"),
            (".array a: u8[1] = {256}", "out of range"),
            (".global g: file = 0", "i32 or u8"),
            (".global g: void = 0", "invalid type"),
            (".global g: u8 = -1", "out of range"),
            (".global g: i32 = 2147483648", "out of range"),
        ]
        for declaration, message in declarations:
            with self.subTest(declaration=declaration):
                self.reject(PREAMBLE + declaration + "\n" + MINIMAL.split(".entry main\n")[1], message)

    def test_duplicate_and_unresolved_names(self):
        bodies = [
            (".local x: i32\n.local x: i32\n", "duplicate"),
            ("x:\nx:\nconst.i32 0\nret.i32\n", "duplicate"),
            ("jmp absent\n", "unresolved symbol 'absent'"),
            ("call absent\n", "unresolved symbol 'absent'"),
            ("ldloc absent\n", "unresolved symbol 'absent'"),
            ("ldglobal absent\n", "unresolved symbol 'absent'"),
            ("array absent\n", "unresolved symbol 'absent'"),
            ("jmp last\nlast:\n", "past function end"),
        ]
        for body, message in bodies:
            with self.subTest(body=body):
                self.reject(PREAMBLE + ".func main() -> i32\n" + body + ".end\n", message)
        for declaration in (".global g: i32 = 0\n", ".array a: i32[1]\n"):
            self.reject(PREAMBLE + declaration * 2 + MINIMAL.split(".entry main\n")[1], "duplicate")
        self.reject(MINIMAL + ".func main() -> void\nret\n.end\n", "duplicate")
        self.reject(PREAMBLE + ".func main(x:i32,x:u8) -> i32\nconst.i32 0\nret.i32\n.end", "duplicate")
        self.reject(MINIMAL.replace("const.i32 42", "array owned")
                    + ".func f() -> void\n.array owned: u8[1]\nret\n.end\n",
                    "another function")
        # Labels may be reused in different functions.
        self.assemble(MINIMAL.replace("    const", "again:\n    const")
                      + ".func f() -> void\nagain:\nret\n.end\n")

    def test_structure_diagnostics_and_stack_metadata(self):
        cases = [
            ("", "missing"),
            ("; only comment\n", "missing"),
            (".entry main\n", "start with"),
            (".version 2.0\n", "lex error"),
            (".version 1.0\n", "missing"),
            (PREAMBLE, "unresolved entry"),
            (PREAMBLE.replace("main", "other"), "entry must"),
            (MINIMAL + ".entry main\n", "duplicate"),
            (MINIMAL + ".version 1.0\n", "duplicate"),
            (MINIMAL.replace(".end", ""), "missing .end"),
            (PREAMBLE + ".func main() -> i32\n.end\n", "contain instructions"),
            (MINIMAL + "nop\n", "outside function"),
            (MINIMAL.replace("    const.i32 42", ".global x: i32 = 0"), "inside function"),
            (MINIMAL.replace("    const.i32 42", ".func nested() -> void"), "nested"),
            (MINIMAL.replace("    ret.i32", ".local x: i32\nret.i32"), "precede statements"),
            (MINIMAL.replace("main()", "main(x:i32)"), "entry must"),
            (MINIMAL.replace("-> i32", "-> void"), "entry must"),
            (MINIMAL.replace("const.i32 42", "const.i32 1; ret.i32"), ""),
            (MINIMAL.replace("    const.i32 42", "    add.i32"), "underflow"),
            (MINIMAL.replace("    ret.i32", "    nop"), "fallthrough"),
            (MINIMAL.replace("    ret.i32", "    ret"), "return opcode"),
            (MINIMAL.replace("    ret.i32", "    const.i32 1\n    ret.i32"), "extra evaluation"),
            (MINIMAL.replace("    ret.i32", "again:\n    const.i32 1\n    jmp again"), "inconsistent"),
            (PREAMBLE + ".func main() -> i32\nconst.i32 1\njz join\nconst.i32 2\njoin:\nconst.i32 0\nret.i32\n.end", "inconsistent"),
        ]
        for source, message in cases:
            with self.subTest(source=source):
                if message:
                    self.reject(source, message)
                else:
                    # A semicolon comments out the remainder, not a separator.
                    self.assertEqual(self.assemble(source), GOLDEN[:144] + b"\1\1\0\0\0\x1f" + GOLDEN[150:])
        diagnostic = self.reject(MINIMAL.replace("const.i32 42", "const.u8 256"), "out of range")
        self.assertIn(":4:14:", diagnostic)
        for invalid in (b"\xff", b"\xc0\x80", b"\xed\xa0\x80", b"\xf4\x90\x80\x80", b"\xe2\x82", b"\0"):
            self.reject(MINIMAL.encode() + invalid, "UTF-8")
        self.reject(MINIMAL.replace("42", "1 2"), "parse error")
        self.reject(MINIMAL.replace("42", "0x"), "parse error")
        self.reject(PREAMBLE + '.array a: u8[3] = "unfinished\n', "lex error")

    def test_file_errors_and_usage(self):
        for arguments in ([], ["input"], ["input", "--output", "output"]):
            result = subprocess.run([str(self.assembler), *arguments], env=self.env, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn(b"usage:", result.stderr)
        help_ = subprocess.run([str(self.assembler), "--help"], env=self.env, capture_output=True)
        self.assertEqual(help_.returncode, 0)
        self.assertIn(b"usage:", help_.stdout)
        result = subprocess.run([str(self.assembler), str(self.work / "missing"), "-o", str(self.output)],
                                env=self.env, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"I/O:", result.stderr)
        self.assertFalse(self.output.exists())
        for path in (self.work, self.work / "missing/output"):
            self.assertIn("I/O:", self.assemble(MINIMAL, success=False, output=path))
        if Path("/dev/full").exists():
            self.assertIn("I/O:", self.assemble(MINIMAL, success=False, output=Path("/dev/full")))
        if Path("/proc/self/mem").exists():
            result = subprocess.run([str(self.assembler), "/proc/self/mem", "-o", str(self.output)],
                                    env=self.env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"I/O:", result.stderr)

    @unittest.skipUnless(Path("/proc/self/fd").is_dir() and Path("/dev/full").exists(),
                         "Linux filesystem failure fixtures")
    def test_adapter_multichunk_empty_failures_and_cleanup(self):
        result = subprocess.run([str(self.consumer), str(self.work / "large.bin"), "--io"],
                                cwd=self.work, env=self.env, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual((self.work / "large.bin").read_bytes(), b"")

    def test_missing_and_failed_generator_never_falls_back(self):
        build = self.work / "build"
        command = ["cmake", "-S", str(ROOT), "-B", str(build), "-DBUILD_TESTING=OFF",
                   f"-DCWHIP_BIN_DIR={self.work / 'bin'}"]
        env = self.env | {"CWHIP_SDK": os.environ["CWHIP_SDK"]}
        result = subprocess.run(command + ["-DCPARSEGEN_EXECUTABLE=/nonexistent/cparsegen"],
                                env=env, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"requires installed cparsegen", result.stderr)
        result = subprocess.run(command + ["-DCPARSEGEN_EXECUTABLE=/bin/false"],
                                env=env, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        stale = build / "assembler/parser.cw"
        stale.write_text("stale parser must not be reused\n")
        os.utime(stale, (1, 1))
        result = subprocess.run(["cmake", "--build", str(build), "--target", "cvm-as"],
                                env=env, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "bin/cvm-as").exists())
        self.assertFalse((build / "assembler/parser.cw").exists())


if __name__ == "__main__":
    unittest.main()
