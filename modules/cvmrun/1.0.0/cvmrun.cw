import cvm as CVM
import process as Proc
import system as Sys

namespace CVMRun {
    class Limits {
        private:
        int64 _programBytes
        int64 _instructions
        int64 _stackValues
        int64 _callDepth
        int64 _heapBytes

        public:
        enum {
            DEFAULT_PROGRAM_BYTES = 16777216,
            DEFAULT_INSTRUCTIONS = 1000000,
            DEFAULT_STACK_VALUES = 65536,
            DEFAULT_CALL_DEPTH = 256,
            DEFAULT_HEAP_BYTES = 16777216,
            ARRAY_INSTANCE_OVERHEAD = 256,
            MAX_PROGRAM_BYTES = 67108864,
            MAX_INSTRUCTIONS = 100000000,
            MAX_STACK_VALUES = 1048576,
            MAX_CALL_DEPTH = 4096,
            MAX_HEAP_BYTES = 268435456
        }

        Limits() {
            _programBytes = DEFAULT_PROGRAM_BYTES
            _instructions = DEFAULT_INSTRUCTIONS
            _stackValues = DEFAULT_STACK_VALUES
            _callDepth = DEFAULT_CALL_DEPTH
            _heapBytes = DEFAULT_HEAP_BYTES
        }

        Limits(int64 programBytes, int64 instructions, int64 stackValues, int64 callDepth, int64 heapBytes) {
            _programBytes = programBytes
            _instructions = instructions
            _stackValues = stackValues
            _callDepth = callDepth
            _heapBytes = heapBytes
        }

        bool valid() {
            return _programBytes > 0 && _programBytes <= MAX_PROGRAM_BYTES && _instructions > 0 && _instructions <= MAX_INSTRUCTIONS && _stackValues > 0 && _stackValues <= MAX_STACK_VALUES && _callDepth > 0 && _callDepth <= MAX_CALL_DEPTH && _heapBytes >= 0 && _heapBytes <= MAX_HEAP_BYTES
        }

        int64 programBytes() { return _programBytes }
        int64 instructions() { return _instructions }
        int64 stackValues() { return _stackValues }
        int64 callDepth() { return _callDepth }
        int64 heapBytes() { return _heapBytes }
    }

    class Capabilities {
        private:
        bool _stdin
        bool _stdout
        bool _files
        int64 _maxOpenFiles

        public:
        enum { DEFAULT_MAX_OPEN_FILES = 64, MAX_OPEN_FILES = 4096 }

        Capabilities() {
            _stdin = true
            _stdout = true
            _files = true
            _maxOpenFiles = DEFAULT_MAX_OPEN_FILES
        }

        Capabilities(bool stdinEnabled, bool stdoutEnabled, bool filesEnabled,
                     int64 maxOpenFiles) {
            _stdin = stdinEnabled
            _stdout = stdoutEnabled
            _files = filesEnabled
            _maxOpenFiles = maxOpenFiles
        }

        bool valid() { return _maxOpenFiles >= 0 && _maxOpenFiles <= MAX_OPEN_FILES }
        bool stdinEnabled() { return _stdin }
        bool stdoutEnabled() { return _stdout }
        bool filesEnabled() { return _files }
        int64 maxOpenFiles() { return _maxOpenFiles }
    }

    class ExecutionResult {
        private:
        int64 _category
        int64 _guestResult
        String _message
        int64 _section
        int64 _byteOffset
        int64 _functionIndex
        String _functionName
        int64 _instructionOffset
        int64 _instructionsExecuted

        public:
        enum {
            SUCCESS = 0,
            LOAD_ERROR = 1,
            VALIDATION_ERROR = 2,
            RUNTIME_TRAP = 3,
            UNSUPPORTED_SERVICE = 4,
            RESOURCE_LIMIT = 5,
            IO_ERROR = 6,
            CONFIGURATION_ERROR = 7
        }

        ExecutionResult(int64 category, int64 guestResult, String message,
                        int64 section, int64 byteOffset, int64 functionIndex,
                        String functionName, int64 instructionOffset, int64 steps) {
            _category = category
            _guestResult = guestResult
            _message = message
            _section = section
            _byteOffset = byteOffset
            _functionIndex = functionIndex
            _functionName = functionName
            _instructionOffset = instructionOffset
            _instructionsExecuted = steps
        }

        bool ok() { return _category == SUCCESS }
        int64 category() { return _category }
        int64 guestResult() { return _guestResult }
        String message() { return _message }
        int64 section() { return _section }
        int64 byteOffset() { return _byteOffset }
        int64 functionIndex() { return _functionIndex }
        String functionName() { return _functionName }
        int64 instructionOffset() { return _instructionOffset }
        int64 instructionsExecuted() { return _instructionsExecuted }
    }

    class Value {
        private:
        int64 _type
        int64 _number
        ArrayInstance _array
        bool _initialized

        public:
        enum { I32 = 1, U8 = 2, FILE = 3, ARRAY_REF = 4 }

        Value(int64 valueType, int64 number, ArrayInstance array, bool initialized) {
            _type = valueType
            _number = number
            _array = array
            _initialized = initialized
        }

        int64 valueType() { return _type }
        int64 number() { return _number }
        ArrayInstance array() { return _array }
        bool initialized() { return _initialized }
    }

    class FunctionInfo {
        private:
        String _name
        int64 _codeOffset
        int64 _codeLength
        int64 _typeOffset
        int64 _parameters
        int64 _locals
        int64 _maximumStack
        int64 _returnType
        list _localArrayIndexes

        public:
        FunctionInfo(String name, int64 codeOffset, int64 codeLength, int64 typeOffset,
                     int64 parameters, int64 locals, int64 maximumStack, int64 returnType) {
            _name = name
            _codeOffset = codeOffset
            _codeLength = codeLength
            _typeOffset = typeOffset
            _parameters = parameters
            _locals = locals
            _maximumStack = maximumStack
            _returnType = returnType
            _localArrayIndexes = []
        }

        String name() { return _name }
        int64 codeOffset() { return _codeOffset }
        int64 codeLength() { return _codeLength }
        int64 typeOffset() { return _typeOffset }
        int64 parameters() { return _parameters }
        int64 locals() { return _locals }
        int64 maximumStack() { return _maximumStack }
        int64 returnType() { return _returnType }
        list localArrayIndexes() { return _localArrayIndexes }
        void addLocalArray(int64 index) { _localArrayIndexes.append(index) }
    }

    class ArrayInfo {
        private:
        int64 _owner
        int64 _elementType
        int64 _length
        bool _initialized
        int64 _dataOffset

        public:
        ArrayInfo(int64 owner, int64 elementType, int64 length, bool initialized, int64 dataOffset) {
            _owner = owner
            _elementType = elementType
            _length = length
            _initialized = initialized
            _dataOffset = dataOffset
        }

        int64 owner() { return _owner }
        int64 elementType() { return _elementType }
        int64 length() { return _length }
        bool initialized() { return _initialized }
        int64 dataOffset() { return _dataOffset }
    }

    class ArrayInstance {
        private:
        int64 _index
        int64 _elementType
        int64 _length
        buffer _bytes
        bool _alive
        int64 _heapBytes

        public:
        ArrayInstance(int64 index, int64 elementType, int64 length, buffer bytes, int64 heapBytes) {
            _index = index
            _elementType = elementType
            _length = length
            _bytes = bytes
            _alive = true
            _heapBytes = heapBytes
        }

        int64 index() { return _index }
        int64 elementType() { return _elementType }
        int64 length() { return _length }
        buffer bytes() { return _bytes }
        bool alive() { return _alive }
        int64 heapBytes() { return _heapBytes }
        void kill() { _alive = false }
    }

    class HostFile {
        private:
        int64 _id
        Sys.File _file
        bool _open
        bool _integerHandle

        public:
        HostFile(int64 id, Sys.File file, bool integerHandle) {
            _id = id
            _file = file
            _open = true
            _integerHandle = integerHandle
        }

        int64 id() { return _id }
        Sys.File file() { return _file }
        bool open() { return _open }
        bool integerHandle() { return _integerHandle }
        void invalidate() { _open = false }
    }

    class Frame {
        private:
        int64 _functionIndex
        int64 _pc
        int64 _stackBase
        int64 _callOffset
        list _locals
        list _localArrays
        bool _active

        public:
        Frame(int64 functionIndex, int64 pc, int64 stackBase, int64 callOffset, list locals) {
            _functionIndex = functionIndex
            _pc = pc
            _stackBase = stackBase
            _callOffset = callOffset
            _locals = locals
            _localArrays = []
            _active = true
        }

        int64 functionIndex() { return _functionIndex }
        int64 pc() { return _pc }
        void setPc(int64 pc) { _pc = pc }
        int64 stackBase() { return _stackBase }
        int64 callOffset() { return _callOffset }
        list locals() { return _locals }
        list localArrays() { return _localArrays }
        bool active() { return _active }
        void addArray(ArrayInstance array) { _localArrays.append(array) }
        void kill() { _active = false }
    }

    class VirtualMachine {
        private:
        list _functions
        list _globals
        list _arrayInfos
        list _globalArrays
        list _frames
        list _stack
        buffer _code
        buffer _types
        buffer _data
        Limits _limits
        Capabilities _capabilities
        ExecutionResult _failure
        list _fileHandles
        Sys.File _stdinFile
        bool _stdinOpen
        int64 _nextFileHandle
        int64 _entry
        int64 _steps
        int64 _heapBytes
        int64 _activeSlots
        int64 _activeOffset
        int64 _guestResult
        bool _completed

        void reset(Limits limits) {
            _functions = []
            _globals = []
            _arrayInfos = []
            _globalArrays = []
            _frames = []
            _stack = []
            _code = buffer[]
            _types = buffer[]
            _data = buffer[]
            _limits = limits
            _capabilities = Capabilities()
            _failure = null
            _fileHandles = []
            _stdinFile = null
            _stdinOpen = false
            if (_nextFileHandle <= 0) { _nextFileHandle = 1 }
            _entry = -1
            _steps = 0
            _heapBytes = 0
            _activeSlots = 0
            _activeOffset = 0
            _guestResult = 0
            _completed = false
        }

        int64 byteAt(buffer bytes, int64 offset, int64 section) {
            if (bytes == null || offset < 0 || offset >= bytes.length) {
                loadFailure(section, offset, "truncated section data")
                return 0
            }
            return int64(bytes[offset])
        }

        int64 u16At(buffer bytes, int64 offset, int64 section) {
            if (bytes == null || offset < 0 || offset > bytes.length || bytes.length - offset < 2) {
                loadFailure(section, offset, "truncated 16-bit field")
                return 0
            }
            return int64(bytes[offset]) + int64(bytes[offset + 1]) * 256
        }

        int64 u32At(buffer bytes, int64 offset, int64 section) {
            if (bytes == null || offset < 0 || offset > bytes.length || bytes.length - offset < 4) {
                loadFailure(section, offset, "truncated 32-bit field")
                return 0
            }
            return int64(bytes[offset]) + int64(bytes[offset + 1]) * 256 + int64(bytes[offset + 2]) * 65536 + int64(bytes[offset + 3]) * 16777216
        }

        int64 i32At(buffer bytes, int64 offset, int64 section) {
            int64 value = u32At(bytes, offset, section)
            if (_failure != null) { return 0 }
            if (value >= 2147483648) { return value - 4294967296 }
            return value
        }

        void loadFailure(int64 section, int64 offset, String message) {
            if (_failure == null) {
                _failure = ExecutionResult(ExecutionResult.LOAD_ERROR, 0, message,
                    section, offset, -1, "", -1, _steps)
            }
        }

        void validationFailure(CVM.ValidationResult validation) {
            _failure = ExecutionResult(ExecutionResult.VALIDATION_ERROR, 0,
                validation.message(), validation.section(), validation.offset(),
                -1, "", -1, _steps)
        }

        void failAt(int64 category, String message, int64 functionIndex, int64 offset) {
            if (_failure != null) { return }
            String name = ""
            if (functionIndex >= 0 && functionIndex < _functions.length) {
                FunctionInfo function = _functions[functionIndex] as FunctionInfo
                name = function.name()
            }
            _failure = ExecutionResult(category, 0, message, 0, -1,
                functionIndex, name, offset, _steps)
        }

        void trap(int64 category, String message) {
            Frame frame = null
            int64 functionIndex = -1
            int64 offset = _activeOffset
            if (_frames.length > 0) {
                frame = _frames[_frames.length - 1] as Frame
                functionIndex = frame.functionIndex()
            }
            failAt(category, message, functionIndex, offset)
        }

        String nameAt(buffer strings, int64 offset) {
            if (offset < 0 || offset >= strings.length) {
                loadFailure(CVM.Format.STRINGS, offset, "function name offset is outside STRINGS")
                return ""
            }
            String name = ""
            int64 cursor = offset
            bool terminated = false
            while (cursor < strings.length && !terminated) {
                int64 byte = int64(strings[cursor])
                if (byte == 0) { terminated = true }
                else {
                    if (byte >= 128) {
                        loadFailure(CVM.Format.STRINGS, cursor, "function name is not ASCII")
                        return ""
                    }
                    name.append(format("{:c}", byte))
                    cursor = cursor + 1
                }
            }
            if (!terminated) { loadFailure(CVM.Format.STRINGS, offset, "unterminated function name") }
            return name
        }

        bool load(CVM.ContainerDecodeResult decoded) {
            buffer functions = decoded.sectionBytes(CVM.Format.FUNCS)
            buffer globals = decoded.sectionBytes(CVM.Format.GLOBALS)
            buffer arrays = decoded.sectionBytes(CVM.Format.ARRAYS)
            buffer strings = decoded.sectionBytes(CVM.Format.STRINGS)
            _code = decoded.sectionBytes(CVM.Format.CODE)
            _types = decoded.sectionBytes(CVM.Format.TYPES)
            _data = decoded.sectionBytes(CVM.Format.DATA)
            _entry = decoded.entryFunction()
            if (functions == null || globals == null || arrays == null || strings == null || _code == null || _types == null || _data == null) {
                loadFailure(0, 0, "validated container is missing a required section")
                return false
            }

            if (functions.length % CVM.Format.FUNCTION_SIZE != 0 || globals.length % CVM.Format.GLOBAL_SIZE != 0 || arrays.length % CVM.Format.ARRAY_SIZE != 0) {
                loadFailure(0, 0, "record section has an invalid length")
                return false
            }
            if (functions.length / CVM.Format.FUNCTION_SIZE > 65535 || globals.length / CVM.Format.GLOBAL_SIZE > 65536 || arrays.length / CVM.Format.ARRAY_SIZE > 65536) {
                loadFailure(0, 0, "function, global, or array table exceeds v1 index limits")
                return false
            }

            int64 offset = 0
            while (offset < functions.length && _failure == null) {
                int64 nameOffset = u32At(functions, offset, CVM.Format.FUNCS)
                int64 codeOffset = u32At(functions, offset + 4, CVM.Format.FUNCS)
                int64 codeLength = u32At(functions, offset + 8, CVM.Format.FUNCS)
                int64 typeOffset = u32At(functions, offset + 12, CVM.Format.FUNCS)
                int64 parameters = u16At(functions, offset + 16, CVM.Format.FUNCS)
                int64 locals = u16At(functions, offset + 18, CVM.Format.FUNCS)
                int64 maximumStack = u16At(functions, offset + 20, CVM.Format.FUNCS)
                int64 returnType = byteAt(functions, offset + 24, CVM.Format.FUNCS)
                if (_failure != null) { return false }
                String name = nameAt(strings, nameOffset)
                if (_failure != null) { return false }
                if (parameters + locals > 65536 || codeLength <= 0 || codeOffset < 0 || codeOffset > _code.length || codeLength > _code.length - codeOffset || typeOffset < 0 || typeOffset > _types.length || parameters + locals > _types.length - typeOffset || returnType < 0 || returnType > 3) {
                    loadFailure(CVM.Format.FUNCS, offset, "function metadata is outside its validated section")
                    return false
                }
                int64 typeIndex = 0
                while (typeIndex < parameters + locals) {
                    int64 valueType = int64(_types[typeOffset + typeIndex])
                    if (valueType < Value.I32 || valueType > Value.FILE) {
                        loadFailure(CVM.Format.TYPES, typeOffset + typeIndex, "invalid local or parameter type")
                        return false
                    }
                    typeIndex = typeIndex + 1
                }
                _functions.append(FunctionInfo(name, codeOffset, codeLength, typeOffset,
                    parameters, locals, maximumStack, returnType))
                offset = offset + CVM.Format.FUNCTION_SIZE
            }
            if (_failure != null) { return false }

            offset = 0
            while (offset < globals.length && _failure == null) {
                int64 valueType = byteAt(globals, offset + 4, CVM.Format.GLOBALS)
                int64 initial = i32At(globals, offset + 8, CVM.Format.GLOBALS)
                if (_failure != null) { return false }
                if ((valueType != Value.I32 && valueType != Value.U8) || (valueType == Value.U8 && (initial < 0 || initial > 255))) {
                    loadFailure(CVM.Format.GLOBALS, offset + 4, "invalid global type or initial value")
                    return false
                }
                int64 reserved = byteAt(globals, offset + 5, CVM.Format.GLOBALS) + byteAt(globals, offset + 6, CVM.Format.GLOBALS) + byteAt(globals, offset + 7, CVM.Format.GLOBALS)
                if (_failure != null) { return false }
                if (reserved != 0) {
                    loadFailure(CVM.Format.GLOBALS, offset + 5, "global reserved bytes are nonzero")
                    return false
                }
                _globals.append(Value(valueType, initial, null, true))
                offset = offset + CVM.Format.GLOBAL_SIZE
            }
            if (_failure != null) { return false }

            offset = 0
            while (offset < arrays.length && _failure == null) {
                int64 owner = u16At(arrays, offset + 4, CVM.Format.ARRAYS)
                int64 elementType = byteAt(arrays, offset + 6, CVM.Format.ARRAYS)
                int64 flags = byteAt(arrays, offset + 7, CVM.Format.ARRAYS)
                int64 length = u32At(arrays, offset + 8, CVM.Format.ARRAYS)
                int64 dataOffset = u32At(arrays, offset + 12, CVM.Format.ARRAYS)
                int64 reserved = u32At(arrays, offset + 16, CVM.Format.ARRAYS)
                if (_failure != null) { return false }
                if ((owner != 65535 && owner >= _functions.length) || (elementType != Value.I32 && elementType != Value.U8) || (flags != 0 && flags != 1) || length <= 0 || reserved != 0) {
                    loadFailure(CVM.Format.ARRAYS, offset + 4, "invalid array metadata")
                    return false
                }
                int64 width = 1
                if (elementType == Value.I32) { width = 4 }
                if (_limits.heapBytes() < Limits.ARRAY_INSTANCE_OVERHEAD || length > (_limits.heapBytes() - Limits.ARRAY_INSTANCE_OVERHEAD) / width) {
                    failAt(ExecutionResult.RESOURCE_LIMIT,
                        "array storage exceeds configured heap limit",
                        -1, -1)
                    return false
                }
                int64 storageBytes = length * width
                if (flags == 1) {
                    if (dataOffset < 0 || dataOffset > _data.length || storageBytes > _data.length - dataOffset) {
                        loadFailure(CVM.Format.ARRAYS, offset + 12, "array initializer is outside DATA")
                        return false
                    }
                    int64 priorIndex = 0
                    while (priorIndex < _arrayInfos.length) {
                        ArrayInfo prior = _arrayInfos[priorIndex] as ArrayInfo
                        if (prior.initialized()) {
                            int64 priorWidth = 1
                            if (prior.elementType() == Value.I32) { priorWidth = 4 }
                            int64 priorBytes = prior.length() * priorWidth
                            if (dataOffset < prior.dataOffset() + priorBytes && prior.dataOffset() < dataOffset + storageBytes) {
                                loadFailure(CVM.Format.ARRAYS, offset + 12, "array initializer ranges overlap")
                                return false
                            }
                        }
                        priorIndex = priorIndex + 1
                    }
                } else {
                    if (dataOffset != 4294967295) {
                        loadFailure(CVM.Format.ARRAYS, offset + 12, "uninitialized array has a data offset")
                        return false
                    }
                }
                ArrayInfo info = ArrayInfo(owner, elementType, length, flags == 1, dataOffset)
                _arrayInfos.append(info)
                if (owner == 65535) {
                    ArrayInstance instance = createArray(_arrayInfos.length - 1, info)
                    if (instance == null) { return false }
                    _globalArrays.append(instance)
                } else {
                    FunctionInfo function = _functions[owner] as FunctionInfo
                    function.addLocalArray(_arrayInfos.length - 1)
                    _globalArrays.append(null)
                }
                offset = offset + CVM.Format.ARRAY_SIZE
            }
            if (_failure != null) { return false }
            if (_entry < 0 || _entry >= _functions.length) {
                loadFailure(CVM.Format.FUNCS, 0, "entry function index is invalid")
                return false
            }
            FunctionInfo entryFunction = _functions[_entry] as FunctionInfo
            if (!entryFunction.name().equals("main") || entryFunction.parameters() != 0 || entryFunction.returnType() != Value.I32) {
                failAt(ExecutionResult.LOAD_ERROR,
                    "entry function must have signature main() -> i32",
                    _entry, -1)
                return false
            }
            return true
        }

        ArrayInstance createArray(int64 index, ArrayInfo info) {
            int64 width = 1
            if (info.elementType() == Value.I32) { width = 4 }
            if (info.length() > _limits.heapBytes() / width) {
                trap(ExecutionResult.RESOURCE_LIMIT, "array storage exceeds configured heap limit")
                return null
            }
            int64 size = info.length() * width
            int64 chargedBytes = size + Limits.ARRAY_INSTANCE_OVERHEAD
            if (chargedBytes > _limits.heapBytes() - _heapBytes) {
                trap(ExecutionResult.RESOURCE_LIMIT, "array storage exceeds configured heap limit")
                return null
            }
            buffer bytes = buffer(size)
            if (info.initialized()) {
                int64 indexInArray = 0
                while (indexInArray < size) {
                    bytes[indexInArray] = _data[info.dataOffset() + indexInArray]
                    indexInArray = indexInArray + 1
                }
            }
            _heapBytes = _heapBytes + chargedBytes
            return ArrayInstance(index, info.elementType(), info.length(), bytes, chargedBytes)
        }

        int64 localType(FunctionInfo function, int64 index) {
            if (index < 0 || index >= function.parameters() + function.locals()) { return 0 }
            return int64(_types[function.typeOffset() + index])
        }

        Value defaultLocal(int64 valueType) {
            return Value(valueType, 0, null, false)
        }

        void contextualizeFrameFailure(int64 functionIndex) {
            if (_failure == null || _frames.length != 0 || functionIndex < 0 || functionIndex >= _functions.length) { return }
            FunctionInfo function = _functions[functionIndex] as FunctionInfo
            _failure = ExecutionResult(_failure.category(), 0, _failure.message(),
                _failure.section(), _failure.byteOffset(), functionIndex,
                function.name(), 0, _steps)
        }

        bool pushFrame(int64 functionIndex, int64 callOffset) {
            if (functionIndex < 0 || functionIndex >= _functions.length) {
                trap(ExecutionResult.RUNTIME_TRAP, "call target function index is invalid")
                return false
            }
            if (_frames.length >= _limits.callDepth()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "call depth limit exceeded")
                return false
            }
            FunctionInfo function = _functions[functionIndex] as FunctionInfo
            int64 argumentCount = function.parameters()
            Frame caller = currentFrame()
            int64 available = _stack.length
            if (caller != null) { available = available - caller.stackBase() }
            if (available < argumentCount) {
                trap(ExecutionResult.RUNTIME_TRAP, "call argument stack underflow")
                return false
            }
            int64 argumentStart = _stack.length - argumentCount
            if (_activeSlots + _stack.length + function.locals() > _limits.stackValues()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "active local and operand value limit exceeded")
                contextualizeFrameFailure(functionIndex)
                return false
            }
            int64 index = 0
            while (index < argumentCount) {
                Value argument = _stack[argumentStart + index] as Value
                if (argument == null || !argument.initialized() || argument.valueType() != localType(function, index)) {
                    trap(ExecutionResult.RUNTIME_TRAP,
                        format("call argument {} has the wrong type", index))
                    return false
                }
                index = index + 1
            }
            list locals = []
            index = 0
            while (index < argumentCount + function.locals()) {
                int64 slotType = localType(function, index)
                if (index < argumentCount) {
                    locals.append(_stack[argumentStart + index])
                } else {
                    locals.append(defaultLocal(slotType))
                }
                index = index + 1
            }
            Frame frame = Frame(functionIndex, 0, argumentStart, callOffset, locals)
            list localIndexes = function.localArrayIndexes()
            index = 0
            while (index < localIndexes.length) {
                int64 arrayIndex = localIndexes[index] as int64
                ArrayInfo info = _arrayInfos[arrayIndex] as ArrayInfo
                ArrayInstance instance = createArray(arrayIndex, info)
                if (instance == null) {
                    contextualizeFrameFailure(functionIndex)
                    return false
                }
                frame.addArray(instance)
                index = index + 1
            }
            _stack.resize(argumentStart)
            _frames.append(frame)
            _activeSlots = _activeSlots + argumentCount + function.locals()
            return true
        }

        Frame currentFrame() {
            if (_frames.length == 0) { return null }
            return _frames[_frames.length - 1] as Frame
        }

        FunctionInfo currentFunction() {
            Frame frame = currentFrame()
            if (frame == null) { return null }
            return _functions[frame.functionIndex()] as FunctionInfo
        }

        bool push(Value value) {
            Frame frame = currentFrame()
            if (frame == null) {
                trap(ExecutionResult.RUNTIME_TRAP, "missing execution frame")
                return false
            }
            if (_activeSlots + _stack.length >= _limits.stackValues()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "active local and operand value limit exceeded")
                return false
            }
            FunctionInfo function = currentFunction()
            if (_stack.length - frame.stackBase() >= function.maximumStack()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "function maximum stack declaration exceeded")
                return false
            }
            _stack.append(value)
            return true
        }

        Value popAny() {
            Frame frame = currentFrame()
            if (frame == null || _stack.length <= frame.stackBase()) {
                trap(ExecutionResult.RUNTIME_TRAP, "operand stack underflow")
                return null
            }
            Value value = _stack[_stack.length - 1] as Value
            _stack.resize(_stack.length - 1)
            if (value == null || !value.initialized()) {
                trap(ExecutionResult.RUNTIME_TRAP, "uninitialized operand stack value")
                return null
            }
            return value
        }

        Value popType(int64 expectedType) {
            Value value = popAny()
            if (value == null || _failure != null) { return null }
            if (value.valueType() != expectedType) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("expected {}, found {}", typeName(expectedType), typeName(value.valueType())))
                return null
            }
            return value
        }

        String typeName(int64 valueType) {
            if (valueType == Value.I32) { return "i32" }
            if (valueType == Value.U8) { return "u8" }
            if (valueType == Value.FILE) { return "file" }
            if (valueType == Value.ARRAY_REF) { return "ArrayRef" }
            return "invalid value"
        }

        int64 readCodeByte(Frame frame, FunctionInfo function, int64 relativeOffset) {
            if (relativeOffset < 0 || relativeOffset >= function.codeLength()) {
                trap(ExecutionResult.RUNTIME_TRAP, "instruction operand extends past function")
                return 0
            }
            int64 absoluteOffset = function.codeOffset() + relativeOffset
            if (absoluteOffset < 0 || absoluteOffset >= _code.length) {
                trap(ExecutionResult.RUNTIME_TRAP, "instruction offset is outside CODE")
                return 0
            }
            return int64(_code[absoluteOffset])
        }

        int64 readOperand(Frame frame, FunctionInfo function, int64 width) {
            int64 operandOffset = frame.pc()
            if (operandOffset < 0 || operandOffset > function.codeLength() || width > function.codeLength() - operandOffset) {
                trap(ExecutionResult.RUNTIME_TRAP, "truncated instruction operand")
                return 0
            }
            int64 value = 0
            if (width == 1) {
                value = readCodeByte(frame, function, operandOffset)
            }
            if (width == 2) {
                value = readCodeByte(frame, function, operandOffset) + readCodeByte(frame, function, operandOffset + 1) * 256
            }
            if (width == 4) {
                value = readCodeByte(frame, function, operandOffset) + readCodeByte(frame, function, operandOffset + 1) * 256 + readCodeByte(frame, function, operandOffset + 2) * 65536 + readCodeByte(frame, function, operandOffset + 3) * 16777216
            }
            if (_failure == null) { frame.setPc(operandOffset + width) }
            return value
        }

        ArrayInstance arrayFor(Frame frame, int64 index) {
            if (index < 0 || index >= _arrayInfos.length) {
                trap(ExecutionResult.RUNTIME_TRAP, "array index is invalid")
                return null
            }
            ArrayInfo info = _arrayInfos[index] as ArrayInfo
            if (info.owner() == 65535) {
                if (index >= _globalArrays.length) {
                    trap(ExecutionResult.RUNTIME_TRAP, "global array storage is missing")
                    return null
                }
                ArrayInstance instance = _globalArrays[index] as ArrayInstance
                if (instance == null || !instance.alive()) {
                    trap(ExecutionResult.RUNTIME_TRAP, "global array storage is unavailable")
                    return null
                }
                return instance
            }
            if (info.owner() != frame.functionIndex()) {
                trap(ExecutionResult.RUNTIME_TRAP, "array belongs to a different function")
                return null
            }
            list localIndexes = currentFunction().localArrayIndexes()
            list localArrays = frame.localArrays()
            int64 localIndex = 0
            while (localIndex < localIndexes.length) {
                if ((localIndexes[localIndex] as int64) == index) {
                    if (localIndex >= localArrays.length) { break }
                    ArrayInstance instance = localArrays[localIndex] as ArrayInstance
                    if (instance == null || !instance.alive()) { break }
                    return instance
                }
                localIndex = localIndex + 1
            }
            trap(ExecutionResult.RUNTIME_TRAP, "local array storage is unavailable")
            return null
        }

        bool validArrayReference(Value value) {
            if (value == null || value.valueType() != Value.ARRAY_REF || value.array() == null || !value.array().alive()) {
                trap(ExecutionResult.RUNTIME_TRAP, "invalid or expired ArrayRef")
                return false
            }
            return true
        }

        bool serviceAvailable(bool enabled, String serviceName) {
            if (!enabled) {
                trap(ExecutionResult.UNSUPPORTED_SERVICE,
                    format("host capability for '{}' is disabled", serviceName))
                return false
            }
            return true
        }

        int64 openResourceCount() {
            int64 count = _fileHandles.length
            if (_stdinOpen) { count = count + 1 }
            return count
        }

        bool checkOpenResourceLimit() {
            if (openResourceCount() >= _capabilities.maxOpenFiles()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "open file handle limit exceeded")
                return false
            }
            return true
        }

        HostFile findFileHandle(int64 id, bool integerHandle) {
            int64 index = 0
            while (index < _fileHandles.length) {
                HostFile hostFile = _fileHandles[index] as HostFile
                if (hostFile != null && hostFile.open() && hostFile.id() == id &&
                    hostFile.integerHandle() == integerHandle) {
                    return hostFile
                }
                index = index + 1
            }
            return null
        }

        void removeFileHandle(HostFile removed) {
            int64 index = 0
            while (index < _fileHandles.length) {
                HostFile hostFile = _fileHandles[index] as HostFile
                if (hostFile != null && hostFile.id() == removed.id()) {
                    hostFile.invalidate()
                    int64 last = _fileHandles.length - 1
                    if (index != last) { _fileHandles[index] = _fileHandles[last] }
                    _fileHandles.resize(last)
                    return
                }
                index = index + 1
            }
            removed.invalidate()
        }

        bool closeFileHandle(HostFile hostFile, bool reportFailure) {
            String error = ""
            try {
                hostFile.file().close()
                error = Sys.System().lastError()
            } except(Exception) as caught {
                error = caught.message
            }
            removeFileHandle(hostFile)
            if (!error.equals("")) {
                if (reportFailure) {
                    trap(ExecutionResult.IO_ERROR,
                        format("closing file handle {}: {}", hostFile.id(), error))
                } else {
                    failAt(ExecutionResult.IO_ERROR,
                        format("closing file handle {} during cleanup: {}", hostFile.id(), error),
                        _entry, _activeOffset)
                }
                return false
            }
            return true
        }

        void closeOwnedResources() {
            while (_fileHandles.length > 0) {
                HostFile hostFile = _fileHandles[_fileHandles.length - 1] as HostFile
                closeFileHandle(hostFile, false)
            }
            if (_stdinOpen) {
                String error = ""
                try {
                    _stdinFile.close()
                    error = Sys.System().lastError()
                } except(Exception) as caught {
                    error = caught.message
                }
                _stdinFile = null
                _stdinOpen = false
                if (!error.equals("") && _failure == null) {
                    failAt(ExecutionResult.IO_ERROR,
                        format("closing binary stdin during cleanup: {}", error),
                        _entry, _activeOffset)
                }
            }
        }

        String decodePath(ArrayInstance instance) {
            if (instance.elementType() != Value.U8) {
                trap(ExecutionResult.RUNTIME_TRAP, "file path array must contain u8 elements")
                return null
            }
            int64 cursor = 0
            bool terminated = false
            while (cursor < instance.length() && !terminated && _failure == null) {
                int64 first = int64(instance.bytes()[cursor])
                if (first == 0) {
                    terminated = true
                } else {
                    int64 width = 1
                    if (first >= 194 && first <= 223) { width = 2 }
                    else {
                        if (first >= 224 && first <= 239) { width = 3 }
                        else {
                            if (first >= 240 && first <= 244) { width = 4 }
                            else {
                                if (first >= 128) {
                                    trap(ExecutionResult.RUNTIME_TRAP,
                                        "file path is not valid UTF-8")
                                    return null
                                }
                            }
                        }
                    }
                    if (width > instance.length() - cursor) {
                        trap(ExecutionResult.RUNTIME_TRAP,
                            "file path is not NUL-terminated valid UTF-8")
                        return null
                    }
                    int64 continuationIndex = 1
                    while (continuationIndex < width) {
                        int64 next = int64(instance.bytes()[cursor + continuationIndex])
                        bool validContinuation = next >= 128 && next <= 191
                        if (continuationIndex == 1) {
                            if (first == 224 && next < 160) { validContinuation = false }
                            if (first == 237 && next > 159) { validContinuation = false }
                            if (first == 240 && next < 144) { validContinuation = false }
                            if (first == 244 && next > 143) { validContinuation = false }
                        }
                        if (!validContinuation) {
                            trap(ExecutionResult.RUNTIME_TRAP,
                                "file path is not valid UTF-8")
                            return null
                        }
                        continuationIndex = continuationIndex + 1
                    }
                    cursor = cursor + width
                }
            }
            if (_failure != null) { return null }
            if (!terminated) {
                trap(ExecutionResult.RUNTIME_TRAP, "file path is not NUL-terminated")
                return null
            }
            if (cursor == 0) {
                trap(ExecutionResult.RUNTIME_TRAP, "file path cannot be empty")
                return null
            }
            buffer encodedPath = buffer(cursor)
            int64 index = 0
            while (index < cursor) {
                encodedPath[index] = instance.bytes()[index]
                index = index + 1
            }
            try {
                return Proc.Runtime().textDecode(encodedPath)
            } except(Exception) as caught {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("unable to decode file path as UTF-8: {}", caught.message))
                return null
            }
        }

        bool checkByteArrayRange(ArrayInstance instance, int64 offset, int64 count,
                                 bool allowZero, String operation) {
            if (instance.elementType() != Value.U8) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("{} buffer must contain u8 elements", operation))
                return false
            }
            if (!allowZero && count == 0) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("{} count must be positive", operation))
                return false
            }
            if (offset < 0 || count < 0 ||
                offset > instance.length() || count > instance.length() - offset) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("{} offset/count is outside the byte array", operation))
                return false
            }
            return true
        }

        String decodeFileMode(ArrayInstance instance) {
            if (instance.elementType() != Value.U8 || instance.length() < 2) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    "file mode must be a NUL-terminated u8 array containing exactly r, w, or a")
                return null
            }
            int64 mode = int64(instance.bytes()[0])
            if (int64(instance.bytes()[1]) != 0 || (mode != 114 && mode != 119 && mode != 97)) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    "file mode must be exactly r, w, or a followed by NUL")
                return null
            }
            if (mode == 114) { return "rb" }
            if (mode == 119) { return "wb" }
            return "ab"
        }

        bool checkIOError(String operation, String error) {
            if (!error.equals("")) {
                trap(ExecutionResult.IO_ERROR, format("{}: {}", operation, error))
                return false
            }
            return true
        }

        bool canPushServiceResult() {
            Frame frame = currentFrame()
            FunctionInfo function = currentFunction()
            if (frame == null || function == null) {
                trap(ExecutionResult.RUNTIME_TRAP, "missing execution frame")
                return false
            }
            if (_activeSlots + _stack.length >= _limits.stackValues()) {
                trap(ExecutionResult.RESOURCE_LIMIT,
                    "active local and operand value limit exceeded")
                return false
            }
            if (_stack.length - frame.stackBase() >= function.maximumStack()) {
                trap(ExecutionResult.RESOURCE_LIMIT,
                    "function maximum stack declaration exceeded")
                return false
            }
            return true
        }

        bool executeService(int64 service) {
            CVM.Service schema = CVM.Service()
            String serviceName = schema.name(service)
            if (serviceName.equals("")) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("invalid host service {}", service))
                return false
            }

            if (service == CVM.Service.STDOUT_I32) {
                Value value = popType(Value.I32)
                if (value == null || _failure != null) { return false }
                if (!serviceAvailable(_capabilities.stdoutEnabled(), serviceName)) { return false }
                String text = format("{}", value.number())
                Sys.StandardIO io = Sys.StandardIO()
                int64 written = -1
                String error = ""
                try {
                    written = io.write(text)
                    error = Sys.System().lastError()
                    if (error.equals("") && written == text.length) {
                        io.flush()
                        error = Sys.System().lastError()
                    }
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("writing stdout", error)) { return false }
                if (written != text.length) {
                    trap(ExecutionResult.IO_ERROR, "writing stdout made incomplete progress")
                    return false
                }
                return true
            }

            if (service == CVM.Service.STDOUT_BYTE) {
                Value value = popType(Value.U8)
                if (value == null || _failure != null) { return false }
                if (!serviceAvailable(_capabilities.stdoutEnabled(), serviceName)) { return false }
                buffer bytes = buffer(1)
                bytes[0] = uint8(value.number())
                Sys.StandardIO io = Sys.StandardIO()
                int64 written = -1
                String error = ""
                try {
                    written = io.writeBytes(bytes)
                    error = Sys.System().lastError()
                    if (error.equals("") && written == 1) {
                        io.flush()
                        error = Sys.System().lastError()
                    }
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("writing stdout byte", error)) { return false }
                if (written != 1) {
                    trap(ExecutionResult.IO_ERROR, "writing stdout byte made incomplete progress")
                    return false
                }
                return true
            }

            if (service == CVM.Service.STDOUT_WRITE) {
                Value countValue = popType(Value.I32)
                if (countValue == null || _failure != null) { return false }
                Value offsetValue = popType(Value.I32)
                if (offsetValue == null || _failure != null) { return false }
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                int64 offset = offsetValue.number()
                int64 count = countValue.number()
                ArrayInstance instance = reference.array()
                if (!checkByteArrayRange(instance, offset, count, true, "stdout_write")) { return false }
                if (!serviceAvailable(_capabilities.stdoutEnabled(), serviceName)) { return false }
                if (!canPushServiceResult()) { return false }
                if (count == 0) { return push(Value(Value.I32, 0, null, true)) }
                buffer chunk = instance.bytes()[offset:offset + count]
                Sys.StandardIO io = Sys.StandardIO()
                int64 written = -1
                String error = ""
                try {
                    written = io.writeBytes(chunk)
                    error = Sys.System().lastError()
                    if (error.equals("") && written > 0) {
                        io.flush()
                        error = Sys.System().lastError()
                    }
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("writing stdout bytes", error)) { return false }
                if (written <= 0 || written > count) {
                    trap(ExecutionResult.IO_ERROR, "stdout write made invalid progress")
                    return false
                }
                return push(Value(Value.I32, written, null, true))
            }

            if (service == CVM.Service.STDIN_BYTE) {
                if (!serviceAvailable(_capabilities.stdinEnabled(), serviceName)) { return false }
                if (!canPushServiceResult()) { return false }
                if (!_stdinOpen) {
                    if (!checkOpenResourceLimit()) { return false }
                    try {
                        _stdinFile = Sys.File("/dev/stdin", "rb")
                        _stdinOpen = true
                    } except(Exception) as caught {
                        trap(ExecutionResult.IO_ERROR,
                            format("opening binary stdin: {}", caught.message))
                        return false
                    }
                }
                buffer byte = buffer[]
                String error = ""
                try {
                    byte = _stdinFile.readBytes(1)
                    error = Sys.System().lastError()
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("reading stdin byte", error)) { return false }
                if (byte == null || byte.length > 1) {
                    trap(ExecutionResult.IO_ERROR, "stdin byte read returned invalid data")
                    return false
                }
                if (byte.length == 1) {
                    return push(Value(Value.I32, int64(byte[0]), null, true))
                }
                bool atEnd = false
                try {
                    atEnd = _stdinFile.eof()
                    error = Sys.System().lastError()
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("checking stdin EOF", error)) { return false }
                if (!atEnd) {
                    trap(ExecutionResult.IO_ERROR, "stdin read made no progress before EOF")
                    return false
                }
                return push(Value(Value.I32, -1, null, true))
            }

            if (service == CVM.Service.FILE_OPEN_READ ||
                service == CVM.Service.FILE_OPEN_WRITE || service == CVM.Service.FILE_OPEN) {
                bool integerHandle = service == CVM.Service.FILE_OPEN
                String mode = "rb"
                if (service == CVM.Service.FILE_OPEN_WRITE) { mode = "wb" }
                if (integerHandle) {
                    Value modeReference = popType(Value.ARRAY_REF)
                    if (modeReference == null || _failure != null ||
                        !validArrayReference(modeReference)) { return false }
                    mode = decodeFileMode(modeReference.array())
                    if (mode == null || _failure != null) { return false }
                }
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                String path = decodePath(reference.array())
                if (path == null || _failure != null) { return false }
                if (!serviceAvailable(_capabilities.filesEnabled(), serviceName)) { return false }
                if (!checkOpenResourceLimit()) { return false }
                if (!canPushServiceResult()) { return false }
                if (_nextFileHandle > 2147483647) {
                    trap(ExecutionResult.RESOURCE_LIMIT, "file handle identifier space exhausted")
                    return false
                }
                Sys.File file = null
                try {
                    file = Sys.File(path, mode)
                } except(Exception) as caught {
                    trap(ExecutionResult.IO_ERROR,
                        format("opening '{}': {}", path, caught.message))
                    return false
                }
                int64 handleId = _nextFileHandle
                _nextFileHandle = _nextFileHandle + 1
                _fileHandles.append(HostFile(handleId, file, integerHandle))
                int64 resultType = Value.FILE
                if (integerHandle) { resultType = Value.I32 }
                return push(Value(resultType, handleId, null, true))
            }

            if (service == CVM.Service.FILE_READ || service == CVM.Service.FILE_READ_HANDLE) {
                bool integerHandle = service == CVM.Service.FILE_READ_HANDLE
                Value capacityValue = popType(Value.I32)
                if (capacityValue == null || _failure != null) { return false }
                int64 offset = 0
                if (!integerHandle) {
                    Value offsetValue = popType(Value.I32)
                    if (offsetValue == null || _failure != null) { return false }
                    offset = offsetValue.number()
                }
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                int64 handleType = Value.FILE
                if (integerHandle) { handleType = Value.I32 }
                Value fileValue = popType(handleType)
                if (fileValue == null || _failure != null) { return false }
                int64 capacity = capacityValue.number()
                ArrayInstance instance = reference.array()
                if (!checkByteArrayRange(instance, offset, capacity, integerHandle, serviceName)) { return false }
                HostFile hostFile = findFileHandle(fileValue.number(), integerHandle)
                if (hostFile == null) {
                    trap(ExecutionResult.RUNTIME_TRAP,
                        format("invalid, stale, or foreign file handle {}", fileValue.number()))
                    return false
                }
                if (!canPushServiceResult()) { return false }
                if (capacity == 0) { return push(Value(Value.I32, 0, null, true)) }
                buffer bytes = buffer[]
                String error = ""
                try {
                    bytes = hostFile.file().readBytes(capacity)
                    error = Sys.System().lastError()
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("reading file", error)) { return false }
                if (bytes == null || bytes.length > capacity) {
                    trap(ExecutionResult.IO_ERROR, "file read returned invalid byte count")
                    return false
                }
                if (integerHandle && bytes.length == 0) {
                    bool atEnd = false
                    try {
                        atEnd = hostFile.file().eof()
                        error = Sys.System().lastError()
                    } except(Exception) as caught {
                        error = caught.message
                    }
                    if (!checkIOError("checking file EOF", error)) { return false }
                    if (!atEnd) {
                        trap(ExecutionResult.IO_ERROR, "file read made no progress before EOF")
                        return false
                    }
                }
                int64 index = 0
                while (index < bytes.length) {
                    instance.bytes()[offset + index] = bytes[index]
                    index = index + 1
                }
                return push(Value(Value.I32, bytes.length, null, true))
            }

            if (service == CVM.Service.FILE_WRITE || service == CVM.Service.FILE_WRITE_HANDLE) {
                bool integerHandle = service == CVM.Service.FILE_WRITE_HANDLE
                Value countValue = popType(Value.I32)
                if (countValue == null || _failure != null) { return false }
                int64 offset = 0
                if (!integerHandle) {
                    Value offsetValue = popType(Value.I32)
                    if (offsetValue == null || _failure != null) { return false }
                    offset = offsetValue.number()
                }
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                int64 handleType = Value.FILE
                if (integerHandle) { handleType = Value.I32 }
                Value fileValue = popType(handleType)
                if (fileValue == null || _failure != null) { return false }
                int64 count = countValue.number()
                ArrayInstance instance = reference.array()
                if (!checkByteArrayRange(instance, offset, count, true, serviceName)) { return false }
                HostFile hostFile = findFileHandle(fileValue.number(), integerHandle)
                if (hostFile == null) {
                    trap(ExecutionResult.RUNTIME_TRAP,
                        format("invalid, stale, or foreign file handle {}", fileValue.number()))
                    return false
                }
                if (!canPushServiceResult()) { return false }
                if (count == 0) { return push(Value(Value.I32, 0, null, true)) }
                buffer chunk = instance.bytes()[offset:offset + count]
                int64 written = -1
                String error = ""
                try {
                    written = hostFile.file().writeBytes(chunk)
                    error = Sys.System().lastError()
                } except(Exception) as caught {
                    error = caught.message
                }
                if (!checkIOError("writing file", error)) { return false }
                if (written <= 0 || written > count) {
                    trap(ExecutionResult.IO_ERROR, "file write made invalid progress")
                    return false
                }
                return push(Value(Value.I32, written, null, true))
            }

            if (service == CVM.Service.FILE_CLOSE || service == CVM.Service.FILE_CLOSE_HANDLE) {
                bool integerHandle = service == CVM.Service.FILE_CLOSE_HANDLE
                int64 handleType = Value.FILE
                if (integerHandle) { handleType = Value.I32 }
                Value fileValue = popType(handleType)
                if (fileValue == null || _failure != null) { return false }
                HostFile hostFile = findFileHandle(fileValue.number(), integerHandle)
                if (hostFile == null) {
                    trap(ExecutionResult.RUNTIME_TRAP,
                        format("invalid, stale, or foreign file handle {}", fileValue.number()))
                    return false
                }
                return closeFileHandle(hostFile, true)
            }

            trap(ExecutionResult.RUNTIME_TRAP,
                format("invalid host service {}", service))
            return false
        }

        void freeFrame(Frame frame) {
            list arrays = frame.localArrays()
            int64 index = 0
            while (index < arrays.length) {
                ArrayInstance instance = arrays[index] as ArrayInstance
                if (instance != null && instance.alive()) {
                    instance.kill()
                    _heapBytes = _heapBytes - instance.heapBytes()
                }
                index = index + 1
            }
            _activeSlots = _activeSlots - frame.locals().length
            frame.kill()
        }

        bool doReturn(int64 returnType) {
            Frame frame = currentFrame()
            FunctionInfo function = currentFunction()
            if (function.returnType() != returnType) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("return type mismatch: function declares {}, instruction returns {}",
                        typeName(function.returnType()), typeName(returnType)))
                return false
            }
            int64 expectedValues = 0
            if (returnType != 0) { expectedValues = 1 }
            if (_stack.length != frame.stackBase() + expectedValues) {
                trap(ExecutionResult.RUNTIME_TRAP, "return has extra or missing operand stack values")
                return false
            }
            Value returned = null
            if (expectedValues == 1) {
                returned = popType(returnType)
                if (returned == null || _failure != null) { return false }
            }
            int64 functionIndex = frame.functionIndex()
            int64 callerOffset = frame.callOffset()
            freeFrame(frame)
            _frames.resize(_frames.length - 1)
            if (_frames.length == 0) {
                if (functionIndex != _entry || returnType != Value.I32 || returned == null) {
                    failAt(ExecutionResult.RUNTIME_TRAP, "invalid entry return", functionIndex, _activeOffset)
                    return false
                }
                _guestResult = returned.number()
                _completed = true
                return true
            }
            if (returned != null) {
                _activeOffset = callerOffset
                if (!push(returned)) { return false }
            }
            return true
        }

        bool compareValues(int64 opcode) {
            Value right = popType(Value.I32)
            if (right == null || _failure != null) { return false }
            Value left = popType(Value.I32)
            if (left == null || _failure != null) { return false }
            bool result = false
            if (opcode == CVM.Opcode.EQ_I32) { result = left.number() == right.number() }
            if (opcode == CVM.Opcode.NE_I32) { result = left.number() != right.number() }
            if (opcode == CVM.Opcode.LT_I32) { result = left.number() < right.number() }
            if (opcode == CVM.Opcode.LE_I32) { result = left.number() <= right.number() }
            if (opcode == CVM.Opcode.GT_I32) { result = left.number() > right.number() }
            if (opcode == CVM.Opcode.GE_I32) { result = left.number() >= right.number() }
            int64 number = 0
            if (result) { number = 1 }
            return push(Value(Value.I32, number, null, true))
        }

        bool binaryI32(int64 opcode) {
            Value right = popType(Value.I32)
            if (right == null || _failure != null) { return false }
            Value left = popType(Value.I32)
            if (left == null || _failure != null) { return false }
            int64 a = left.number()
            int64 b = right.number()
            int64 result = 0
            if (opcode == CVM.Opcode.ADD_I32) { result = a + b }
            if (opcode == CVM.Opcode.SUB_I32) { result = a - b }
            if (opcode == CVM.Opcode.MUL_I32) { result = a * b }
            if (opcode == CVM.Opcode.DIV_I32 || opcode == CVM.Opcode.REM_I32) {
                if (b == 0) {
                    trap(ExecutionResult.RUNTIME_TRAP, "integer division by zero")
                    return false
                }
                if (a == -2147483648 && b == -1) {
                    trap(ExecutionResult.RUNTIME_TRAP, "i32 division or remainder overflow")
                    return false
                }
                if (opcode == CVM.Opcode.DIV_I32) { result = a / b }
                else { result = a % b }
            }
            if (result < -2147483648 || result > 2147483647) {
                trap(ExecutionResult.RUNTIME_TRAP, "i32 arithmetic overflow")
                return false
            }
            return push(Value(Value.I32, result, null, true))
        }

        bool executeOne() {
            Frame frame = currentFrame()
            if (frame == null) {
                trap(ExecutionResult.RUNTIME_TRAP, "missing execution frame")
                return false
            }
            FunctionInfo function = currentFunction()
            if (frame.pc() < 0 || frame.pc() >= function.codeLength()) {
                trap(ExecutionResult.RUNTIME_TRAP, "reachable function fallthrough")
                return false
            }
            _activeOffset = frame.pc()
            if (_steps >= _limits.instructions()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "instruction limit exceeded")
                return false
            }
            _steps = _steps + 1
            int64 opcode = readCodeByte(frame, function, frame.pc())
            if (_failure != null) { return false }
            frame.setPc(frame.pc() + 1)

            if (opcode == CVM.Opcode.NOP) { return true }
            if (opcode == CVM.Opcode.CONST_I32) {
                int64 value = readOperand(frame, function, 4)
                if (_failure != null) { return false }
                if (value >= 2147483648) { value = value - 4294967296 }
                return push(Value(Value.I32, value, null, true))
            }
            if (opcode == CVM.Opcode.CONST_U8) {
                int64 value = readOperand(frame, function, 1)
                if (_failure != null) { return false }
                return push(Value(Value.U8, value, null, true))
            }
            if (opcode == CVM.Opcode.LDLOC || opcode == CVM.Opcode.STLOC) {
                int64 index = readOperand(frame, function, 2)
                if (_failure != null) { return false }
                list locals = frame.locals()
                if (index < 0 || index >= locals.length) {
                    trap(ExecutionResult.RUNTIME_TRAP, "local index is invalid")
                    return false
                }
                if (opcode == CVM.Opcode.LDLOC) {
                    Value value = locals[index] as Value
                    if (value == null || !value.initialized()) {
                        trap(ExecutionResult.RUNTIME_TRAP, format("local {} is uninitialized", index))
                        return false
                    }
                    return push(value)
                }
                Value stored = popAny()
                if (stored == null || _failure != null) { return false }
                if (stored.valueType() != localType(function, index)) {
                    trap(ExecutionResult.RUNTIME_TRAP, format("local {} store type mismatch", index))
                    return false
                }
                locals[index] = stored
                return push(stored)
            }
            if (opcode == CVM.Opcode.LDGLOBAL || opcode == CVM.Opcode.STGLOBAL) {
                int64 index = readOperand(frame, function, 2)
                if (_failure != null) { return false }
                if (index < 0 || index >= _globals.length) {
                    trap(ExecutionResult.RUNTIME_TRAP, "global index is invalid")
                    return false
                }
                if (opcode == CVM.Opcode.LDGLOBAL) {
                    return push(_globals[index] as Value)
                }
                Value stored = popAny()
                if (stored == null || _failure != null) { return false }
                Value existing = _globals[index] as Value
                if (stored.valueType() != existing.valueType()) {
                    trap(ExecutionResult.RUNTIME_TRAP, format("global {} store type mismatch", index))
                    return false
                }
                _globals[index] = stored
                return push(stored)
            }
            if (opcode == CVM.Opcode.ARRAY) {
                int64 index = readOperand(frame, function, 2)
                if (_failure != null) { return false }
                ArrayInstance instance = arrayFor(frame, index)
                if (instance == null || _failure != null) { return false }
                return push(Value(Value.ARRAY_REF, 0, instance, true))
            }
            if (opcode == CVM.Opcode.ALEN) {
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                return push(Value(Value.I32, reference.array().length(), null, true))
            }
            if (opcode == CVM.Opcode.AGET || opcode == CVM.Opcode.ASET) {
                Value stored = null
                if (opcode == CVM.Opcode.ASET) {
                    stored = popAny()
                    if (stored == null || _failure != null) { return false }
                }
                Value indexValue = popType(Value.I32)
                if (indexValue == null || _failure != null) { return false }
                Value reference = popType(Value.ARRAY_REF)
                if (reference == null || _failure != null || !validArrayReference(reference)) { return false }
                ArrayInstance instance = reference.array()
                int64 index = indexValue.number()
                if (index < 0 || index >= instance.length()) {
                    trap(ExecutionResult.RUNTIME_TRAP, "array index is out of bounds")
                    return false
                }
                if (opcode == CVM.Opcode.AGET) {
                    int64 value = 0
                    if (instance.elementType() == Value.U8) {
                        value = int64(instance.bytes()[index])
                    } else {
                        int64 at = index * 4
                        value = int64(instance.bytes()[at]) + int64(instance.bytes()[at + 1]) * 256 + int64(instance.bytes()[at + 2]) * 65536 + int64(instance.bytes()[at + 3]) * 16777216
                        if (value >= 2147483648) { value = value - 4294967296 }
                    }
                    return push(Value(instance.elementType(), value, null, true))
                }
                if (stored.valueType() != instance.elementType()) {
                    trap(ExecutionResult.RUNTIME_TRAP, "array store type mismatch")
                    return false
                }
                if (instance.elementType() == Value.U8) {
                    instance.bytes()[index] = uint8(stored.number())
                } else {
                    int64 value = stored.number()
                    if (value < 0) { value = value + 4294967296 }
                    int64 at = index * 4
                    instance.bytes()[at] = uint8(value % 256)
                    instance.bytes()[at + 1] = uint8((value / 256) % 256)
                    instance.bytes()[at + 2] = uint8((value / 65536) % 256)
                    instance.bytes()[at + 3] = uint8((value / 16777216) % 256)
                }
                return push(stored)
            }
            if (opcode == CVM.Opcode.ADD_I32 || opcode == CVM.Opcode.SUB_I32 || opcode == CVM.Opcode.MUL_I32 || opcode == CVM.Opcode.DIV_I32 || opcode == CVM.Opcode.REM_I32) { return binaryI32(opcode) }
            if (opcode == CVM.Opcode.NEG_I32) {
                Value operand = popType(Value.I32)
                if (operand == null || _failure != null) { return false }
                if (operand.number() == -2147483648) {
                    trap(ExecutionResult.RUNTIME_TRAP, "i32 negation overflow")
                    return false
                }
                return push(Value(Value.I32, -operand.number(), null, true))
            }
            if (opcode == CVM.Opcode.EQ_I32 || opcode == CVM.Opcode.NE_I32 || opcode == CVM.Opcode.LT_I32 || opcode == CVM.Opcode.LE_I32 || opcode == CVM.Opcode.GT_I32 || opcode == CVM.Opcode.GE_I32) {
                return compareValues(opcode)
            }
            if (opcode == CVM.Opcode.TO_U8) {
                Value operand = popType(Value.I32)
                if (operand == null || _failure != null) { return false }
                if (operand.number() < 0 || operand.number() > 255) {
                    trap(ExecutionResult.RUNTIME_TRAP, "to.u8 value is outside 0..255")
                    return false
                }
                return push(Value(Value.U8, operand.number(), null, true))
            }
            if (opcode == CVM.Opcode.TO_I32) {
                Value operand = popType(Value.U8)
                if (operand == null || _failure != null) { return false }
                return push(Value(Value.I32, operand.number(), null, true))
            }
            if (opcode == CVM.Opcode.DUP) {
                Value value = popAny()
                if (value == null || _failure != null) { return false }
                if (value.valueType() == Value.ARRAY_REF) {
                    trap(ExecutionResult.RUNTIME_TRAP, "dup does not accept ArrayRef")
                    return false
                }
                if (!push(value)) { return false }
                return push(value)
            }
            if (opcode == CVM.Opcode.POP) {
                Value value = popAny()
                if (value == null || _failure != null) { return false }
                if (value.valueType() == Value.ARRAY_REF) {
                    trap(ExecutionResult.RUNTIME_TRAP, "pop does not accept ArrayRef")
                    return false
                }
                return true
            }
            if (opcode == CVM.Opcode.JMP || opcode == CVM.Opcode.JZ) {
                int64 target = readOperand(frame, function, 4)
                if (_failure != null) { return false }
                bool take = true
                if (opcode == CVM.Opcode.JZ) {
                    Value condition = popType(Value.I32)
                    if (condition == null || _failure != null) { return false }
                    take = condition.number() == 0
                }
                if (take) {
                    if (target < 0 || target >= function.codeLength()) {
                        trap(ExecutionResult.RUNTIME_TRAP, "branch target is outside function code")
                        return false
                    }
                    frame.setPc(target)
                }
                return true
            }
            if (opcode == CVM.Opcode.CALL) {
                int64 target = readOperand(frame, function, 2)
                if (_failure != null) { return false }
                return pushFrame(target, _activeOffset)
            }
            if (opcode == CVM.Opcode.RET) { return doReturn(0) }
            if (opcode == CVM.Opcode.RET_I32) { return doReturn(Value.I32) }
            if (opcode == CVM.Opcode.RET_U8) { return doReturn(Value.U8) }
            if (opcode == CVM.Opcode.RET_FILE) { return doReturn(Value.FILE) }
            if (opcode == CVM.Opcode.SYS) {
                int64 service = readOperand(frame, function, 1)
                if (_failure != null) { return false }
                return executeService(service)
            }
            trap(ExecutionResult.RUNTIME_TRAP, format("unknown opcode {}", opcode))
            return false
        }

        public:
        ExecutionResult run(buffer program) {
            return run(program, Limits())
        }

        ExecutionResult run(buffer program, Limits limits) {
            return run(program, limits, Capabilities())
        }

        ExecutionResult run(buffer program, Capabilities capabilities) {
            return run(program, Limits(), capabilities)
        }

        ExecutionResult run(buffer program, Limits limits, Capabilities capabilities) {
            reset(limits)
            if (limits == null || !limits.valid()) {
                _failure = ExecutionResult(ExecutionResult.CONFIGURATION_ERROR, 0,
                    "invalid VM limits", 0, -1, -1, "", -1, _steps)
                return _failure
            }
            if (capabilities == null || !capabilities.valid()) {
                _failure = ExecutionResult(ExecutionResult.CONFIGURATION_ERROR, 0,
                    "invalid host capabilities", 0, -1, -1, "", -1, _steps)
                return _failure
            }
            _capabilities = capabilities
            if (program == null) {
                loadFailure(0, 0, "program buffer is null")
                return _failure
            }
            if (program.length > limits.programBytes()) {
                failAt(ExecutionResult.RESOURCE_LIMIT, "program exceeds configured byte limit", -1, -1)
                return _failure
            }
            CVM.ContainerDecodeResult decoded = CVM.ContainerDecoder().decode(program)
            if (!decoded.valid()) {
                validationFailure(decoded.validation())
                return _failure
            }
            if (!load(decoded)) { return _failure }
            if (!pushFrame(_entry, -1)) { return _failure }
            while (!_completed && _failure == null) {
                if (!executeOne() && _failure == null) {
                    trap(ExecutionResult.RUNTIME_TRAP, "instruction did not complete")
                }
            }
            closeOwnedResources()
            if (_failure != null) { return _failure }
            return ExecutionResult(ExecutionResult.SUCCESS, _guestResult, "",
                0, -1, -1, "", -1, _steps)
        }
    }
}
