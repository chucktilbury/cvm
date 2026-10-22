namespace CVM {
    class Format {
        public:
        enum {
            HEADER_SIZE = 32,
            DIRECTORY_ENTRY_SIZE = 16,
            MAJOR_VERSION = 1,
            MINOR_VERSION = 0,
            CODE = 1,
            FUNCS = 2,
            TYPES = 3,
            GLOBALS = 4,
            ARRAYS = 5,
            DATA = 6,
            STRINGS = 7,
            DEBUG = 8,
            FUNCTION_SIZE = 28,
            GLOBAL_SIZE = 12,
            ARRAY_SIZE = 20,
            DEBUG_SIZE = 20
        }
    }

    class Opcode {
        public:
        enum {
            NOP = 0x00, CONST_I32 = 0x01, CONST_U8 = 0x02,
            LDLOC = 0x03, STLOC = 0x04, LDGLOBAL = 0x05,
            STGLOBAL = 0x06, ARRAY = 0x07, ALEN = 0x08,
            AGET = 0x09, ASET = 0x0a, ADD_I32 = 0x0b,
            SUB_I32 = 0x0c, MUL_I32 = 0x0d, DIV_I32 = 0x0e,
            REM_I32 = 0x0f, NEG_I32 = 0x10, EQ_I32 = 0x11,
            NE_I32 = 0x12, LT_I32 = 0x13, LE_I32 = 0x14,
            GT_I32 = 0x15, GE_I32 = 0x16, TO_U8 = 0x17,
            TO_I32 = 0x18, DUP = 0x19, POP = 0x1a,
            JMP = 0x1b, JZ = 0x1c, CALL = 0x1d, RET = 0x1e,
            RET_I32 = 0x1f, RET_U8 = 0x20, SYS = 0x21,
            RET_FILE = 0x22
        }

        bool isValid(int opcode) { return opcode >= NOP && opcode <= RET_FILE }

        int operandWidth(int opcode) {
            if (opcode == CONST_I32 || opcode == JMP || opcode == JZ) { return 4 }
            if (opcode == LDLOC || opcode == STLOC || opcode == LDGLOBAL || opcode == STGLOBAL || opcode == ARRAY || opcode == CALL) { return 2 }
            if (opcode == CONST_U8 || opcode == SYS) { return 1 }
            return 0
        }

        int operandKind(int opcode) {
            if (opcode == CONST_I32) { return 1 }
            if (opcode == CONST_U8 || opcode == SYS) { return 2 }
            if (opcode == LDLOC || opcode == STLOC) { return 3 }
            if (opcode == LDGLOBAL || opcode == STGLOBAL) { return 4 }
            if (opcode == ARRAY) { return 5 }
            if (opcode == JMP || opcode == JZ) { return 6 }
            if (opcode == CALL) { return 7 }
            return 0
        }

        String mnemonic(int opcode) {
            if (opcode == NOP) { return "nop" }
            if (opcode == CONST_I32) { return "const.i32" }
            if (opcode == CONST_U8) { return "const.u8" }
            if (opcode == LDLOC) { return "ldloc" }
            if (opcode == STLOC) { return "stloc" }
            if (opcode == LDGLOBAL) { return "ldglobal" }
            if (opcode == STGLOBAL) { return "stglobal" }
            if (opcode == ARRAY) { return "array" }
            if (opcode == ALEN) { return "alen" }
            if (opcode == AGET) { return "aget" }
            if (opcode == ASET) { return "aset" }
            if (opcode == ADD_I32) { return "add.i32" }
            if (opcode == SUB_I32) { return "sub.i32" }
            if (opcode == MUL_I32) { return "mul.i32" }
            if (opcode == DIV_I32) { return "div.i32" }
            if (opcode == REM_I32) { return "rem.i32" }
            if (opcode == NEG_I32) { return "neg.i32" }
            if (opcode == EQ_I32) { return "eq.i32" }
            if (opcode == NE_I32) { return "ne.i32" }
            if (opcode == LT_I32) { return "lt.i32" }
            if (opcode == LE_I32) { return "le.i32" }
            if (opcode == GT_I32) { return "gt.i32" }
            if (opcode == GE_I32) { return "ge.i32" }
            if (opcode == TO_U8) { return "to.u8" }
            if (opcode == TO_I32) { return "to.i32" }
            if (opcode == DUP) { return "dup" }
            if (opcode == POP) { return "pop" }
            if (opcode == JMP) { return "jmp" }
            if (opcode == JZ) { return "jz" }
            if (opcode == CALL) { return "call" }
            if (opcode == RET) { return "ret" }
            if (opcode == RET_I32) { return "ret.i32" }
            if (opcode == RET_U8) { return "ret.u8" }
            if (opcode == SYS) { return "sys" }
            if (opcode == RET_FILE) { return "ret.file" }
            return ""
        }

        String operandSchema(int opcode) {
            if (opcode == CONST_I32) { return "i32" }
            if (opcode == CONST_U8) { return "u8 value" }
            if (opcode == SYS) { return "u8 service number (0..8)" }
            if (opcode == LDLOC || opcode == STLOC) { return "u16 local index" }
            if (opcode == LDGLOBAL || opcode == STGLOBAL) { return "u16 global index" }
            if (opcode == ARRAY) { return "u16 array index" }
            if (opcode == JMP || opcode == JZ) { return "u32 function-relative target" }
            if (opcode == CALL) { return "u16 function index" }
            if (isValid(opcode)) { return "none" }
            return ""
        }

        String stackEffect(int opcode) {
            if (opcode == NOP) { return "S -> S" }
            if (opcode == CONST_I32) { return "S -> S,i32" }
            if (opcode == CONST_U8) { return "S -> S,u8" }
            if (opcode == LDLOC || opcode == LDGLOBAL) { return "S -> S,T" }
            if (opcode == STLOC || opcode == STGLOBAL) { return "S,T -> S,T" }
            if (opcode == ARRAY) { return "S -> S,Array<T>" }
            if (opcode == ALEN) { return "S,Array<T> -> S,i32" }
            if (opcode == AGET) { return "S,Array<T>,i32 -> S,T" }
            if (opcode == ASET) { return "S,Array<T>,i32,T -> S,T" }
            if (opcode == ADD_I32 || opcode == SUB_I32 || opcode == MUL_I32 || opcode == DIV_I32 || opcode == REM_I32 || opcode == EQ_I32 || opcode == NE_I32 || opcode == LT_I32 || opcode == LE_I32 || opcode == GT_I32 || opcode == GE_I32) { return "S,i32,i32 -> S,i32" }
            if (opcode == NEG_I32 || opcode == TO_U8 || opcode == TO_I32) { return "S,T -> S,T" }
            if (opcode == DUP) { return "S,T -> S,T,T" }
            if (opcode == POP) { return "S,T -> S" }
            if (opcode == JMP) { return "S -> S" }
            if (opcode == JZ) { return "S,i32 -> S" }
            if (opcode == CALL) { return "signature-dependent" }
            if (opcode == RET) { return "S -> return" }
            if (opcode == RET_I32 || opcode == RET_U8 || opcode == RET_FILE) { return "S,T -> return" }
            if (opcode == SYS) { return "service-dependent" }
            return ""
        }

        String operation(int opcode) {
            if (opcode == NOP) { return "no effect" }
            if (opcode == CONST_I32) { return "signed constant" }
            if (opcode == CONST_U8) { return "unsigned constant" }
            if (opcode == LDLOC || opcode == LDGLOBAL) { return "load typed value" }
            if (opcode == STLOC || opcode == STGLOBAL) { return "store typed value and leave it" }
            if (opcode == ARRAY) { return "reference a global or current-function array" }
            if (opcode == ALEN) { return "array element count" }
            if (opcode == AGET) { return "checked indexed load" }
            if (opcode == ASET) { return "checked indexed store and leave value" }
            if (opcode == ADD_I32) { return "checked left plus right" }
            if (opcode == SUB_I32) { return "checked left minus right" }
            if (opcode == MUL_I32) { return "checked multiply" }
            if (opcode == DIV_I32) { return "checked signed divide" }
            if (opcode == REM_I32) { return "checked signed remainder" }
            if (opcode == NEG_I32) { return "checked negation" }
            if (opcode == EQ_I32) { return "equal, result 0 or 1" }
            if (opcode == NE_I32) { return "not equal, result 0 or 1" }
            if (opcode == LT_I32) { return "signed less-than, result 0 or 1" }
            if (opcode == LE_I32) { return "signed less-than-or-equal, result 0 or 1" }
            if (opcode == GT_I32) { return "signed greater-than, result 0 or 1" }
            if (opcode == GE_I32) { return "signed greater-than-or-equal, result 0 or 1" }
            if (opcode == TO_U8) { return "checked conversion to 0..255" }
            if (opcode == TO_I32) { return "zero-extend u8 to i32" }
            if (opcode == DUP) { return "duplicate scalar or file value, not ArrayRef" }
            if (opcode == POP) { return "discard scalar or file value" }
            if (opcode == JMP) { return "branch to function-relative byte target" }
            if (opcode == JZ) { return "pop i32 and branch if zero" }
            if (opcode == CALL) { return "call indexed function" }
            if (opcode == RET) { return "return void" }
            if (opcode == RET_I32) { return "return i32" }
            if (opcode == RET_U8) { return "return u8" }
            if (opcode == SYS) { return "invoke synchronous host service" }
            if (opcode == RET_FILE) { return "return file handle" }
            return ""
        }
    }

    class Service {
        public:
        enum {
            STDOUT_I32 = 0, STDOUT_BYTE = 1, STDOUT_WRITE = 2,
            STDIN_BYTE = 3, FILE_OPEN_READ = 4, FILE_OPEN_WRITE = 5,
            FILE_READ = 6, FILE_WRITE = 7, FILE_CLOSE = 8
        }

        String name(int id) {
            if (id == STDOUT_I32) { return "stdout_i32" }
            if (id == STDOUT_BYTE) { return "stdout_byte" }
            if (id == STDOUT_WRITE) { return "stdout_write" }
            if (id == STDIN_BYTE) { return "stdin_byte" }
            if (id == FILE_OPEN_READ) { return "file_open_read" }
            if (id == FILE_OPEN_WRITE) { return "file_open_write" }
            if (id == FILE_READ) { return "file_read" }
            if (id == FILE_WRITE) { return "file_write" }
            if (id == FILE_CLOSE) { return "file_close" }
            return ""
        }

        int parameterCount(int id) {
            if (id == STDOUT_WRITE) { return 3 }
            if (id == FILE_READ || id == FILE_WRITE) { return 4 }
            if (id == STDIN_BYTE) { return 0 }
            if (id >= STDOUT_I32 && id <= FILE_CLOSE) { return 1 }
            return -1
        }

        int resultCount(int id) {
            if (id < STDOUT_I32 || id > FILE_CLOSE) { return -1 }
            if (id == STDOUT_I32 || id == STDOUT_BYTE || id == FILE_CLOSE) { return 0 }
            return 1
        }
    }

    class ByteWriter {
        private:
        buffer _bytes
        int _error

        public:
        enum { OK = 0, RANGE_ERROR = 1 }

        ByteWriter() {
            _bytes = buffer[]
            _error = OK
        }

        bool writeU8(int value) {
            if (_error != OK) { return false }
            if (value < 0 || value > 255) {
                _error = RANGE_ERROR
                return false
            }
            _bytes.append(value)
            return true
        }

        bool writeU16(int value) {
            if (_error != OK) { return false }
            if (value < 0 || value > 65535) {
                _error = RANGE_ERROR
                return false
            }
            _bytes.append(value % 256)
            _bytes.append((value / 256) % 256)
            return true
        }

        bool writeU32(unsigned value) {
            if (_error != OK) { return false }
            if (value > 4294967295u) {
                _error = RANGE_ERROR
                return false
            }
            _bytes.append(value % 256u)
            _bytes.append((value / 256u) % 256u)
            _bytes.append((value / 65536u) % 256u)
            _bytes.append((value / 16777216u) % 256u)
            return true
        }

        bool writeI32(int value) {
            if (_error != OK) { return false }
            if (value < -2147483648 || value > 2147483647) {
                _error = RANGE_ERROR
                return false
            }
            if (value < 0) { return writeU32(unsigned(value + 4294967296)) }
            return writeU32(unsigned(value))
        }

        int errorCode() { return _error }
        buffer bytes() { return _bytes }
    }

    class ByteReader {
        private:
        buffer _bytes
        int _offset
        int _error
        int _errorOffset

        public:
        enum { OK = 0, TRUNCATED = 1 }

        ByteReader(buffer bytes) {
            _bytes = bytes
            _offset = 0
            _error = OK
            _errorOffset = -1
        }

        void seek(int offset) {
            if (_error != OK) { return }
            if (offset < 0 || offset > _bytes.length) {
                _error = TRUNCATED
                _errorOffset = _offset
                return
            }
            _offset = offset
        }

        int readU8() {
            if (_error != OK) { return 0 }
            if (_offset < 0 || _offset >= _bytes.length) {
                _error = TRUNCATED
                _errorOffset = _offset
                return 0
            }
            int value = int(_bytes[_offset])
            _offset = _offset + 1
            return value
        }

        int readU16() {
            if (_error != OK) { return 0 }
            if (_offset < 0 || _bytes.length - _offset < 2) {
                _error = TRUNCATED
                _errorOffset = _offset
                return 0
            }
            int value = int(_bytes[_offset]) + int(_bytes[_offset + 1]) * 256
            _offset = _offset + 2
            return value
        }

        int readU32() {
            if (_error != OK) { return 0 }
            if (_offset < 0 || _bytes.length - _offset < 4) {
                _error = TRUNCATED
                _errorOffset = _offset
                return 0
            }
            int value = int(_bytes[_offset]) + int(_bytes[_offset + 1]) * 256 + int(_bytes[_offset + 2]) * 65536 + int(_bytes[_offset + 3]) * 16777216
            _offset = _offset + 4
            return value
        }

        int readI32() {
            int value = readU32()
            if (_error != OK) { return 0 }
            if (value >= 2147483648) { return value - 4294967296 }
            return value
        }

        int offset() { return _offset }
        int errorCode() { return _error }
        int errorOffset() { return _errorOffset }
    }

    class ValidationResult {
        private:
        int _code
        int _section
        int _offset
        String _message

        public:
        enum {
            OK = 0, TRUNCATED = 1, INVALID_MAGIC = 2,
            UNSUPPORTED_VERSION = 3, INVALID_HEADER = 4,
            INVALID_DIRECTORY = 5, INVALID_SECTION = 6,
            INVALID_INSTRUCTION = 7, INVALID_INDEX = 8,
            INVALID_RECORD = 9
        }

        ValidationResult(int code, int section, int offset, String message) {
            _code = code
            _section = section
            _offset = offset
            _message = message
        }

        bool valid() { return _code == OK }
        int code() { return _code }
        int section() { return _section }
        int offset() { return _offset }
        String message() { return _message }
    }

    class BuildResult {
        private:
        buffer _bytes
        int _code
        String _message

        public:
        BuildResult(buffer bytes, int code, String message) {
            _bytes = bytes
            _code = code
            _message = message
        }

        bool ok() { return _code == 0 }
        buffer bytes() { return _bytes }
        int code() { return _code }
        String message() { return _message }
    }

    class Section {
        private:
        int _kind
        int _flags
        int _count
        buffer _bytes
        int _offset
        int _length

        public:
        Section(int kind, int flags, int count, buffer bytes) {
            _kind = kind
            _flags = flags
            _count = count
            _bytes = bytes
            _offset = 0
            _length = bytes.length
        }

        int kind() { return _kind }
        int flags() { return _flags }
        int count() { return _count }
        buffer bytes() { return _bytes }
        int offset() { return _offset }
        int length() { return _length }
        void setExtent(int offset, int length) {
            _offset = offset
            _length = length
        }
    }

    class BranchTarget {
        private:
        int _functionOffset
        int _target

        public:
        BranchTarget(int functionOffset, int target) {
            _functionOffset = functionOffset
            _target = target
        }

        int functionOffset() { return _functionOffset }
        int target() { return _target }
    }

    class InstructionBuilder {
        private:
        buffer _code
        int _error
        String _message

        bool appendAll(buffer source) {
            int index = 0
            while (index < source.length) {
                _code.append(source[index])
                index = index + 1
            }
            return true
        }

        bool fail(int code, String message) {
            if (_error == 0) {
                _error = code
                _message = message
            }
            return false
        }

        public:
        enum { OK = 0, INVALID_VALUE = 1, INVALID_INSTRUCTION = 2 }

        InstructionBuilder() {
            _code = buffer[]
            _error = 0
            _message = ""
        }

        bool emit(int opcode, int operand) {
            if (_error != 0) { return false }
            Opcode schema = Opcode()
            if (!schema.isValid(opcode)) { return fail(INVALID_INSTRUCTION, "unknown opcode") }
            int width = schema.operandWidth(opcode)
            int kind = schema.operandKind(opcode)
            if (width == 0) { return fail(INVALID_INSTRUCTION, "opcode has no operand") }
            if (kind == 1 && (operand < -2147483648 || operand > 2147483647)) { return fail(INVALID_VALUE, "i32 operand out of range") }
            if (kind == 2 && (operand < 0 || operand > 255 || (opcode == Opcode.SYS && operand > 8))) { return fail(INVALID_VALUE, "u8 operand out of range") }
            if ((kind == 3 || kind == 4 || kind == 5 || kind == 7) && (operand < 0 || operand > 65535)) { return fail(INVALID_VALUE, "u16 operand out of range") }
            if (kind == 6 && (operand < 0 || operand > 4294967295)) { return fail(INVALID_VALUE, "branch target out of range") }
            _code.append(opcode)
            if (width == 1) {
                _code.append(operand)
            } else {
                if (width == 2) {
                    _code.append(operand % 256)
                    _code.append((operand / 256) % 256)
                } else {
                    ByteWriter writer = ByteWriter()
                    if (kind == 1) { writer.writeI32(operand) }
                    else { writer.writeU32(unsigned(operand)) }
                    appendAll(writer.bytes())
                }
            }
            return true
        }

        bool emitNoOperand(int opcode) {
            if (_error != 0) { return false }
            Opcode schema = Opcode()
            if (!schema.isValid(opcode) || schema.operandWidth(opcode) != 0) { return fail(INVALID_INSTRUCTION, "invalid no-operand opcode") }
            _code.append(opcode)
            return true
        }

        buffer bytes() { return _code }
        int errorCode() { return _error }
        String errorMessage() { return _message }
    }

    class ContainerBuilder {
        private:
        list _sections
        buffer _code
        buffer _functions
        buffer _types
        buffer _globals
        buffer _arrays
        buffer _data
        buffer _strings
        buffer _debug
        int _debugCount
        bool _debugSet
        list _optionalSections
        list _functionNames
        list _globalNames
        list _arrayNames
        int _entry
        int _error
        String _message

        bool appendAll(buffer target, buffer source) {
            int index = 0
            while (index < source.length) {
                target.append(source[index])
                index = index + 1
            }
            return true
        }

        int sectionCount(Section section) {
            int kind = section.kind()
            if (kind == Format.CODE || kind == Format.TYPES || kind == Format.DATA || kind == Format.STRINGS) { return section.bytes().length }
            if (kind == Format.FUNCS) { return _functions.length / Format.FUNCTION_SIZE }
            if (kind == Format.GLOBALS) { return _globals.length / Format.GLOBAL_SIZE }
            if (kind == Format.ARRAYS) { return _arrays.length / Format.ARRAY_SIZE }
            return section.count()
        }

        int appendString(String value) {
            int offset = _strings.length
            int index = 0
            while (index < value.length) {
                _strings.append(value.byteAt(index))
                index = index + 1
            }
            _strings.append(0)
            return offset
        }

        bool validIdentifier(String value) {
            if (value == null || value.length == 0) { return false }
            int index = 0
            while (index < value.length) {
                int current = int(value.byteAt(index))
                bool letter = (current >= 65 && current <= 90) || (current >= 97 && current <= 122) || current == 95
                bool digit = current >= 48 && current <= 57
                if (index == 0 && !letter) { return false }
                if (index > 0 && !letter && !digit) { return false }
                index = index + 1
            }
            return true
        }

        bool fail(int code, String message) {
            if (_error == 0) {
                _error = code
                _message = message
            }
            return false
        }

        bool nameExists(list names, String value) {
            int index = 0
            while (index < names.length) {
                String previous = names[index] as String
                if (previous.equals(value)) { return true }
                index = index + 1
            }
            return false
        }

        public:
        enum { OK = 0, INVALID_VALUE = 1, LIMIT_EXCEEDED = 2, INVALID_INSTRUCTION = 3 }

        ContainerBuilder() {
            _sections = []
            _code = buffer[]
            _functions = buffer[]
            _types = buffer[]
            _globals = buffer[]
            _arrays = buffer[]
            _data = buffer[]
            _strings = buffer[]
            _debug = buffer[]
            _debugCount = 0
            _debugSet = false
            _optionalSections = []
            _functionNames = []
            _globalNames = []
            _arrayNames = []
            _entry = 0
            _error = 0
            _message = ""
            _sections.append(Section(Format.CODE, 0, 0, _code))
            _sections.append(Section(Format.FUNCS, 0, 0, _functions))
            _sections.append(Section(Format.TYPES, 0, 0, _types))
            _sections.append(Section(Format.GLOBALS, 0, 0, _globals))
            _sections.append(Section(Format.ARRAYS, 0, 0, _arrays))
            _sections.append(Section(Format.DATA, 0, 0, _data))
            _sections.append(Section(Format.STRINGS, 0, 0, _strings))
        }

        bool setEntry(int functionIndex) {
            if (_error != 0) { return false }
            if (functionIndex < 0 || functionIndex > 65534) { return fail(INVALID_VALUE, "entry index is out of range") }
            _entry = functionIndex
            return true
        }

        bool addFunction(String name, buffer code, buffer localTypes, int parameterCount, int localCount, int maximumStack, int returnType) {
            if (_error != 0) { return false }
            if (!validIdentifier(name) || code == null || localTypes == null || code.length == 0 || parameterCount < 0 || parameterCount > 65535 || localCount < 0 || localCount > 65535 || parameterCount + localCount > 65536 || localTypes.length != parameterCount + localCount || maximumStack < 0 || maximumStack > 65535 || returnType < 0 || returnType > 3) { return fail(INVALID_VALUE, "invalid function metadata") }
            if (_functionNames.length >= 65535 || _code.length > 4294967295 - code.length || _types.length > 4294967295 - localTypes.length || _strings.length > 4294967295 - name.length - 1) { return fail(LIMIT_EXCEEDED, "function exceeds v1 limits") }
            if (nameExists(_functionNames, name)) { return fail(INVALID_VALUE, "duplicate function name") }
            int index = 0
            while (index < localTypes.length) {
                int valueType = int(localTypes[index])
                if (valueType < 1 || valueType > 3) { return fail(INVALID_VALUE, "invalid function parameter/local type") }
                index = index + 1
            }
            int nameOffset = appendString(name)
            _functionNames.append(name)
            ByteWriter record = ByteWriter()
            record.writeU32(unsigned(nameOffset))
            record.writeU32(unsigned(_code.length))
            record.writeU32(unsigned(code.length))
            record.writeU32(unsigned(_types.length))
            record.writeU16(parameterCount)
            record.writeU16(localCount)
            record.writeU16(maximumStack)
            record.writeU16(0)
            record.writeU8(returnType)
            record.writeU8(0)
            record.writeU8(0)
            record.writeU8(0)
            appendAll(_functions, record.bytes())
            appendAll(_types, localTypes)
            appendAll(_code, code)
            return true
        }

        bool addGlobal(String name, int valueType, int initialValue) {
            if (_error != 0) { return false }
            if (!validIdentifier(name) || nameExists(_globalNames, name) || (valueType != 1 && valueType != 2) || initialValue < -2147483648 || initialValue > 2147483647 || (valueType == 2 && (initialValue < 0 || initialValue > 255)) || _globals.length / Format.GLOBAL_SIZE >= 65536 || _strings.length > 4294967295 - name.length - 1) { return fail(INVALID_VALUE, "invalid global metadata") }
            int nameOffset = appendString(name)
            _globalNames.append(name)
            ByteWriter record = ByteWriter()
            record.writeU32(unsigned(nameOffset))
            record.writeU8(valueType)
            record.writeU8(0)
            record.writeU8(0)
            record.writeU8(0)
            record.writeI32(initialValue)
            appendAll(_globals, record.bytes())
            return true
        }

        bool addArray(String name, int ownerFunction, int elementType, int length, buffer initialData) {
            if (_error != 0) { return false }
            if (!validIdentifier(name) || nameExists(_arrayNames, name) || (ownerFunction != 65535 && (ownerFunction < 0 || ownerFunction >= _functionNames.length)) || (elementType != 1 && elementType != 2) || length <= 0 || length > 4294967295 || initialData == null || _arrays.length / Format.ARRAY_SIZE >= 65536 || _strings.length > 4294967295 - name.length - 1) { return fail(INVALID_VALUE, "invalid array metadata") }
            int width = 1
            if (elementType == 1) { width = 4 }
            if (initialData.length != 0 && (initialData.length != length * width || _data.length > 4294967295 - initialData.length)) { return fail(INVALID_VALUE, "array initializer length is invalid") }
            int nameOffset = appendString(name)
            _arrayNames.append(name)
            int flags = 1
            int dataOffset = _data.length
            if (initialData.length == 0) {
                flags = 0
                dataOffset = -1
            }
            ByteWriter record = ByteWriter()
            record.writeU32(unsigned(nameOffset))
            record.writeU16(ownerFunction)
            record.writeU8(elementType)
            record.writeU8(flags)
            record.writeU32(unsigned(length))
            if (flags == 0) { record.writeU32(4294967295u) }
            else {
                record.writeU32(unsigned(dataOffset))
                appendAll(_data, initialData)
            }
            record.writeU32(0u)
            appendAll(_arrays, record.bytes())
            return true
        }

        bool setDebug(buffer records, int count) {
            if (_error != 0) { return false }
            if (_debugSet || records == null || count < 0 || count > 4294967295 / Format.DEBUG_SIZE || records.length != count * Format.DEBUG_SIZE) { return fail(INVALID_VALUE, "invalid DEBUG section") }
            _debug = records
            _debugCount = count
            _debugSet = true
            return true
        }

        bool addOptionalSection(int kind, buffer bytes, int count) {
            if (_error != 0) { return false }
            if ((kind >= Format.CODE && kind <= Format.DEBUG) || kind < 0 || kind > 65535 || bytes == null || count < 0 || count > 4294967295 || _optionalSections.length >= 65527) { return fail(INVALID_VALUE, "invalid optional section") }
            if (_optionalSections.length > 0) {
                Section previous = _optionalSections[_optionalSections.length - 1] as Section
                if (kind <= previous.kind()) { return fail(INVALID_VALUE, "optional sections must be added in ascending kind order") }
            }
            _optionalSections.append(Section(kind, 1, count, bytes))
            return true
        }

        int errorCode() { return _error }
        String errorMessage() { return _message }

        BuildResult encode() {
            if (_error != 0) { return BuildResult(buffer[], _error, _message) }
            if (_functionNames.length == 0 || _entry >= _functionNames.length) { return BuildResult(buffer[], INVALID_VALUE, "entry function is missing") }
            _sections = []
            int optionalIndex = 0
            while (optionalIndex < _optionalSections.length) {
                Section optional = _optionalSections[optionalIndex] as Section
                if (optional.kind() >= Format.CODE) { break }
                _sections.append(optional)
                optionalIndex = optionalIndex + 1
            }
            _sections.append(Section(Format.CODE, 0, 0, _code))
            _sections.append(Section(Format.FUNCS, 0, 0, _functions))
            _sections.append(Section(Format.TYPES, 0, 0, _types))
            _sections.append(Section(Format.GLOBALS, 0, 0, _globals))
            _sections.append(Section(Format.ARRAYS, 0, 0, _arrays))
            _sections.append(Section(Format.DATA, 0, 0, _data))
            _sections.append(Section(Format.STRINGS, 0, 0, _strings))
            if (_debugSet) { _sections.append(Section(Format.DEBUG, 1, _debugCount, _debug)) }
            while (optionalIndex < _optionalSections.length) {
                _sections.append(_optionalSections[optionalIndex] as Section)
                optionalIndex = optionalIndex + 1
            }
            if (_sections.length > 65535) { return BuildResult(buffer[], LIMIT_EXCEEDED, "too many sections") }
            int fileSize = Format.HEADER_SIZE + _sections.length * Format.DIRECTORY_ENTRY_SIZE
            list lengths = []
            int index = 0
            while (index < _sections.length) {
                Section section = _sections[index] as Section
                int size = section.bytes().length
                if (size > 4294967295 - fileSize) { return BuildResult(buffer[], LIMIT_EXCEEDED, "container exceeds v1 size limit") }
                lengths.append(size)
                fileSize = fileSize + size
                index = index + 1
            }
            ByteWriter writer = ByteWriter()
            writer.writeU8(0x43)
            writer.writeU8(0x56)
            writer.writeU8(0x4d)
            writer.writeU8(0)
            writer.writeU16(Format.MAJOR_VERSION)
            writer.writeU16(Format.MINOR_VERSION)
            writer.writeU16(Format.HEADER_SIZE)
            writer.writeU16(0)
            writer.writeU16(_sections.length)
            writer.writeU16(0)
            writer.writeU32(unsigned(_entry))
            writer.writeU32(unsigned(Format.HEADER_SIZE))
            writer.writeU32(unsigned(fileSize))
            writer.writeU32(unsigned(0))
            int sectionOffset = Format.HEADER_SIZE + _sections.length * Format.DIRECTORY_ENTRY_SIZE
            index = 0
            while (index < _sections.length) {
                Section section = _sections[index] as Section
                int size = lengths[index] as int
                writer.writeU16(section.kind())
                writer.writeU16(section.flags())
                writer.writeU32(unsigned(sectionOffset))
                writer.writeU32(unsigned(size))
                writer.writeU32(unsigned(sectionCount(section)))
                sectionOffset = sectionOffset + size
                index = index + 1
            }
            index = 0
            while (index < _sections.length) {
                Section section = _sections[index] as Section
                appendAll(writer.bytes(), section.bytes())
                index = index + 1
            }
            if (writer.errorCode() != 0 || writer.bytes().length != fileSize) { return BuildResult(buffer[], LIMIT_EXCEEDED, "container encoding failed") }
            ValidationResult validation = ContainerValidator().validate(writer.bytes())
            if (!validation.valid()) { return BuildResult(buffer[], validation.code(), validation.message()) }
            return BuildResult(writer.bytes(), 0, "")
        }
    }

    class ContainerValidator {
        private:
        Section findSection(list sections, int kind) {
            int index = 0
            while (index < sections.length) {
                Section section = sections[index] as Section
                if (section.kind() == kind) { return section }
                index = index + 1
            }
            return null
        }

        ValidationResult reject(int code, int section, int offset, String message) {
            return ValidationResult(code, section, offset, message)
        }

        bool validName(buffer bytes, int stringsStart, int stringsLength, int offset) {
            if (offset < 0 || offset >= stringsLength) { return false }
            int cursor = stringsStart + offset
            int end = stringsStart + stringsLength
            bool first = true
            while (cursor < end) {
                int value = int(bytes[cursor])
                if (value == 0) { return !first }
                bool letter = (value >= 65 && value <= 90) || (value >= 97 && value <= 122) || value == 95
                bool digit = value >= 48 && value <= 57
                if (first && !letter) { return false }
                if (!first && !letter && !digit) { return false }
                first = false
                cursor = cursor + 1
            }
            return false
        }

        bool sameName(buffer bytes, int stringsStart, int first, int second) {
            int left = stringsStart + first
            int right = stringsStart + second
            while (int(bytes[left]) == int(bytes[right])) {
                if (int(bytes[left]) == 0) { return true }
                left = left + 1
                right = right + 1
            }
            return false
        }

        public:
        ValidationResult validate(buffer bytes) {
            if (bytes == null || bytes.length < Format.HEADER_SIZE) { return reject(ValidationResult.TRUNCATED, 0, 0, "truncated header") }
            ByteReader reader = ByteReader(bytes)
            if (reader.readU8() != 0x43 || reader.readU8() != 0x56 || reader.readU8() != 0x4d || reader.readU8() != 0) { return reject(ValidationResult.INVALID_MAGIC, 0, 0, "invalid CVM magic") }
            int major = reader.readU16()
            int minor = reader.readU16()
            int headerSize = reader.readU16()
            int headerFlags = reader.readU16()
            int sectionCount = reader.readU16()
            int reserved16 = reader.readU16()
            int entry = reader.readU32()
            int directoryOffset = reader.readU32()
            int fileSize = reader.readU32()
            int reserved32 = reader.readU32()
            if (major != Format.MAJOR_VERSION || minor != Format.MINOR_VERSION) { return reject(ValidationResult.UNSUPPORTED_VERSION, 0, 4, "unsupported bytecode version") }
            if (headerSize != Format.HEADER_SIZE || headerFlags != 0 || reserved16 != 0 || reserved32 != 0 || directoryOffset != Format.HEADER_SIZE || sectionCount < 7) { return reject(ValidationResult.INVALID_HEADER, 0, 8, "invalid header fields") }
            if (fileSize != bytes.length) { return reject(ValidationResult.INVALID_HEADER, 0, 24, "file size differs from input length") }
            if (sectionCount > (bytes.length - Format.HEADER_SIZE) / Format.DIRECTORY_ENTRY_SIZE) { return reject(ValidationResult.TRUNCATED, 0, Format.HEADER_SIZE, "truncated section directory") }
            list sections = []
            int expectedOffset = Format.HEADER_SIZE + sectionCount * Format.DIRECTORY_ENTRY_SIZE
            int previousKind = -1
            int index = 0
            while (index < sectionCount) {
                int at = Format.HEADER_SIZE + index * Format.DIRECTORY_ENTRY_SIZE
                reader.seek(at)
                int kind = reader.readU16()
                int flags = reader.readU16()
                int offset = reader.readU32()
                int length = reader.readU32()
                int count = reader.readU32()
                if (kind <= previousKind) { return reject(ValidationResult.INVALID_DIRECTORY, kind, at, "section kinds must be unique and ascending") }
                if (offset != expectedOffset || offset > fileSize || length > fileSize - offset) { return reject(ValidationResult.INVALID_SECTION, kind, at + 4, "section extent is invalid") }
                if (kind >= Format.CODE && kind <= Format.STRINGS && flags != 0) { return reject(ValidationResult.INVALID_SECTION, kind, at + 2, "required section flags must be zero") }
                if (kind == Format.DEBUG && flags != 1) { return reject(ValidationResult.INVALID_SECTION, kind, at + 2, "DEBUG must be optional") }
                if ((kind < Format.CODE || kind > Format.DEBUG) && flags != 1) { return reject(ValidationResult.INVALID_SECTION, kind, at + 2, "unknown required section") }
                int recordSize = 0
                if (kind == Format.FUNCS) { recordSize = Format.FUNCTION_SIZE }
                if (kind == Format.GLOBALS) { recordSize = Format.GLOBAL_SIZE }
                if (kind == Format.ARRAYS) { recordSize = Format.ARRAY_SIZE }
                if (kind == Format.DEBUG) { recordSize = Format.DEBUG_SIZE }
                if (recordSize == 0) {
                    if (kind >= Format.CODE && kind <= Format.STRINGS && count != length) { return reject(ValidationResult.INVALID_SECTION, kind, at + 12, "byte count differs from section length") }
                } else {
                    if (count > 4294967295 / recordSize || count * recordSize != length) { return reject(ValidationResult.INVALID_SECTION, kind, at + 8, "record count differs from section length") }
                }
                sections.append(Section(kind, flags, count, buffer[]))
                Section current = sections[sections.length - 1] as Section
                current.setExtent(offset, length)
                expectedOffset = offset + length
                previousKind = kind
                index = index + 1
            }
            if (expectedOffset != fileSize) { return reject(ValidationResult.INVALID_SECTION, 0, expectedOffset, "last section does not end at file size") }
            index = 1
            while (index <= 7) {
                if (findSection(sections, index) == null) { return reject(ValidationResult.INVALID_DIRECTORY, index, Format.HEADER_SIZE, "required section is missing") }
                index = index + 1
            }
            Section code = findSection(sections, Format.CODE)
            Section functions = findSection(sections, Format.FUNCS)
            Section types = findSection(sections, Format.TYPES)
            Section globals = findSection(sections, Format.GLOBALS)
            Section arrays = findSection(sections, Format.ARRAYS)
            Section strings = findSection(sections, Format.STRINGS)
            if (functions.count() > 65535 || globals.count() > 65536 || arrays.count() > 65536) { return reject(ValidationResult.INVALID_SECTION, 0, Format.HEADER_SIZE, "table exceeds v1 index limits") }
            if (functions.count() == 0 || entry >= functions.count()) { return reject(ValidationResult.INVALID_INDEX, Format.FUNCS, 16, "entry function index is invalid") }
            buffer boundaries = buffer(code.length())
            list branches = []
            list functionNames = []
            int nextCode = 0
            index = 0
            while (index < functions.count()) {
                int at = functions.offset() + index * Format.FUNCTION_SIZE
                reader.seek(at)
                int nameOffset = reader.readU32()
                int codeOffset = reader.readU32()
                int codeLength = reader.readU32()
                int typeOffset = reader.readU32()
                int parameterCount = reader.readU16()
                int localCount = reader.readU16()
                int maximumStack = reader.readU16()
                int functionFlags = reader.readU16()
                int returnType = reader.readU8()
                int r0 = reader.readU8()
                int r1 = reader.readU8()
                int r2 = reader.readU8()
                int slots = parameterCount + localCount
                if (codeLength == 0 || codeOffset != nextCode || codeOffset > code.length() || codeLength > code.length() - codeOffset) { return reject(ValidationResult.INVALID_RECORD, Format.FUNCS, at + 4, "function code extent is invalid") }
                if (slots > 65536 || typeOffset > types.length() || slots > types.length() - typeOffset || returnType > 3 || functionFlags != 0 || r0 != 0 || r1 != 0 || r2 != 0) { return reject(ValidationResult.INVALID_RECORD, Format.FUNCS, at + 12, "function metadata is invalid") }
                if (!validName(bytes, strings.offset(), strings.length(), nameOffset)) { return reject(ValidationResult.INVALID_RECORD, Format.FUNCS, at, "function name is not a valid ASCII identifier") }
                int nameIndex = 0
                while (nameIndex < functionNames.length) {
                    int previousName = functionNames[nameIndex] as int
                    if (sameName(bytes, strings.offset(), previousName, nameOffset)) { return reject(ValidationResult.INVALID_RECORD, Format.FUNCS, at, "function name is duplicated") }
                    nameIndex = nameIndex + 1
                }
                functionNames.append(nameOffset)
                int typeIndex = 0
                while (typeIndex < slots) {
                    int valueType = int(bytes[types.offset() + typeOffset + typeIndex])
                    if (valueType < 1 || valueType > 3) { return reject(ValidationResult.INVALID_RECORD, Format.TYPES, typeOffset + typeIndex, "invalid function parameter/local type") }
                    typeIndex = typeIndex + 1
                }
                int cursor = 0
                while (cursor < codeLength) {
                    boundaries[codeOffset + cursor] = 1
                    int instructionAt = code.offset() + codeOffset + cursor
                    reader.seek(instructionAt)
                    int opcode = reader.readU8()
                    Opcode schema = Opcode()
                    if (!schema.isValid(opcode)) { return reject(ValidationResult.INVALID_INSTRUCTION, Format.CODE, instructionAt, "unknown opcode") }
                    int width = schema.operandWidth(opcode)
                    if (width > codeLength - cursor - 1) { return reject(ValidationResult.TRUNCATED, Format.CODE, instructionAt, "truncated instruction operand") }
                    int kind = schema.operandKind(opcode)
                    int operand = 0
                    if (width == 1) { operand = reader.readU8() }
                    if (width == 2) { operand = reader.readU16() }
                    if (width == 4) { operand = reader.readU32() }
                    if (kind == 2 && opcode == Opcode.SYS && operand > 8) { return reject(ValidationResult.INVALID_INDEX, Format.CODE, instructionAt + 1, "unknown service number") }
                    if ((kind == 3 && operand >= slots) || (kind == 4 && operand >= globals.count()) || (kind == 5 && operand >= arrays.count()) || (kind == 7 && operand >= functions.count())) { return reject(ValidationResult.INVALID_INDEX, Format.CODE, instructionAt + 1, "instruction index is invalid") }
                    if (kind == 6) {
                        if (operand >= codeLength) { return reject(ValidationResult.INVALID_INDEX, Format.CODE, instructionAt + 1, "branch target outside function") }
                        branches.append(BranchTarget(codeOffset, operand))
                    }
                    cursor = cursor + 1 + width
                }
                nextCode = codeOffset + codeLength
                index = index + 1
            }
            if (nextCode != code.length()) { return reject(ValidationResult.INVALID_RECORD, Format.FUNCS, functions.offset(), "function code does not cover CODE") }
            index = 0
            while (index < branches.length) {
                BranchTarget branch = branches[index] as BranchTarget
                if (int(boundaries[branch.functionOffset() + branch.target()]) == 0) { return reject(ValidationResult.INVALID_INDEX, Format.CODE, code.offset() + branch.functionOffset() + branch.target(), "branch target is not an instruction boundary") }
                index = index + 1
            }
            return ValidationResult(ValidationResult.OK, 0, -1, "")
        }
    }

    class ContainerDecodeResult {
        private:
        buffer _bytes
        ValidationResult _validation

        int directoryValue(int kind, int field) {
            if (!valid()) { return -1 }
            int index = 0
            ByteReader reader = ByteReader(_bytes)
            while (index < directoryCount()) {
                int at = Format.HEADER_SIZE + index * Format.DIRECTORY_ENTRY_SIZE
                reader.seek(at)
                int currentKind = reader.readU16()
                reader.readU16()
                int sectionOffset = reader.readU32()
                int sectionLength = reader.readU32()
                int count = reader.readU32()
                if (currentKind == kind) {
                    if (field == 0) { return sectionOffset }
                    if (field == 1) { return sectionLength }
                    return count
                }
                index = index + 1
            }
            return -1
        }

        public:
        ContainerDecodeResult(buffer bytes, ValidationResult validation) {
            _bytes = bytes
            _validation = validation
        }

        bool valid() { return _validation.valid() }
        ValidationResult validation() { return _validation }
        int entryFunction() {
            if (!valid()) { return -1 }
            ByteReader reader = ByteReader(_bytes)
            reader.seek(16)
            return reader.readU32()
        }

        int directoryCount() {
            if (!valid()) { return 0 }
            ByteReader reader = ByteReader(_bytes)
            reader.seek(12)
            return reader.readU16()
        }

        int countForSection(int kind) { return directoryValue(kind, 2) }

        buffer sectionBytes(int kind) {
            int offset = directoryValue(kind, 0)
            int length = directoryValue(kind, 1)
            if (offset < 0 || length < 0) { return null }
            return _bytes[offset:offset + length]
        }
    }

    class ContainerDecoder {
        public:
        ContainerDecodeResult decode(buffer bytes) {
            ValidationResult validation = ContainerValidator().validate(bytes)
            return ContainerDecodeResult(bytes, validation)
        }
    }
}
