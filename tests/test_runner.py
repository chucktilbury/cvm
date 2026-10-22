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

    def run_binary(self, binary_path, *arguments):
        return subprocess.run([str(self.runner), *arguments, str(binary_path)],
                              cwd=self.work, env=self.env, capture_output=True,
                              timeout=30)

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

    def test_unsupported_services_are_explicit(self):
        binary = self.assemble(""".version 1.0
.entry main
.func main() -> i32
    const.i32 7
    sys stdout_i32
    const.i32 0
    ret.i32
.end
""")
        result = self.run_binary(binary)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"unsupported service", result.stderr)
        self.assertIn(b"stdout_i32", result.stderr)
        self.assertIn(b"function main[0]+5", result.stderr)

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
        unsupported = subprocess.run([str(self.consumer), str(binary)], cwd=self.work,
                                     env=self.env, capture_output=True, timeout=30)
        self.assertEqual(unsupported.returncode, 4)
        self.assertTrue(unsupported.stderr.startswith(b"4:0:5:host service 'stdout_i32'"))

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
