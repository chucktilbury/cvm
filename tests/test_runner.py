"""Installed command-line and in-memory interpreter conformance tests."""

import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def section_offsets(binary):
    count = struct.unpack_from("<H", binary, 12)[0]
    sections = {}
    for index in range(count):
        kind, flags, offset, length, records = struct.unpack_from(
            "<HHIII", binary, 32 + index * 16)
        sections[kind] = (offset, length, records)
    return sections


@unittest.skipUnless(os.environ.get("CWHIP_SDK") and os.environ.get("CVM_BUILD_DIR"),
                     "requires a configured CVM build and CWhip SDK")
class RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.prefix = cls.root / "install"
        subprocess.run(["cmake", "--install", os.environ["CVM_BUILD_DIR"],
                        "--prefix", str(cls.prefix)], check=True, capture_output=True)
        cls.runner = cls.prefix / "bin/cvm-run"
        cls.assembler = cls.prefix / "bin/cvm-as"
        cls.env = {"PATH": "/usr/bin:/bin", "HOME": str(cls.root)}

        modules = cls.root / "modules"
        shutil.copytree(cls.prefix / "share/cwhip/modules", modules)
        cls.consumer = cls.root / "vm-consumer"
        compiled = subprocess.run([
            str(Path(os.environ["CWHIP_SDK"]) / "bin/cwhip"),
            str(ROOT / "tests/vm_consumer.cw"), "-M", str(modules),
            "-o", str(cls.consumer),
        ], cwd=cls.root, env={**os.environ, "CWHIP_SDK": os.environ["CWHIP_SDK"]},
            capture_output=True, text=True)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)

    def setUp(self):
        self.case = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(self.case.cleanup)
        self.work = Path(self.case.name)

    def assemble(self, source):
        source_path = self.work / "program.asm"
        binary_path = self.work / "program.cvm"
        source_path.write_text(source)
        result = subprocess.run([str(self.assembler), str(source_path), "-o",
                                 str(binary_path)], cwd=self.work, env=self.env,
                                capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"")
        return binary_path

    def run_binary(self, binary_path, *arguments, input=b""):
        return subprocess.run([str(self.runner), *arguments, str(binary_path)],
                              cwd=self.work, env=self.env, capture_output=True,
                              input=input, timeout=30)

    def byte_literal(self, payload):
        return "".join(f"\\x{byte:02x}" for byte in payload)

    def file_copy_program(self, source, destination, chunk_size=65536):
        source = str(source)
        destination = str(destination)
        return f""".version 1.0
.entry main
.array source_path: u8[{len(source.encode()) + 1}] = "{source}"
.array destination_path: u8[{len(destination.encode()) + 1}] = "{destination}"
.func main() -> i32
    .local reader: file
    .local writer: file
    .local read_count: i32
    .local remaining: i32
    .local position: i32
    .local written: i32
    .array transfer_buffer: u8[{chunk_size}]
    array source_path
    sys file_open_read
    stloc reader
    pop
    array destination_path
    sys file_open_write
    stloc writer
    pop
read_loop:
    ldloc reader
    array transfer_buffer
    const.i32 0
    const.i32 {chunk_size}
    sys file_read
    stloc read_count
    pop
    ldloc read_count
    jz finished
    const.i32 0
    stloc position
    pop
    ldloc read_count
    stloc remaining
    pop
write_loop:
    ldloc writer
    array transfer_buffer
    ldloc position
    ldloc remaining
    sys file_write
    stloc written
    pop
    ldloc position
    ldloc written
    add.i32
    stloc position
    pop
    ldloc remaining
    ldloc written
    sub.i32
    stloc remaining
    pop
    ldloc remaining
    jz read_loop
    jmp write_loop
finished:
    ldloc reader
    sys file_close
    ldloc writer
    sys file_close
    const.i32 0
    ret.i32
.end
"""

    def assert_result(self, source, value):
        binary = self.assemble(source)
        result = self.run_binary(binary)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout, f"result: {value}\n".encode())
        self.assertEqual(result.stderr, b"")
        return binary

    def assert_trap(self, source, message, category="runtime trap"):
        binary = self.assemble(source)
        result = self.run_binary(binary)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        error = result.stderr.decode()
        self.assertIn(category, error)
        self.assertIn(message, error)
        self.assertRegex(error, r"function main\[\d+\]\+\d+")

    def test_help_usage_and_exact_minimal_result(self):
        help_result = subprocess.run([str(self.runner), "--help"], cwd=self.work,
                                     env=self.env, capture_output=True)
        self.assertEqual(help_result.returncode, 0)
        self.assertIn(b"usage: cvm-run", help_result.stdout)
        invalid = subprocess.run([str(self.runner)], cwd=self.work, env=self.env,
                                 capture_output=True)
        self.assertEqual(invalid.returncode, 2)
        self.assertEqual(invalid.stdout, b"")
        self.assertIn(b"usage: cvm-run", invalid.stderr)
        self.assert_result(""".version 1.0
.entry main
.func main() -> i32
    const.i32 42
    ret.i32
.end
""", 42)

    def test_checked_arithmetic_and_conversions(self):
        preamble = ".version 1.0\n.entry main\n.func main() -> i32\n"
        suffix = "    ret.i32\n.end\n"
        for value in (-2147483648, 2147483647):
            self.assert_result(preamble + f"    const.i32 {value}\n" + suffix, value)
        self.assert_result(preamble + "    const.i32 255\n    to.u8\n    to.i32\n" + suffix, 255)
        self.assert_trap(preamble + "    const.i32 2147483647\n    const.i32 1\n    add.i32\n" + suffix,
                         "overflow")
        self.assert_trap(preamble + "    const.i32 -2147483648\n    const.i32 1\n    sub.i32\n" + suffix,
                         "overflow")
        self.assert_trap(preamble + "    const.i32 -2147483648\n    const.i32 -1\n    mul.i32\n" + suffix,
                         "overflow")
        self.assert_trap(preamble + "    const.i32 -2147483648\n    neg.i32\n" + suffix,
                         "negation overflow")
        self.assert_trap(preamble + "    const.i32 1\n    const.i32 0\n    div.i32\n" + suffix,
                         "division by zero")
        self.assert_trap(preamble + "    const.i32 -2147483648\n    const.i32 -1\n    rem.i32\n" + suffix,
                         "overflow")
        self.assert_trap(preamble + "    const.i32 256\n    to.u8\n" + suffix,
                         "to.u8")
        self.assert_trap(preamble + "    const.i32 -1\n    to.u8\n" + suffix,
                         "to.u8")
        self.assert_result(preamble + "    const.i32 -7\n    const.i32 2\n    div.i32\n" + suffix,
                           -3)
        self.assert_result(preamble + "    const.i32 -7\n    const.i32 2\n    rem.i32\n" + suffix,
                           -1)

    def test_all_nonservice_opcode_success_paths(self):
        source = """.version 1.0
.entry main
.func noop() -> void
    nop
    ret
.end
.func byte_value() -> u8
    const.u8 250
    ret.u8
.end
.func main() -> i32
    .local saved: i32
    call noop
    const.i32 3
    dup
    add.i32
    stloc saved
    pop
    ldloc saved
    const.i32 8
    const.i32 3
    sub.i32
    const.i32 6
    mul.i32
    const.i32 4
    div.i32
    const.i32 3
    rem.i32
    neg.i32
    add.i32
    call byte_value
    to.i32
    add.i32
    const.i32 1
    const.i32 1
    eq.i32
    const.i32 1
    const.i32 2
    ne.i32
    add.i32
    const.i32 1
    const.i32 2
    lt.i32
    add.i32
    const.i32 2
    const.i32 2
    le.i32
    add.i32
    const.i32 3
    const.i32 2
    gt.i32
    add.i32
    const.i32 2
    const.i32 2
    ge.i32
    add.i32
    add.i32
    ret.i32
.end
"""
        # 6 + (((8-3)*6/4)%3 negated) + 250 + six true comparisons = 261.
        self.assert_result(source, 261)

    def test_file_return_instruction_traps_without_fake_handles(self):
        source = """.version 1.0
.entry main
.func return_file() -> file
    const.i32 0
    ret.file
.end
.func main() -> i32
    call return_file
    pop
    const.i32 0
    ret.i32
.end
"""
        binary = self.assemble(source)
        result = self.run_binary(binary)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"expected file, found i32", result.stderr)
        self.assertIn(b"function return_file[0]+5", result.stderr)

    def test_loop_branch_and_nested_call_results(self):
        source = """.version 1.0
.entry main
.func sum_to(n:i32) -> i32
    .local i: i32
    .local sum: i32
    const.i32 0
    stloc i
    pop
    const.i32 0
    stloc sum
    pop
loop:
    ldloc i
    ldloc n
    le.i32
    jz done
    ldloc sum
    ldloc i
    add.i32
    stloc sum
    pop
    ldloc i
    const.i32 1
    add.i32
    stloc i
    pop
    jmp loop
done:
    ldloc sum
    ret.i32
.end
.func main() -> i32
    const.i32 10
    call sum_to
    ret.i32
.end
"""
        self.assert_result(source, 55)

    def test_globals_arrays_and_frame_isolation(self):
        source = """.version 1.0
.entry main
.global total: i32 = 4
.array global_values: i32[2] = {7, 8}
.func first() -> i32
    .array local_values: i32[1] = {3}
    array local_values
    const.i32 0
    aget
    ret.i32
.end
.func add_one(value:i32) -> i32
    .local result: i32
    ldloc value
    const.i32 1
    add.i32
    stloc result
    pop
    ldloc result
    ret.i32
.end
.func main() -> i32
    .local value: i32
    array global_values
    const.i32 1
    aget
    stloc value
    pop
    ldglobal total
    ldloc value
    add.i32
    stglobal total
    pop
    array global_values
    const.i32 0
    const.i32 40
    aset
    pop
    call first
    call first
    add.i32
    const.i32 10
    call add_one
    const.i32 20
    call add_one
    add.i32
    add.i32
    ldglobal total
    add.i32
    ret.i32
.end
"""
        # 3 + 3 + 11 + 21 + 12 == 50; the local array is rebuilt on each call.
        self.assert_result(source, 50)

    def test_caller_array_reference_survives_scalar_call(self):
        source = """.version 1.0
.entry main
.func value() -> i32
    const.i32 9
    ret.i32
.end
.func main() -> i32
    .array local: u8[2] = {4, 5}
    array local
    call value
    pop
    alen
    ret.i32
.end
"""
        self.assert_result(source, 2)

    def test_array_bounds_and_type_mismatch_trap(self):
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array values: i32[1]
    array values
    const.i32 1
    aget
    ret.i32
.end
""", "out of bounds")
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array values: i32[1]
    array values
    const.i32 -1
    aget
    ret.i32
.end
""", "out of bounds")
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    const.u8 7
    ret.i32
.end
""", "expected i32")
        self.assert_trap(""".version 1.0
.entry main
.func expects_byte(value:u8) -> i32
    ldloc value
    to.i32
    ret.i32
.end
.func main() -> i32
    const.i32 7
    call expects_byte
    ret.i32
.end
""", "call argument 0 has the wrong type")

    def test_signed_i32_array_store_round_trip(self):
        source = """.version 1.0
.entry main
.array values: i32[1]
.func main() -> i32
    array values
    const.i32 0
    const.i32 -2147483648
    aset
    pop
    array values
    const.i32 0
    aget
    ret.i32
.end
"""
        self.assert_result(source, -2147483648)

    def test_u8_array_and_global_storage(self):
        source = """.version 1.0
.entry main
.global byte: u8 = 4
.array values: u8[2] = {1, 2}
.func main() -> i32
    array values
    const.i32 1
    const.u8 255
    aset
    pop
    array values
    const.i32 1
    aget
    stglobal byte
    pop
    ldglobal byte
    to.i32
    ret.i32
.end
"""
        self.assert_result(source, 255)

    def test_underflow_not_rejected_by_structural_validator(self):
        binary = self.assert_result(""".version 1.0
.entry main
.func main() -> i32
    const.i32 0
    ret.i32
.end
""", 0)
        encoded = bytearray(binary.read_bytes())
        code_offset = section_offsets(encoded)[1][0]
        encoded[code_offset] = 0x1A  # replace const.i32 with pop
        malformed_semantics = self.work / "underflow.cvm"
        malformed_semantics.write_bytes(encoded)
        result = self.run_binary(malformed_semantics)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"operand stack underflow", result.stderr)
        self.assertIn(b"function main[0]+0", result.stderr)

    def test_entry_signature_and_global_record_load_errors(self):
        entry = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 0
    ret.i32
.end
""")
        encoded = bytearray(entry.read_bytes())
        funcs_offset = section_offsets(encoded)[2][0]
        encoded[funcs_offset + 24] = 2
        changed_entry = self.work / "bad-entry.cvm"
        changed_entry.write_bytes(encoded)
        result = self.run_binary(changed_entry)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"entry function must have signature", result.stderr)
        self.assertIn(b"function main[0]", result.stderr)

        global_program = self.assemble(""".version 1.0
.entry main
.global value: i32 = 0
.func main() -> i32
    const.i32 0
    ret.i32
.end
""")
        encoded = bytearray(global_program.read_bytes())
        globals_offset = section_offsets(encoded)[4][0]
        encoded[globals_offset + 4] = 9
        changed_global = self.work / "bad-global.cvm"
        changed_global.write_bytes(encoded)
        result = self.run_binary(changed_global)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"load", result.stderr)
        self.assertIn(b"invalid global type", result.stderr)

    def test_array_record_and_initializer_load_errors(self):
        binary = self.assemble(""".version 1.0
.entry main
.array values: u8[1] = {7}
.func main() -> i32
    const.i32 0
    ret.i32
.end
""")
        sections = section_offsets(binary.read_bytes())
        arrays_offset = sections[5][0]

        encoded = bytearray(binary.read_bytes())
        struct.pack_into("<H", encoded, arrays_offset + 4, 1)
        invalid_owner = self.work / "bad-array-owner.cvm"
        invalid_owner.write_bytes(encoded)
        result = self.run_binary(invalid_owner)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"load", result.stderr)
        self.assertIn(b"invalid array metadata", result.stderr)

        encoded = bytearray(binary.read_bytes())
        struct.pack_into("<I", encoded, arrays_offset + 12, 0xFFFFFFFF)
        invalid_data = self.work / "bad-array-data.cvm"
        invalid_data.write_bytes(encoded)
        result = self.run_binary(invalid_data)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"array initializer is outside DATA", result.stderr)

    def test_console_services_preserve_bytes_and_report_eof(self):
        payload = bytes(range(256))
        binary = self.assemble(f""".version 1.0
.entry main
.array bytes: u8[257] = "{self.byte_literal(payload)}"
.func main() -> i32
    array bytes
    const.i32 0
    const.i32 0
    sys stdout_write
    pop
    const.i32 -2147483648
    sys stdout_i32
    const.u8 255
    sys stdout_byte
    array bytes
    const.i32 0
    const.i32 256
    sys stdout_write
    pop
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(binary)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout, b"-2147483648\xff" + payload + b"result: 0\n")
        self.assertEqual(result.stderr, b"")

        input_program = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    sys stdin_byte
    sys stdout_i32
    const.u8 32
    sys stdout_byte
    sys stdin_byte
    sys stdout_i32
    const.u8 32
    sys stdout_byte
    sys stdin_byte
    sys stdout_i32
    const.u8 32
    sys stdout_byte
    sys stdin_byte
    sys stdout_i32
    const.u8 32
    sys stdout_byte
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(input_program, input=b"\x00\x80\xff")
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout, b"0 128 255 -1 result: 0\n")
        self.assertEqual(result.stderr, b"")

    def test_file_services_copy_exact_binary_empty_and_multichunk_data(self):
        payloads = (
            bytes(range(256)),
            b"",
            bytes((index * 37 + 11) % 256 for index in range(131329)),
        )
        for number, payload in enumerate(payloads):
            with self.subTest(length=len(payload)):
                source_path = self.work / f"source-{number}.bin"
                destination_path = self.work / f"destination-{number}.bin"
                source_path.write_bytes(payload)
                binary = self.assemble(
                    self.file_copy_program(source_path, destination_path))
                result = self.run_binary(binary)
                self.assertEqual(result.returncode, 0,
                                 result.stderr.decode(errors="replace"))
                self.assertEqual(result.stdout, b"result: 0\n")
                self.assertEqual(result.stderr, b"")
                self.assertEqual(destination_path.read_bytes(), payload)

    def test_file_services_decode_valid_utf8_paths(self):
        source_path = self.work / "café-source.bin"
        destination_path = self.work / "café-destination.bin"
        payload = b"\x00\x80\xff"
        source_path.write_bytes(payload)
        result = self.run_binary(self.assemble(
            self.file_copy_program(source_path, destination_path, 4)))
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(destination_path.read_bytes(), payload)

    def test_file_write_zero_count_is_a_successful_noop(self):
        path = str(self.work / "empty-output.bin")
        program = self.assemble(f""".version 1.0
.entry main
.array path: u8[{len(path.encode()) + 1}] = "{path}"
.func main() -> i32
    .local file: file
    .array data: u8[1]
    array path
    sys file_open_write
    stloc file
    pop
    ldloc file
    array data
    const.i32 0
    const.i32 0
    sys file_write
    pop
    ldloc file
    sys file_close
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(program)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(Path(path).read_bytes(), b"")

    def test_open_files_are_closed_on_normal_exit_and_runtime_traps(self):
        path = self.work / "cleanup.bin"
        source = f""".version 1.0
.entry main
.array path: u8[{len(str(path).encode()) + 1}] = "{path}"
.array bytes: u8[4] = "\\x00\\x80\\xff"
.func main() -> i32
    .local file: file
    array path
    sys file_open_write
    stloc file
    pop
    ldloc file
    array bytes
    const.i32 0
    const.i32 3
    sys file_write
    pop
    const.i32 0
    ret.i32
.end
"""
        result = self.run_binary(self.assemble(source))
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(path.read_bytes(), b"\x00\x80\xff")

        trap_path = self.work / "trap-cleanup.bin"
        trap_program = f""".version 1.0
.entry main
.array path: u8[{len(str(trap_path).encode()) + 1}] = "{trap_path}"
.array bytes: u8[3] = "\\x00\\xfe"
.func main() -> i32
    .local file: file
    array path
    sys file_open_write
    stloc file
    pop
    ldloc file
    array bytes
    const.i32 0
    const.i32 2
    sys file_write
    pop
    const.i32 1
    const.i32 0
    div.i32
    ret.i32
.end
"""
        result = self.run_binary(self.assemble(trap_program))
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"division by zero", result.stderr)
        self.assertEqual(trap_path.read_bytes(), b"\x00\xfe")

    def test_invalid_service_arguments_and_stale_handles_trap(self):
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array wrong: i32[1]
    array wrong
    sys file_open_read
    pop
    const.i32 0
    ret.i32
.end
""", "file path array must contain u8 elements")
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array path: u8[1] = {97}
    array path
    sys file_open_read
    pop
    const.i32 0
    ret.i32
.end
""", "file path is not NUL-terminated")
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array path: u8[2] = {255, 0}
    array path
    sys file_open_read
    pop
    const.i32 0
    ret.i32
.end
""", "file path is not valid UTF-8")
        readable = self.work / "capacity.bin"
        readable.write_bytes(b"")
        readable_path = str(readable)
        self.assert_trap(f""".version 1.0
.entry main
.array path: u8[{len(readable_path.encode()) + 1}] = "{readable_path}"
.func main() -> i32
    .local file: file
    .array bytes: u8[1]
    array path
    sys file_open_read
    stloc file
    pop
    ldloc file
    array bytes
    const.i32 0
    const.i32 0
    sys file_read
    pop
    const.i32 0
    ret.i32
.end
""", "file_read count must be positive")
        self.assert_trap(""".version 1.0
.entry main
.func main() -> i32
    .array bytes: u8[1]
    array bytes
    const.i32 -1
    const.i32 1
    sys stdout_write
    pop
    const.i32 0
    ret.i32
.end
""", "stdout_write offset/count is outside")

        path = self.work / "stale.bin"
        stale = f""".version 1.0
.entry main
.array path: u8[{len(str(path).encode()) + 1}] = "{path}"
.array bytes: u8[2] = "x"
.func main() -> i32
    .local file: file
    array path
    sys file_open_write
    stloc file
    pop
    ldloc file
    sys file_close
    ldloc file
    array bytes
    const.i32 0
    const.i32 1
    sys file_write
    pop
    const.i32 0
    ret.i32
.end
"""
        self.assert_trap(stale, "invalid, stale, or foreign file handle")

    def test_service_capabilities_and_open_handle_limits(self):
        output = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 7
    sys stdout_i32
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(output, "--no-stdout")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"unsupported service", result.stderr)
        self.assertIn(b"capability for 'stdout_i32' is disabled", result.stderr)

        input_program = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    sys stdin_byte
    pop
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(input_program, "--no-stdin")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"capability for 'stdin_byte' is disabled", result.stderr)

        path = str(self.work / "disabled.bin")
        file_program = self.assemble(f""".version 1.0
.entry main
.array path: u8[{len(path.encode()) + 1}] = "{path}"
.func main() -> i32
    array path
    sys file_open_write
    pop
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(file_program, "--no-files")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"capability for 'file_open_write' is disabled", result.stderr)
        self.assertFalse(Path(path).exists())
        result = self.run_binary(file_program, "--max-open-files", "0")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"open file handle limit exceeded", result.stderr)
        result = self.run_binary(output, "--max-open-files", "4097")
        self.assertEqual(result.returncode, 2)

        first = str(self.work / "first.bin")
        second = str(self.work / "second.bin")
        two_open = self.assemble(f""".version 1.0
.entry main
.array first_path: u8[{len(first.encode()) + 1}] = "{first}"
.array second_path: u8[{len(second.encode()) + 1}] = "{second}"
.func main() -> i32
    .local file: file
    array first_path
    sys file_open_write
    stloc file
    pop
    array second_path
    sys file_open_write
    pop
    const.i32 0
    ret.i32
.end
""")
        limited_open = self.run_binary(two_open, "--max-open-files", "1")
        self.assertEqual(limited_open.returncode, 1)
        self.assertIn(b"open file handle limit exceeded", limited_open.stderr)
        self.assertTrue(Path(first).exists())
        self.assertFalse(Path(second).exists())

        api_disabled = subprocess.run([str(self.consumer), str(file_program), "no-files"],
                                       cwd=self.work, env=self.env, capture_output=True,
                                       timeout=30)
        self.assertEqual(api_disabled.returncode, 4)
        self.assertTrue(api_disabled.stderr.startswith(b"4:0:"))
        self.assertIn(b"host capability for 'file_open_write' is disabled",
                      api_disabled.stderr)
        api_limited = subprocess.run([str(self.consumer), str(file_program), "zero-files"],
                                     cwd=self.work, env=self.env, capture_output=True,
                                     timeout=30)
        self.assertEqual(api_limited.returncode, 4)
        self.assertTrue(api_limited.stderr.startswith(b"5:0:"))
        self.assertIn(b"open file handle limit exceeded", api_limited.stderr)

        missing_path = str(self.work / "missing-file.bin")
        missing_program = self.assemble(f""".version 1.0
.entry main
.array path: u8[{len(missing_path.encode()) + 1}] = "{missing_path}"
.func main() -> i32
    array path
    sys file_open_read
    pop
    const.i32 0
    ret.i32
.end
""")
        missing = self.run_binary(missing_program)
        self.assertEqual(missing.returncode, 1)
        self.assertIn(b"I/O error", missing.stderr)
        self.assertIn(b"opening '", missing.stderr)

    @unittest.skipUnless(os.name == "posix" and Path("/proc/self/mem").exists()
                         and Path("/dev/full").exists(),
                         "requires Linux procfs and /dev/full I/O error fixtures")
    def test_file_io_errors_and_repeated_failure_cleanup(self):
        bad_read = """.version 1.0
.entry main
.array path: u8[15] = "/proc/self/mem"
.func main() -> i32
    .local file: file
    .array data: u8[1]
    array path
    sys file_open_read
    stloc file
    pop
    ldloc file
    array data
    const.i32 0
    const.i32 1
    sys file_read
    pop
    const.i32 0
    ret.i32
.end
"""
        failed_read = self.assemble(bad_read)
        result = self.run_binary(failed_read)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"I/O error", result.stderr)
        self.assertIn(b"reading file", result.stderr)

        full_path = "/dev/full"
        bad_write = f""".version 1.0
.entry main
.array path: u8[{len(full_path) + 1}] = "{full_path}"
.array data: u8[2] = "x"
.func main() -> i32
    .local file: file
    array path
    sys file_open_write
    stloc file
    pop
    ldloc file
    array data
    const.i32 0
    const.i32 1
    sys file_write
    pop
    ldloc file
    sys file_close
    const.i32 0
    ret.i32
.end
"""
        failed_write = self.assemble(bad_write)
        result = self.run_binary(failed_write)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"I/O error", result.stderr)
        self.assertIn(b"closing file handle", result.stderr)

        result = subprocess.run([str(self.consumer), str(failed_read), "repeat"],
                                cwd=self.work, env=self.env, capture_output=True,
                                timeout=30)
        self.assertEqual(result.returncode, 4, result.stderr.decode(errors="replace"))
        self.assertTrue(result.stderr.startswith(b"6:0:"))

    def test_deterministic_instruction_stack_call_and_heap_limits(self):
        simple = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 1
    const.i32 2
    add.i32
    ret.i32
.end
""")
        result = self.run_binary(simple, "--max-instructions", "1")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"instruction limit exceeded", result.stderr)
        result = self.run_binary(simple, "--max-stack-values", "1")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"active local and operand value limit", result.stderr)

        call_program = self.assemble(""".version 1.0
.entry main
.func callee() -> i32
    const.i32 1
    ret.i32
.end
.func main() -> i32
    call callee
    ret.i32
.end
""")
        result = self.run_binary(call_program, "--max-call-depth", "1")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"call depth limit exceeded", result.stderr)

        array_program = self.assemble(""".version 1.0
.entry main
.array values: u8[2]
.func main() -> i32
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(array_program, "--max-heap-bytes", "1")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"array storage exceeds configured heap limit", result.stderr)

    def test_program_size_malformed_input_and_invalid_paths(self):
        binary = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(binary, "--max-program-bytes", "1")
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"input exceeds configured byte limit", result.stderr)
        self.assertIn(b"resource limit", result.stderr)
        truncated = self.work / "truncated.cvm"
        truncated.write_bytes(binary.read_bytes()[:31])
        result = self.run_binary(truncated)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"validation", result.stderr)
        missing = self.work / "does-not-exist.cvm"
        result = self.run_binary(missing)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"load", result.stderr)
        invalid_limit = self.run_binary(binary, "--max-instructions", "0")
        self.assertEqual(invalid_limit.returncode, 2)

    def test_public_in_memory_vm_api(self):
        binary = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 -17
    ret.i32
.end
""")
        result = subprocess.run([str(self.consumer), str(binary)], cwd=self.work,
                                env=self.env, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        output = result.stdout.decode().strip().split(":")
        self.assertEqual(output[0], "-17")
        self.assertGreater(int(output[1]), 0)

    def test_public_api_structured_failures_and_custom_limits(self):
        source = """.version 1.0
.entry main
.func main() -> i32
    const.i32 7
    sys stdout_i32
    const.i32 0
    ret.i32
.end
"""
        binary = self.assemble(source)
        enabled = subprocess.run([str(self.consumer), str(binary)], cwd=self.work,
                                 env=self.env, capture_output=True, timeout=30)
        self.assertEqual(enabled.returncode, 0)
        self.assertRegex(enabled.stdout.decode(), r"^70:\d+\n$")
        self.assertEqual(enabled.stderr, b"")

        disabled = subprocess.run([str(self.consumer), str(binary), "no-stdout"],
                                  cwd=self.work, env=self.env, capture_output=True,
                                  timeout=30)
        self.assertEqual(disabled.returncode, 4)
        self.assertTrue(disabled.stderr.startswith(
            b"4:0:5:host capability for 'stdout_i32' is disabled"))

        limited = subprocess.run([str(self.consumer), str(binary), "steps"], cwd=self.work,
                                 env=self.env, capture_output=True, timeout=30)
        self.assertEqual(limited.returncode, 4)
        self.assertTrue(limited.stderr.startswith(b"5:0:5:instruction limit exceeded"))

        malformed = self.work / "malformed.cvm"
        malformed.write_bytes(b"CVM")
        validation = subprocess.run([str(self.consumer), str(malformed)], cwd=self.work,
                                    env=self.env, capture_output=True, timeout=30)
        self.assertEqual(validation.returncode, 4)
        self.assertTrue(validation.stderr.startswith(b"2:-1:-1:"))


if __name__ == "__main__":
    unittest.main()
