# CVM bytecode and assembly specification

**Status: approved v1 design, partially implemented.** Numeric choices below
are normative. The shared bytecode library, standalone assembler and binary
file adapter are implemented; see [library](BYTECODE-LIBRARY.md) and
[assembler](ASSEMBLER.md) guides for their exact supported boundaries.
The interpreter, full semantic verifier, disassembler and SmallC binary
backend remain future work. Execution requirements below are not claims
that these components exist.

## 1. Project boundaries and ownership

```text
                      build time
 CVM-owned grammar ──> installed cparsegen ──> generated assembler parser
                                                   │
                                                   v
 SmallC compiler ──> CVM-owned shared bytecode library <── CVM assembler
                                  │
                          encoder / validator
                                  │
                           CVM interpreter
                                  │
                    public CWhip SDK host services
```

CVM owns the versioned bytecode library, canonical opcode and operand
definitions, binary encoder/decoder, builder and validator, VM, assembler,
and assembler grammar. The separately installed cparsegen project owns its
generator executable and implementation. CVM's build locates that installed
executable and invokes it on the grammar in this repository, placing
generated parser sources in the build tree. The generated parser is a build
input, not a runtime dependency. The exact argument vector must come from
the installed cparsegen documentation; it is deliberately not guessed here.
A missing generator or failed generation must fail the build rather than
silently select a hand-written or stale parser. cparsegen and CVM remain
separate projects and packages.

The shared bytecode library is a CVM-owned, versioned package consumed by
both the assembler/VM and the SmallC compiler. It is the sole source of
opcode numbers, operand layouts, serialization, and validation rules.
Consumers use the published library API; they must not copy opcode tables
or encoders. SmallC must not grow a parallel opcode table, binary encoder,
or runtime cparsegen dependency.

SmallC is the C-subset demonstration compiler in cparsegen: `int`/`char`,
arrays and strings, functions/calls, and constructs such as `if`, `for`,
`while`, `switch`, and `goto`. Its current frontend/checker emits an AST,
not VM code. A future SmallC backend lowers that AST through the shared CVM
library. This does not make SmallC an object-oriented language. CWhip is a
separate full OOP compiler; it is the implementation language and public SDK
provider for the VM, not another bytecode producer in this design.

## 2. Binary container

The file is serialized a byte at a time. Multibyte fields are little-endian;
signed values use two's complement. There is no padding. Range checks occur
before encoding. Native structs, host pointers, alignment, and host
endianness are never part of the file format.

The codec can be implemented with arithmetic byte operations alone: emit a
u32 as successive `(value / 256^n) % 256` bytes for `n = 0..3`, and decode
as the sum of each byte times `256^n`. Signed i32 encoding first maps a
validated negative value to its unsigned two's-complement value by adding
`2^32`; decoding subtracts `2^32` from unsigned values at least `2^31`.
The same method with two bytes handles u16. No CWhip bitwise operators are
assumed by this format.

### 2.1 Fixed header and section directory

The header is exactly 32 bytes:

| Offset | Width | Field | v1 value/rule |
|---:|---:|---|---|
| 0 | 4 | magic | ASCII `CVM` followed by NUL (`43 56 4d 00`) |
| 4 | 2 | major | 1 |
| 6 | 2 | minor | 0 |
| 8 | 2 | header size | 32 |
| 10 | 2 | header flags | zero |
| 12 | 2 | section count | at least 7 |
| 14 | 2 | reserved | zero |
| 16 | 4 | entry function | function-table index |
| 20 | 4 | directory offset | 32 |
| 24 | 4 | file size | exact file byte length |
| 28 | 4 | reserved | zero |

The directory immediately follows the header. Each 16-byte record is
`kind:u16, flags:u16, offset:u32, length:u32, count:u32`. Directory offset
must be 32. Section offsets and lengths are byte units from the beginning of
the file. Records are sorted by ascending kind. Required sections occur
exactly once; section kinds and `count` units are:

| Kind | Name | Required | `count` |
|---:|---|---|---|
| 1 | CODE | yes | byte length |
| 2 | FUNCS | yes | number of 28-byte function records |
| 3 | TYPES | yes | byte length |
| 4 | GLOBALS | yes | number of 12-byte global records |
| 5 | ARRAYS | yes | number of 20-byte array records |
| 6 | DATA | yes | byte length |
| 7 | STRINGS | yes | byte length |
| 8 | DEBUG | no | number of 20-byte debug records |

Sections follow the directory, tightly packed in ascending kind order. An
empty section has zero length and may share the following section's offset.
The final section ends exactly at `file_size`. Section flag bit 0 means
optional; all other bits are reserved. Unknown sections are skippable only
when bit 0 is set; an unknown required section is rejected. In v1, header
flags and all reserved fields must be zero; unknown bits are rejected.
Kinds 1 through 7 must have flags zero. If DEBUG is present its optional bit
must be set.
Readers accept only major 1, minor 0, and header size 32. Other versions are
rejected, not guessed.

### 2.2 Record layouts, symbols, and addresses

FUNCS has fixed 28-byte records:

| Field | Width | Meaning |
|---|---:|---|
| name string offset | u32 | byte offset into STRINGS |
| code offset | u32 | byte offset into CODE |
| code length | u32 | byte length of function |
| type offset | u32 | byte offset into TYPES |
| parameter count | u16 | number of leading parameter types |
| local count | u16 | additional scalar locals |
| maximum evaluation stack | u16 | verified maximum reachable depth in stack values |
| flags | u16 | zero in v1 |
| return type | u8 | 0 void, 1 i32, 2 u8, 3 file |
| reserved | 3 | zero |

At `type offset`, TYPES contains one type byte per parameter followed by one
per scalar local. Type 1 is signed i32, 2 is unsigned u8, 3 is opaque file
handle; type 0 is permitted only as a void return type. Type ranges must fit
TYPES and may not overlap. Function names are unique. Function-table index
is the function identifier used by the header entry and `call`. Since
`call` and local-array owner indexes are u16, v1 contains at most 65,535
functions, indexed 0 through 65,534; `0xffff` is reserved for global-array
ownership. The sum of a function's parameter and scalar-local counts may
not exceed 65,536, so each local slot index fits u16.

Each function has a nonempty code extent. Function extents lie wholly in
CODE, do not overlap, and occupy CODE in function-table order without gaps.
Instruction offsets and branch targets are byte offsets relative to the
function start, never file offsets or instruction ordinals. Every branch
target is an instruction start. An `array` instruction may refer to a global
array or to a local array owned by the containing function, never another
function's local array.

GLOBALS has 12-byte records:
`name_string_offset:u32, type:u8, reserved[3], initial_value:i32`.
Types are i32 or u8; the initial value must fit. The record index is the
global index encoded by global instructions. Names are unique. Global and
array table indexes used by instructions are u16, so each table has at most
65,536 records.

ARRAYS has 20-byte records:
`name_string_offset:u32, owner_function:u16, element_type:u8, flags:u8,
length:u32, initial_data_offset:u32, reserved:u32`.
`owner_function == 0xffff` means global; otherwise it is a function index.
Element type is i32 or u8. Length is a positive element count. Flag bit 0
means initialized; other bits are reserved. If initialized,
`initial_data_offset` is relative to DATA and exactly
`length * element_width` bytes must fit there (width 4 for i32, 1 for u8).
If uninitialized, the offset is `0xffffffff` and elements are zeroed.
Initialized ranges must not overlap. Arrays are mutable. The record index is
the array index.

STRINGS contains NUL-terminated UTF-8 names; each referenced offset must
start a valid string and terminate within the section. Identifiers are
ASCII in v1. DEBUG, when present, is a sequence of 20-byte records:
`function_index:u32, instruction_offset:u32, file_name_string_offset:u32,
line:u32, column:u32`. Records are ordered by function then instruction
offset, with no duplicate pair. Offsets must be instruction boundaries;
file names refer to STRINGS; line and column are 1-based. DEBUG only
improves diagnostics and does not affect execution or compatibility.

The entry is a function-table index. Function/global/array identifiers are
table indexes. Data, string, code, and branch locations are byte offsets
within their named section or function, as stated. Counts are record counts
only where the directory table says so; array lengths are element counts.

### 2.3 Numeric golden example

For `main() -> i32` containing `const.i32 42; ret.i32`, CODE is six bytes:
`01 2a 00 00 00 1f`. The minimal file has a 32-byte header, seven 16-byte
directory records (112 bytes), 6 code bytes, one 28-byte function record,
and 5 STRINGS bytes (`main\0`): 183 (`0xb7`) total. The header bytes are:

```text
43 56 4d 00  01 00 00 00  20 00 00 00  07 00 00 00
00 00 00 00  20 00 00 00  b7 00 00 00  00 00 00 00
```

The directory records, each laid out as kind/flags/offset/length/count,
are:

```text
01 00 00 00  90 00 00 00  06 00 00 00  06 00 00 00
02 00 00 00  96 00 00 00  1c 00 00 00  01 00 00 00
03 00 00 00  b2 00 00 00  00 00 00 00  00 00 00 00
04 00 00 00  b2 00 00 00  00 00 00 00  00 00 00 00
05 00 00 00  b2 00 00 00  00 00 00 00  00 00 00 00
06 00 00 00  b2 00 00 00  00 00 00 00  00 00 00 00
07 00 00 00  b2 00 00 00  05 00 00 00  05 00 00 00
```

CODE starts at `0x90` (144); FUNCS at `0x96`. Its function record names
`main` at STRINGS offset 0, points to CODE offset 0 length 6, has no
parameters or locals, maximum stack 1, and return type 1. Empty sections
share offset `0xb2` (178), followed by STRINGS. The library and assembler conformance tests check the
complete 183-byte golden independently.

## 3. Guest values and execution

Guest scalar types are signed two's-complement i32, unsigned u8, and opaque
file handles. Comparisons yield i32 0 or 1. Arrays contain i32 or u8 and are
referenced internally by a typed `ArrayRef`, never by a guest integer or
pointer. Each call has a frame with separate parameter/local slots, local
arrays, and an evaluation stack. A callee has its own evaluation stack;
parameters are indexed from 0 and scalar locals from `parameter_count`.
Local arrays are described by ARRAYS and do not use scalar-local indexes.

u8 is zero-extended when promoted to i32. Add, subtract, multiply, negate,
divide, and remainder are checked; overflow traps. An implementation may
use a signed 64-bit intermediate to check i32 addition, subtraction,
multiplication, and negation before narrowing; the product of two i32 values
fits in i64. Division/remainder by zero and `INT32_MIN / -1` or `% -1` trap.
`to.u8` traps outside 0..255;
`to.i32` zero-extends. Assignment and return require exact types unless a
frontend emits an explicit conversion. No implicit wraparound is defined.
Comparisons use signed i32 ordering. Expression operands and call arguments
are evaluated left-to-right. A branch considers any nonzero i32 true.

Array lengths are positive and fixed. Arrays are zero-initialized before any
initializer. Dynamic indexes are signed i32 and must satisfy
`0 <= index < length`. Loads/stores preserve element type. A local array is
created and initialized on each function entry and destroyed at return.
ArrayRefs cannot be passed as ordinary function parameters, returned, stored
in scalar/global slots, or retained by services. A caller may keep its
ArrayRef on its own stack while a scalar-only function runs. A service
borrows an ArrayRef only for that synchronous call. These lifetime rules
prevent references to expired frames.

The entry signature is `main() -> i32`. Its result is the guest program
result, distinct from VM errors and the host process exit status. The VM API
returns success with the guest result or a structured failure. A CLI may map
success/failure to an OS status but must not silently truncate the guest
result into that status.

## 4. Instruction encoding and complete v1 opcode table

Every opcode is one byte. Multi-byte operands follow little-endian, with no
padding. Stack notation is bottom-to-top; `A` and `B` denote left and right
operands. `Array<T>` is the internal reference above. `CALL` and `SYS` have
signature-dependent effects.

| Byte | Mnemonic | Encoded operands | Stack effect | Operation |
|---:|---|---|---|---|
| 00 | `nop` | — | `S -> S` | no effect |
| 01 | `const.i32` | i32 | `S -> S,i32` | signed constant |
| 02 | `const.u8` | u8 | `S -> S,u8` | unsigned constant |
| 03 | `ldloc` | u16 local index | `S -> S,T` | load parameter/local |
| 04 | `stloc` | u16 local index | `S,T -> S,T` | store same type, leave value |
| 05 | `ldglobal` | u16 global index | `S -> S,T` | load global |
| 06 | `stglobal` | u16 global index | `S,T -> S,T` | store same type, leave value |
| 07 | `array` | u16 array index | `S -> S,Array<T>` | reference current/global array |
| 08 | `alen` | — | `S,Array<T> -> S,i32` | element count |
| 09 | `aget` | — | `S,Array<T>,i32 -> S,T` | checked indexed load |
| 0a | `aset` | — | `S,Array<T>,i32,T -> S,T` | checked store, leave value |
| 0b | `add.i32` | — | `S,i32,i32 -> S,i32` | checked left + right |
| 0c | `sub.i32` | — | `S,i32,i32 -> S,i32` | checked left - right |
| 0d | `mul.i32` | — | `S,i32,i32 -> S,i32` | checked multiply |
| 0e | `div.i32` | — | `S,i32,i32 -> S,i32` | checked signed divide |
| 0f | `rem.i32` | — | `S,i32,i32 -> S,i32` | checked signed remainder |
| 10 | `neg.i32` | — | `S,i32 -> S,i32` | checked negate |
| 11 | `eq.i32` | — | `S,i32,i32 -> S,i32` | equal, result 0/1 |
| 12 | `ne.i32` | — | `S,i32,i32 -> S,i32` | not equal, result 0/1 |
| 13 | `lt.i32` | — | `S,i32,i32 -> S,i32` | signed less-than, 0/1 |
| 14 | `le.i32` | — | `S,i32,i32 -> S,i32` | signed <=, 0/1 |
| 15 | `gt.i32` | — | `S,i32,i32 -> S,i32` | signed greater-than, 0/1 |
| 16 | `ge.i32` | — | `S,i32,i32 -> S,i32` | signed >=, 0/1 |
| 17 | `to.u8` | — | `S,i32 -> S,u8` | checked 0..255 conversion |
| 18 | `to.i32` | — | `S,u8 -> S,i32` | zero extension |
| 19 | `dup` | — | `S,T -> S,T,T` | duplicate scalar/file, not ArrayRef |
| 1a | `pop` | — | `S,T -> S` | discard scalar/file |
| 1b | `jmp` | u32 target | `S -> S` | function-relative byte target |
| 1c | `jz` | u32 target | `S,i32 -> S` | pop; branch if zero |
| 1d | `call` | u16 function index | signature-dependent | call with pushed arguments |
| 1e | `ret` | — | `S -> return` | return void; stack must be empty |
| 1f | `ret.i32` | — | `S,i32 -> return` | return i32; no extra values |
| 20 | `ret.u8` | — | `S,u8 -> return` | return u8; no extra values |
| 21 | `sys` | u8 service number | service-dependent | synchronous host service |
| 22 | `ret.file` | — | `S,file -> return` | return file handle; no extra values |

`dup`/`pop` accept i32, u8, and file handles, not ArrayRefs. Stores and
`aset` leave the stored value. Binary operations pop right then left, so
source evaluation remains left-to-right. `call` pops arguments in reverse
stack order into declared parameter slots; a non-void result is pushed for
the caller. `ret`, `ret.i32`, `ret.u8`, and `ret.file` are valid only for
their matching declared return type and leave no unrelated values. Every
reachable path terminates in a return.
Duplicating or assigning a file handle creates another value for the same
opaque handle; closing it invalidates every copy.
Unknown opcodes, truncated operands, invalid indexes, branch targets not at
instruction boundaries, and targets outside a function are rejected before
execution. v1 has no object model, JIT, threads, native linking, or raw
guest pointers.

## 5. Assembly source format

Assembly is UTF-8 with ASCII identifiers and case-sensitive mnemonics. One
directive, label, or instruction appears per logical line. A semicolon
starts a comment to end-of-line; semicolons do not separate statements.
Blank lines are ignored. Labels end with `:` and are function-scoped.
Forward function/label references are allowed and resolved after parsing.
Duplicates, unresolved names, wrong operand types, and out-of-range values
are diagnostics.

The file starts with `.version 1.0` and exactly one `.entry name`. Globals:
`.global name: i32 = literal` or `.global name: u8 = literal`. Arrays:
`.array name: u8[capacity] [= initializer]` (or i32); outside a function
they are global, inside a function they are frame-local. Initializers are
strings for u8 arrays or `{literal, ...}` for either type. A string stores
decoded bytes plus a NUL; capacity must include it. Other uninitialized
elements are zero. Integer array data uses i32 little-endian.

Functions use `.func name(param:type, ...) -> type`, optional `.local
name: type` scalar declarations, local `.array` declarations, instructions,
then `.end`. Return types are `void`, `i32`, `u8`, or `file`; parameter/local
types are `i32`, `u8`, or `file`. Entry must be `.func main() -> i32`.
Integer literals are signed decimal or `0x` hexadecimal for i32; u8
constants are decimal/hex 0..255. Strings and byte character literals
accept `\\`, `\"`, `\'`, `\n`, `\r`, `\t`, `\0`, and `\xHH` (exactly two
hex digits). A character literal decodes to one byte. Unicode is never
silently truncated to a byte.

Assembly operands use declared names. The assembler resolves table indexes,
branch byte offsets, service numbers, and string/data offsets, then asks the
shared bytecode library to encode and validate. Locals are indexed after
parameters in declaration order. The text form names locals, globals, and
arrays by symbol; the numeric indexes shown in the instruction table are
binary encodings, not source operands. Function/global/array names are unique
in their respective namespaces; labels are unique within a function.

Grammar sketch (lexical details and instruction operand typing are governed
by the rules above):

```text
file          := version entry top_item*
version       := ".version" "1.0" newline
entry         := ".entry" identifier newline
top_item      := global_decl newline | array_decl newline | function
global_decl   := ".global" identifier ":" scalar_type "=" integer
array_decl    := ".array" identifier ":" element_type "[" integer "]"
                 ("=" (string | "{" integer_list? "}"))?
function      := ".func" identifier "(" parameters? ")" "->" return_type
                 newline local_decl* statement* ".end" newline
parameters    := parameter ("," parameter)*
parameter     := identifier ":" scalar_type
local_decl    := ".local" identifier ":" scalar_type newline
               | array_decl newline
statement     := label newline | instruction newline | blank_line
label         := identifier ":"
instruction   := mnemonic (operand ("," operand)*)?
scalar_type   := "i32" | "u8" | "file"
element_type  := "i32" | "u8"
return_type   := "void" | scalar_type
```

Newlines terminate declarations and statements; comments begin with `;`
outside a quoted literal. The grammar uses identifiers for symbol-valued
operands, labels for branch operands, literals for constants, and the
service mnemonic after `sys`. The parser rejects a source-level operand
whose kind does not match the selected instruction.

Hello/output and arithmetic:

```asm
.version 1.0
.entry main
.array greeting: u8[13] = "Hello, CVM!\n"

.func main() -> i32
    array greeting
    const.i32 0
    const.i32 12
    sys stdout_write
    pop
    const.i32 20
    const.i32 22
    add.i32
    ret.i32
.end
```

The string has 12 output bytes plus NUL. `stdout_write` returns the number
written; `pop` discards it. `main` returns 42.

Loop and scalar function:

```asm
.version 1.0
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
    sys stdout_i32
    const.i32 0
    ret.i32
.end
```

The assembler maps parameter `n` to slot 0 and locals `i`/`sum` to slots 1
and 2. `stdout_i32` consumes an i32 and returns void. The stack is empty at
both control-flow joins.

Canonical disassembly prints version, entry, declarations, then instructions
in table/byte order, with labels for branch targets and the defined literal
escaping. Assembly-disassembly-assembly preserves executable semantics,
not comments, whitespace, or original symbol spelling. DEBUG may be printed
as comments, but reassembly does not recreate it unless explicitly asked.
An ordinary library round-trip preserves unknown optional sections
byte-for-byte or reports preservation unsupported; only an explicit lossy
conversion may discard them.

## 6. Runtime services and I/O boundary

Service arguments are pushed left-to-right and consumed according to the
signature; ArrayRefs come from `array`, not a guest pointer. Services check
types and bounds, borrow arrays synchronously, and retain no references.
File handles are opaque and belong to one VM instance.

| ID | Assembly name | Exact VM signature | Contract |
|---:|---|---|---|
| 0 | `stdout_i32` | `(i32) -> void` | base-10 signed decimal, no newline |
| 1 | `stdout_byte` | `(u8) -> void` | write one raw byte |
| 2 | `stdout_write` | `(ArrayRef<u8>, i32 offset, i32 count) -> i32` | write up to count; return actual bytes |
| 3 | `stdin_byte` | `() -> i32` | 0..255, or -1 at EOF |
| 4 | `file_open_read` | `(ArrayRef<u8> nul_path) -> file` | open existing path for binary read |
| 5 | `file_open_write` | `(ArrayRef<u8> nul_path) -> file` | create/truncate for binary write |
| 6 | `file_read` | `(file, ArrayRef<u8>, i32 offset, i32 capacity) -> i32` | bytes read; zero is EOF |
| 7 | `file_write` | `(file, ArrayRef<u8>, i32 offset, i32 count) -> i32` | bytes written; may be short |
| 8 | `file_close` | `(file) -> void` | close and invalidate |

Offsets and counts are nonnegative and must fit the array. A read capacity
must be positive; reads may return 0..capacity, with zero meaning EOF, not
error. A write count may be zero (which returns zero); for positive counts,
writes may be short but must make progress, so the guest retries the
remainder and a zero-byte result is an I/O failure. Host I/O errors trap
distinctly, never become EOF, zero bytes, or a fake handle. Invalid,
foreign, stale, and closed handles trap.
Close failure reports I/O failure but still invalidates the handle. On
return, trap, or host cancellation, remaining handles are closed; cleanup
errors do not replace the primary failure. Host policy controls open-file,
memory, instruction, frame/recursion, and time limits.

`nul_path` is a fixed u8 array. The first NUL terminates a nonempty path;
preceding bytes must be valid UTF-8 and contain no NUL. Bytes after the
terminator are ignored. The service copies and validates the path
synchronously before passing a host path. This conversion is only for
filenames. File and standard-stream contents are bytes, never UTF-8 strings.

SmallC has no general pointers or array parameters. A future backend lowers
I/O intrinsics to `array name` plus `sys service`, using fixed-size local or
global byte arrays. It does not silently add array parameters to SmallC.
`file_open_*` copies the path before returning; read/write borrows a guest
buffer only until the service returns. Guest functions may exchange scalar
and file-handle values, but cannot return/retain ArrayRefs.

**Implemented file boundary:** the public SDK now provides
`File.readBytes(int)`, `readAllBytes()` and `writeBytes(buffer)` (Cwhip PR #20).
The CVM-owned `cvmfile` package handles EOF, partial transfers, `lastError()`
and explicit close through those APIs. See [the adapter contract](ASSEMBLER.md).
Guest stdin/file services remain interpreter work, including confirmation of
the stdin-byte interface. Arbitrary binary payloads must never pass through
UTF-8 text, CWhip Strings, or a private ABI.

## 7. Validation, failures, and host policy

The shared validator rejects bad magic/version/header, reserved bits,
unknown required sections, missing/duplicate sections, invalid ordering,
file-size mismatches, truncated/overflowing extents/counts, malformed
strings, invalid names/types/indexes/calls, overlapping function or data
ranges, invalid array initializers, unknown/truncated instructions,
out-of-function or non-boundary branches, stack underflow/type mismatch,
invalid ArrayRef use, inconsistent stack types/depth at joins, invalid
returns, reachable fallthrough, and incorrect maximum-stack declarations.
All size arithmetic is checked before slicing or allocation. Every
instruction is encoding/operand checked, including unreachable code;
dataflow stack/type checking and exact maximum depth apply to reachable
instructions. Cycles are allowed and bounded by host instruction budget.

Validation errors occur before execution. Runtime traps include arithmetic
and conversion failures, bounds errors, invalid handles, I/O errors, and
host-policy exhaustion. EOF and short writes are ordinary service results.
Filesystem permissions, path policy, allowed directories, and resource
limits are host configuration, not portable bytecode guarantees. CVM is
not a security sandbox; untrusted programs need separately designed and
reviewed host policy.

Diagnostics identify program, function name/index, and function-relative
instruction byte offset. DEBUG adds source file/line/column when present.
Validation, runtime, I/O, and host-limit failures have distinct categories.
Library callers receive a structured failure, not a display string to parse.

## 8. Implementation and acceptance stages

These are staged acceptance gates; completed subsets are described in the
implementation guides, not implied by the complete execution design:

1. **Shared library:** bytewise reader/writer, builder, canonical instruction
   schemas, and validator; publish/install from CVM and consume without
   duplicated tables.
2. **Format goldens:** check the 183-byte example and goldens for globals,
   arrays, calls, branches, and DEBUG with an independent decoder. Compare
   exact bytes across architectures.
3. **Assembler:** CVM-owned grammar, generated with the separately
   installed cparsegen during build; forward fixups, located diagnostics,
   file reload, structural validation and exact bytes are implemented.
   Canonical disassembly and semantic execution round trips remain later work.
4. **Interpreter:** per-opcode success/trap tests, calls, joins, result/error
   separation, and host-configurable limits.
5. **Host adapter:** confirm public SDK byte I/O; test EOF, errors, short
   reads/writes, stale/foreign handles, cleanup, and byte-exact round-trips.
6. **SmallC integration:** later test SmallC AST -> shared library -> binary
   -> independent VM for arrays, strings, scalar calls, loops, branches, and
   supported intrinsics. SmallC implementation is outside this design task.

Conformance includes malformed/truncated input, integer/extent overflow,
unknown opcodes/reserved bits, invalid branch boundaries, type/index/call
checks, every opcode's success and trap behavior, deterministic goldens,
assembler round trips, cross-architecture encoding, and an installed
shared-library consumer. Golden encodings must be checked by an independent
decoder, not only the encoder that emitted them.

## 9. v1 exclusions

No OOP, raw guest pointers, array parameters, closures, dynamic allocation,
floating point, bitwise instructions, JIT, threads, exceptions, native
linking, or implicit host ABI are defined. New opcodes, types, service IDs,
or container features require an explicit compatibility decision; reserved
values do not imply support.
