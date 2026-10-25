# CVM assembler

`cvm-as` assembles the v1 syntax in [BYTECODE-ASSEMBLY.md](BYTECODE-ASSEMBLY.md).
It is implemented in CWhip using the public SDK and the installed `cvm`
schema/builders/validator. There is no copied opcode table or binary encoder.
It does not execute programs.

```sh
export CWHIP_SDK=/path/to/installed/binary-io-sdk
cmake -S . -B build \
  -DCPARSEGEN_EXECUTABLE=/path/to/installed/bin/cparsegen \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel 2
ctest --test-dir build --output-on-failure
bin/cvm-as tests/fixtures/hello.asm -o build/hello.cvm
cmake --install build --prefix "$PWD/build/install"
cd /tmp
/path/to/cvm/build/install/bin/cvm-as /path/to/input.asm -o output.cvm
```

The build invokes exactly `cparsegen --library grammar/assembly.cpg
BUILD/assembler/parser.cw`, using absolute paths. Generated source is confined
to the build tree; missing generators and generation failures are fatal.
There is no handwritten-parser fallback, vendored generator, runtime generator
dependency, or runtime source-tree dependency. CMake tracks the grammar,
generator executable, CWhip sources, modules and selected SDK resources.
Changing any of these rebuilds the affected output.
Use an updated cparsegen that emits current CWhip keyword syntax and explicit
`int64` indices; generated source is no longer rewritten by CVM.
See [Building](BUILDING.md) for the SDK and generator prerequisites.

## Source contract

The CLI accepts `cvm-as INPUT.asm -o OUTPUT.cvm` and `--help`. Exit status
is 0 on success, 1 for assembly or file failures, and 2 for usage errors.
Diagnostics use `input:line:column: message`; columns count UTF-8 **bytes**,
starting at 1. File errors are reported separately as `input: I/O: message`
and include the failing path. Assembly and validation finish before opening
the output, so invalid assembly does not truncate existing output.
An output I/O error can leave a partial/truncated file; writes are not atomic.

Supported declarations are `.version 1.0`, `.entry main`, `.global`,
`.array`, `.func`, `.local`, and `.end`. There are no additional `.section`
directives in the approved v1 syntax. All instructions and service names are
supported, including scalar/file parameters, locals and returns; i32/u8
globals and global/frame-local arrays; zero-filled, list and string
initializers; signed decimal/hex literals; byte character literals; and all
documented escapes. Arrays retain source declaration order, including local
arrays. Function, global and array namespaces are independent; array names
are unique across the file, and scalar local/parameter names and labels are
unique per function. Forward function, global, array and label references
are resolved after parsing. Branches encode function-relative byte offsets.
Locals follow parameters in declaration order. References to another
function's local array are rejected.

`sys file_open`, `sys file_read_handle`, `sys file_write_handle`, and
`sys file_close_handle` resolve through `CVM.Service` to stable IDs 9..12.
No grammar extension is needed. Their metadata supplies stack arities;
runtime checks enforce their types, modes and bounds. See the
[integer-file example](INTERPRETER.md#integer-file-reproduction-and-smallc-lowering)
and [canonical service table](BYTECODE-ASSEMBLY.md#6-runtime-services-and-io-boundary).

Blank lines, CRLF/LF, a final line without LF, and semicolon comments are
accepted. A semicolon is not an instruction separator. Identifiers are
ASCII and case-sensitive. Source must be valid UTF-8 without embedded NUL.
Raw UTF-8 in strings is preserved as its encoded bytes; a character literal
must decode to exactly one byte, never a truncated Unicode character.
`\xHH` consumes exactly two hexadecimal digits; subsequent string characters
remain separate bytes. Strings include a terminating NUL in array data;
list initializers do not. Any remaining capacity is zero-filled.

The generator's lexer accepts ASCII only. A small source-normalization pass
validates UTF-8 and rewrites non-ASCII bytes **inside quoted literals** to
`\xHH` before generated scanning; comment bytes are ignored. It does not
parse declarations or instructions. A byte-column map preserves original
diagnostic locations. The generated parser handles a complete logical line
at a time; the assembler enforces file/function ordering. This avoids
whole-file parser backtracking budgets. Excessive individual lines still
fail explicitly with the installed generator's resource-limit diagnostic.

## Specification reconciliations and validation boundary

The specification's `.entry name` grammar is generic, but its prose requires
`main() -> i32`. v1 conservatively requires `.entry main` naming that exact
signature, with no parameters. The binary library remains capable of other
entry indexes for non-assembler producers.

The function record requires maximum reachable stack depth, but assembly
has no stack-size directive. The assembler computes it with depth-only
control-flow propagation, using callee and shared service arities. It
rejects reachable underflow, differing depths at joins, excessive depth,
extra values at return, fallthrough, and return opcodes inconsistent with
declared return types. Unreachable instructions still undergo operand,
symbol, range and return-opcode checking; their depths do not contribute.
The minimal example consequently declares maximum stack 1, not a placeholder.

This is **not** a semantic verifier: scalar/ArrayRef types at stack positions,
call argument types, array element operations, file-handle lifetimes, and
runtime/execution safety remain unverified. For example, a u8 value returned
with `ret.i32` can pass depth checks. The shared structural validator is run
before output, but its documented limitations still apply. The separate
`cvm-run` interpreter detects these cases when they execute; it does not
provide a pre-execution semantic verifier. Runtime services are implemented
by `cvm-run`; DEBUG generation, disassembly, SmallC integration, and an
execution-safety guarantee are not included. See
[Interpreter usage and scope](INTERPRETER.md).

## Reusable binary file adapter

Import the installed `cvmfile` 1.0.0 package as namespace `CVMFile`.
Its manifest depends only on the public SDK `system` 0.1.0 package:

```cwhip
import cvmfile as IO
import cvm as CVM

start {
    IO.Result loaded = IO.Files().read("program.cvm")
    if (!loaded.ok()) { raise(Exception(loaded.error())) }
    CVM.ValidationResult valid = CVM.ContainerValidator().validate(loaded.bytes())
    if (!valid.valid()) { raise(Exception(valid.message())) }
}
```

`Files.read(path)` returns a `Result` exposing `ok()`, `bytes()` and `error()`.
Failed reads return an empty buffer and an explicit diagnostic, never partial
data disguised as success. `Files.write(path, buffer)` returns the same shape
(its success buffer is empty); null data is rejected without opening a file.
`Files.readLimited(path, maximumBytes)` provides the same contract while
reading at most one byte beyond the supplied limit to detect oversized input
without buffering the rest; it is used by `cvm-run` before validation. Its
`Result.category()` distinguishes ordinary I/O failure from
`Result.LIMIT_EXCEEDED`.
Neither operation converts binary data through String. Reads use 64 KiB
chunks until EOF, including partial final reads. Writes advance by actual
byte counts, retry a short successful write, reject zero/invalid progress,
and propagate any SDK error even when some bytes transferred. All opened
files close explicitly in `finally`. Close/flush failures are reported;
cleanup does not replace a previously reported read/write error.

## Conformance

`tests/test_assembler.py` installs the assembler and both modules into a
temporary prefix and runs away from the source tree with only `/usr/bin:/bin`
on `PATH`, no generator or SDK environment. A separately compiled installed
consumer reloads accepted files through the public byte API and invokes
the structural validator. Expected bytes use independent Python `struct`
checks, never the CVM encoder/decoder: the exact 183-byte published golden,
complete hello/loop containers, every opcode/service encoding, declarations,
initializers, branch offsets and record fields. Negative cases exercise
symbols, operands, source structure, UTF-8/escapes, located diagnostics,
stack-depth metadata and actual filesystem failures. Installed library
regressions remain separate. Linux failure fixtures exercise `/proc/self/mem`
read errors, `/dev/full` buffered-close and large-write errors, repeated-error
descriptor cleanup, empty files and a 131,329-byte multichunk round trip.
The suite also checks old SDK rejection, missing/failed generation with a
stale parser present, and thousands of separately generated-parser lines.
