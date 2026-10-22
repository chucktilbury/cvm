import cvm as CVM

namespace CVMRun {
    class Limits {
        private:
        int _programBytes
        int _instructions
        int _stackValues
        int _callDepth
        int _heapBytes

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

        Limits(int programBytes, int instructions, int stackValues, int callDepth, int heapBytes) {
            _programBytes = programBytes
            _instructions = instructions
            _stackValues = stackValues
            _callDepth = callDepth
            _heapBytes = heapBytes
        }

        bool valid() {
            return _programBytes > 0 && _programBytes <= MAX_PROGRAM_BYTES && _instructions > 0 && _instructions <= MAX_INSTRUCTIONS && _stackValues > 0 && _stackValues <= MAX_STACK_VALUES && _callDepth > 0 && _callDepth <= MAX_CALL_DEPTH && _heapBytes >= 0 && _heapBytes <= MAX_HEAP_BYTES
        }

        int programBytes() { return _programBytes }
        int instructions() { return _instructions }
        int stackValues() { return _stackValues }
        int callDepth() { return _callDepth }
        int heapBytes() { return _heapBytes }
    }

    class ExecutionResult {
        private:
        int _category
        int _guestResult
        String _message
        int _section
        int _byteOffset
        int _functionIndex
        String _functionName
        int _instructionOffset
        int _instructionsExecuted

        public:
        enum {
            SUCCESS = 0,
            LOAD_ERROR = 1,
            VALIDATION_ERROR = 2,
            RUNTIME_TRAP = 3,
            UNSUPPORTED_SERVICE = 4,
            RESOURCE_LIMIT = 5
        }

        ExecutionResult(int category, int guestResult, String message,
                        int section, int byteOffset, int functionIndex,
                        String functionName, int instructionOffset, int steps) {
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
        int category() { return _category }
        int guestResult() { return _guestResult }
        String message() { return _message }
        int section() { return _section }
        int byteOffset() { return _byteOffset }
        int functionIndex() { return _functionIndex }
        String functionName() { return _functionName }
        int instructionOffset() { return _instructionOffset }
        int instructionsExecuted() { return _instructionsExecuted }
    }

    class Value {
        private:
        int _type
        int _number
        ArrayInstance _array
        bool _initialized

        public:
        enum { I32 = 1, U8 = 2, FILE = 3, ARRAY_REF = 4 }

        Value(int valueType, int number, ArrayInstance array, bool initialized) {
            _type = valueType
            _number = number
            _array = array
            _initialized = initialized
        }

        int valueType() { return _type }
        int number() { return _number }
        ArrayInstance array() { return _array }
        bool initialized() { return _initialized }
    }

    class FunctionInfo {
        private:
        String _name
        int _codeOffset
        int _codeLength
        int _typeOffset
        int _parameters
        int _locals
        int _maximumStack
        int _returnType
        list _localArrayIndexes

        public:
        FunctionInfo(String name, int codeOffset, int codeLength, int typeOffset,
                     int parameters, int locals, int maximumStack, int returnType) {
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
        int codeOffset() { return _codeOffset }
        int codeLength() { return _codeLength }
        int typeOffset() { return _typeOffset }
        int parameters() { return _parameters }
        int locals() { return _locals }
        int maximumStack() { return _maximumStack }
        int returnType() { return _returnType }
        list localArrayIndexes() { return _localArrayIndexes }
        void addLocalArray(int index) { _localArrayIndexes.append(index) }
    }

    class ArrayInfo {
        private:
        int _owner
        int _elementType
        int _length
        bool _initialized
        int _dataOffset

        public:
        ArrayInfo(int owner, int elementType, int length, bool initialized, int dataOffset) {
            _owner = owner
            _elementType = elementType
            _length = length
            _initialized = initialized
            _dataOffset = dataOffset
        }

        int owner() { return _owner }
        int elementType() { return _elementType }
        int length() { return _length }
        bool initialized() { return _initialized }
        int dataOffset() { return _dataOffset }
    }

    class ArrayInstance {
        private:
        int _index
        int _elementType
        int _length
        buffer _bytes
        bool _alive
        int _heapBytes

        public:
        ArrayInstance(int index, int elementType, int length, buffer bytes, int heapBytes) {
            _index = index
            _elementType = elementType
            _length = length
            _bytes = bytes
            _alive = true
            _heapBytes = heapBytes
        }

        int index() { return _index }
        int elementType() { return _elementType }
        int length() { return _length }
        buffer bytes() { return _bytes }
        bool alive() { return _alive }
        int heapBytes() { return _heapBytes }
        void kill() { _alive = false }
    }

    class Frame {
        private:
        int _functionIndex
        int _pc
        int _stackBase
        int _callOffset
        list _locals
        list _localArrays
        bool _active

        public:
        Frame(int functionIndex, int pc, int stackBase, int callOffset, list locals) {
            _functionIndex = functionIndex
            _pc = pc
            _stackBase = stackBase
            _callOffset = callOffset
            _locals = locals
            _localArrays = []
            _active = true
        }

        int functionIndex() { return _functionIndex }
        int pc() { return _pc }
        void setPc(int pc) { _pc = pc }
        int stackBase() { return _stackBase }
        int callOffset() { return _callOffset }
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
        ExecutionResult _failure
        int _entry
        int _steps
        int _heapBytes
        int _activeSlots
        int _activeOffset
        int _guestResult
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
            _failure = null
            _entry = -1
            _steps = 0
            _heapBytes = 0
            _activeSlots = 0
            _activeOffset = 0
            _guestResult = 0
            _completed = false
        }

        int byteAt(buffer bytes, int offset, int section) {
            if (bytes == null || offset < 0 || offset >= bytes.length) {
                loadFailure(section, offset, "truncated section data")
                return 0
            }
            return int(bytes[offset])
        }

        int u16At(buffer bytes, int offset, int section) {
            if (bytes == null || offset < 0 || offset > bytes.length || bytes.length - offset < 2) {
                loadFailure(section, offset, "truncated 16-bit field")
                return 0
            }
            return int(bytes[offset]) + int(bytes[offset + 1]) * 256
        }

        int u32At(buffer bytes, int offset, int section) {
            if (bytes == null || offset < 0 || offset > bytes.length || bytes.length - offset < 4) {
                loadFailure(section, offset, "truncated 32-bit field")
                return 0
            }
            return int(bytes[offset]) + int(bytes[offset + 1]) * 256 + int(bytes[offset + 2]) * 65536 + int(bytes[offset + 3]) * 16777216
        }

        int i32At(buffer bytes, int offset, int section) {
            int value = u32At(bytes, offset, section)
            if (_failure != null) { return 0 }
            if (value >= 2147483648) { return value - 4294967296 }
            return value
        }

        void loadFailure(int section, int offset, String message) {
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

        void failAt(int category, String message, int functionIndex, int offset) {
            if (_failure != null) { return }
            String name = ""
            if (functionIndex >= 0 && functionIndex < _functions.length) {
                FunctionInfo function = _functions[functionIndex] as FunctionInfo
                name = function.name()
            }
            _failure = ExecutionResult(category, 0, message, 0, -1,
                functionIndex, name, offset, _steps)
        }

        void trap(int category, String message) {
            Frame frame = null
            int functionIndex = -1
            int offset = _activeOffset
            if (_frames.length > 0) {
                frame = _frames[_frames.length - 1] as Frame
                functionIndex = frame.functionIndex()
            }
            failAt(category, message, functionIndex, offset)
        }

        String nameAt(buffer strings, int offset) {
            if (offset < 0 || offset >= strings.length) {
                loadFailure(CVM.Format.STRINGS, offset, "function name offset is outside STRINGS")
                return ""
            }
            String name = ""
            int cursor = offset
            bool terminated = false
            while (cursor < strings.length && !terminated) {
                int byte = int(strings[cursor])
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

            int offset = 0
            while (offset < functions.length && _failure == null) {
                int nameOffset = u32At(functions, offset, CVM.Format.FUNCS)
                int codeOffset = u32At(functions, offset + 4, CVM.Format.FUNCS)
                int codeLength = u32At(functions, offset + 8, CVM.Format.FUNCS)
                int typeOffset = u32At(functions, offset + 12, CVM.Format.FUNCS)
                int parameters = u16At(functions, offset + 16, CVM.Format.FUNCS)
                int locals = u16At(functions, offset + 18, CVM.Format.FUNCS)
                int maximumStack = u16At(functions, offset + 20, CVM.Format.FUNCS)
                int returnType = byteAt(functions, offset + 24, CVM.Format.FUNCS)
                if (_failure != null) { return false }
                String name = nameAt(strings, nameOffset)
                if (_failure != null) { return false }
                if (parameters + locals > 65536 || codeLength <= 0 || codeOffset < 0 || codeOffset > _code.length || codeLength > _code.length - codeOffset || typeOffset < 0 || typeOffset > _types.length || parameters + locals > _types.length - typeOffset || returnType < 0 || returnType > 3) {
                    loadFailure(CVM.Format.FUNCS, offset, "function metadata is outside its validated section")
                    return false
                }
                int typeIndex = 0
                while (typeIndex < parameters + locals) {
                    int valueType = int(_types[typeOffset + typeIndex])
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
                int valueType = byteAt(globals, offset + 4, CVM.Format.GLOBALS)
                int initial = i32At(globals, offset + 8, CVM.Format.GLOBALS)
                if (_failure != null) { return false }
                if ((valueType != Value.I32 && valueType != Value.U8) || (valueType == Value.U8 && (initial < 0 || initial > 255))) {
                    loadFailure(CVM.Format.GLOBALS, offset + 4, "invalid global type or initial value")
                    return false
                }
                int reserved = byteAt(globals, offset + 5, CVM.Format.GLOBALS) + byteAt(globals, offset + 6, CVM.Format.GLOBALS) + byteAt(globals, offset + 7, CVM.Format.GLOBALS)
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
                int owner = u16At(arrays, offset + 4, CVM.Format.ARRAYS)
                int elementType = byteAt(arrays, offset + 6, CVM.Format.ARRAYS)
                int flags = byteAt(arrays, offset + 7, CVM.Format.ARRAYS)
                int length = u32At(arrays, offset + 8, CVM.Format.ARRAYS)
                int dataOffset = u32At(arrays, offset + 12, CVM.Format.ARRAYS)
                int reserved = u32At(arrays, offset + 16, CVM.Format.ARRAYS)
                if (_failure != null) { return false }
                if ((owner != 65535 && owner >= _functions.length) || (elementType != Value.I32 && elementType != Value.U8) || (flags != 0 && flags != 1) || length <= 0 || reserved != 0) {
                    loadFailure(CVM.Format.ARRAYS, offset + 4, "invalid array metadata")
                    return false
                }
                int width = 1
                if (elementType == Value.I32) { width = 4 }
                if (_limits.heapBytes() < Limits.ARRAY_INSTANCE_OVERHEAD || length > (_limits.heapBytes() - Limits.ARRAY_INSTANCE_OVERHEAD) / width) {
                    failAt(ExecutionResult.RESOURCE_LIMIT,
                        "array storage exceeds configured heap limit",
                        -1, -1)
                    return false
                }
                int storageBytes = length * width
                if (flags == 1) {
                    if (dataOffset < 0 || dataOffset > _data.length || storageBytes > _data.length - dataOffset) {
                        loadFailure(CVM.Format.ARRAYS, offset + 12, "array initializer is outside DATA")
                        return false
                    }
                    int priorIndex = 0
                    while (priorIndex < _arrayInfos.length) {
                        ArrayInfo prior = _arrayInfos[priorIndex] as ArrayInfo
                        if (prior.initialized()) {
                            int priorWidth = 1
                            if (prior.elementType() == Value.I32) { priorWidth = 4 }
                            int priorBytes = prior.length() * priorWidth
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

        ArrayInstance createArray(int index, ArrayInfo info) {
            int width = 1
            if (info.elementType() == Value.I32) { width = 4 }
            if (info.length() > _limits.heapBytes() / width) {
                trap(ExecutionResult.RESOURCE_LIMIT, "array storage exceeds configured heap limit")
                return null
            }
            int size = info.length() * width
            int chargedBytes = size + Limits.ARRAY_INSTANCE_OVERHEAD
            if (chargedBytes > _limits.heapBytes() - _heapBytes) {
                trap(ExecutionResult.RESOURCE_LIMIT, "array storage exceeds configured heap limit")
                return null
            }
            buffer bytes = buffer(size)
            if (info.initialized()) {
                int indexInArray = 0
                while (indexInArray < size) {
                    bytes[indexInArray] = _data[info.dataOffset() + indexInArray]
                    indexInArray = indexInArray + 1
                }
            }
            _heapBytes = _heapBytes + chargedBytes
            return ArrayInstance(index, info.elementType(), info.length(), bytes, chargedBytes)
        }

        int localType(FunctionInfo function, int index) {
            if (index < 0 || index >= function.parameters() + function.locals()) { return 0 }
            return int(_types[function.typeOffset() + index])
        }

        Value defaultLocal(int valueType) {
            return Value(valueType, 0, null, false)
        }

        void contextualizeFrameFailure(int functionIndex) {
            if (_failure == null || _frames.length != 0 || functionIndex < 0 || functionIndex >= _functions.length) { return }
            FunctionInfo function = _functions[functionIndex] as FunctionInfo
            _failure = ExecutionResult(_failure.category(), 0, _failure.message(),
                _failure.section(), _failure.byteOffset(), functionIndex,
                function.name(), 0, _steps)
        }

        bool pushFrame(int functionIndex, int callOffset) {
            if (functionIndex < 0 || functionIndex >= _functions.length) {
                trap(ExecutionResult.RUNTIME_TRAP, "call target function index is invalid")
                return false
            }
            if (_frames.length >= _limits.callDepth()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "call depth limit exceeded")
                return false
            }
            FunctionInfo function = _functions[functionIndex] as FunctionInfo
            int argumentCount = function.parameters()
            Frame caller = currentFrame()
            int available = _stack.length
            if (caller != null) { available = available - caller.stackBase() }
            if (available < argumentCount) {
                trap(ExecutionResult.RUNTIME_TRAP, "call argument stack underflow")
                return false
            }
            int argumentStart = _stack.length - argumentCount
            if (_activeSlots + _stack.length + function.locals() > _limits.stackValues()) {
                trap(ExecutionResult.RESOURCE_LIMIT, "active local and operand value limit exceeded")
                contextualizeFrameFailure(functionIndex)
                return false
            }
            int index = 0
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
                int slotType = localType(function, index)
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
                int arrayIndex = localIndexes[index] as int
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

        Value popType(int expectedType) {
            Value value = popAny()
            if (value == null || _failure != null) { return null }
            if (value.valueType() != expectedType) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("expected {}, found {}", typeName(expectedType), typeName(value.valueType())))
                return null
            }
            return value
        }

        String typeName(int valueType) {
            if (valueType == Value.I32) { return "i32" }
            if (valueType == Value.U8) { return "u8" }
            if (valueType == Value.FILE) { return "file" }
            if (valueType == Value.ARRAY_REF) { return "ArrayRef" }
            return "invalid value"
        }

        int readCodeByte(Frame frame, FunctionInfo function, int relativeOffset) {
            if (relativeOffset < 0 || relativeOffset >= function.codeLength()) {
                trap(ExecutionResult.RUNTIME_TRAP, "instruction operand extends past function")
                return 0
            }
            int absoluteOffset = function.codeOffset() + relativeOffset
            if (absoluteOffset < 0 || absoluteOffset >= _code.length) {
                trap(ExecutionResult.RUNTIME_TRAP, "instruction offset is outside CODE")
                return 0
            }
            return int(_code[absoluteOffset])
        }

        int readOperand(Frame frame, FunctionInfo function, int width) {
            int operandOffset = frame.pc()
            if (operandOffset < 0 || operandOffset > function.codeLength() || width > function.codeLength() - operandOffset) {
                trap(ExecutionResult.RUNTIME_TRAP, "truncated instruction operand")
                return 0
            }
            int value = 0
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

        ArrayInstance arrayFor(Frame frame, int index) {
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
            int localIndex = 0
            while (localIndex < localIndexes.length) {
                if ((localIndexes[localIndex] as int) == index) {
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

        void freeFrame(Frame frame) {
            list arrays = frame.localArrays()
            int index = 0
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

        bool doReturn(int returnType) {
            Frame frame = currentFrame()
            FunctionInfo function = currentFunction()
            if (function.returnType() != returnType) {
                trap(ExecutionResult.RUNTIME_TRAP,
                    format("return type mismatch: function declares {}, instruction returns {}",
                        typeName(function.returnType()), typeName(returnType)))
                return false
            }
            int expectedValues = 0
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
            int functionIndex = frame.functionIndex()
            int callerOffset = frame.callOffset()
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

        bool compareValues(int opcode) {
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
            int number = 0
            if (result) { number = 1 }
            return push(Value(Value.I32, number, null, true))
        }

        bool binaryI32(int opcode) {
            Value right = popType(Value.I32)
            if (right == null || _failure != null) { return false }
            Value left = popType(Value.I32)
            if (left == null || _failure != null) { return false }
            int a = left.number()
            int b = right.number()
            int result = 0
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
            int opcode = readCodeByte(frame, function, frame.pc())
            if (_failure != null) { return false }
            frame.setPc(frame.pc() + 1)

            if (opcode == CVM.Opcode.NOP) { return true }
            if (opcode == CVM.Opcode.CONST_I32) {
                int value = readOperand(frame, function, 4)
                if (_failure != null) { return false }
                if (value >= 2147483648) { value = value - 4294967296 }
                return push(Value(Value.I32, value, null, true))
            }
            if (opcode == CVM.Opcode.CONST_U8) {
                int value = readOperand(frame, function, 1)
                if (_failure != null) { return false }
                return push(Value(Value.U8, value, null, true))
            }
            if (opcode == CVM.Opcode.LDLOC || opcode == CVM.Opcode.STLOC) {
                int index = readOperand(frame, function, 2)
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
                int index = readOperand(frame, function, 2)
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
                int index = readOperand(frame, function, 2)
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
                int index = indexValue.number()
                if (index < 0 || index >= instance.length()) {
                    trap(ExecutionResult.RUNTIME_TRAP, "array index is out of bounds")
                    return false
                }
                if (opcode == CVM.Opcode.AGET) {
                    int value = 0
                    if (instance.elementType() == Value.U8) {
                        value = int(instance.bytes()[index])
                    } else {
                        int at = index * 4
                        value = int(instance.bytes()[at]) + int(instance.bytes()[at + 1]) * 256 + int(instance.bytes()[at + 2]) * 65536 + int(instance.bytes()[at + 3]) * 16777216
                        if (value >= 2147483648) { value = value - 4294967296 }
                    }
                    return push(Value(instance.elementType(), value, null, true))
                }
                if (stored.valueType() != instance.elementType()) {
                    trap(ExecutionResult.RUNTIME_TRAP, "array store type mismatch")
                    return false
                }
                if (instance.elementType() == Value.U8) {
                    instance.bytes()[index] = stored.number()
                } else {
                    int value = stored.number()
                    if (value < 0) { value = value + 4294967296 }
                    int at = index * 4
                    instance.bytes()[at] = value % 256
                    instance.bytes()[at + 1] = (value / 256) % 256
                    instance.bytes()[at + 2] = (value / 65536) % 256
                    instance.bytes()[at + 3] = (value / 16777216) % 256
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
                int target = readOperand(frame, function, 4)
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
                int target = readOperand(frame, function, 2)
                if (_failure != null) { return false }
                return pushFrame(target, _activeOffset)
            }
            if (opcode == CVM.Opcode.RET) { return doReturn(0) }
            if (opcode == CVM.Opcode.RET_I32) { return doReturn(Value.I32) }
            if (opcode == CVM.Opcode.RET_U8) { return doReturn(Value.U8) }
            if (opcode == CVM.Opcode.RET_FILE) { return doReturn(Value.FILE) }
            if (opcode == CVM.Opcode.SYS) {
                int service = readOperand(frame, function, 1)
                if (_failure != null) { return false }
                String name = CVM.Service().name(service)
                if (name.equals("")) { name = format("service {}", service) }
                trap(ExecutionResult.UNSUPPORTED_SERVICE,
                    format("host service '{}' is not implemented by this runner", name))
                return false
            }
            trap(ExecutionResult.RUNTIME_TRAP, format("unknown opcode {}", opcode))
            return false
        }

        public:
        ExecutionResult run(buffer program) {
            return run(program, Limits())
        }

        ExecutionResult run(buffer program, Limits limits) {
            reset(limits)
            if (limits == null || !limits.valid()) {
                loadFailure(0, 0, "invalid VM limits")
                return _failure
            }
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
            if (_failure != null) { return _failure }
            return ExecutionResult(ExecutionResult.SUCCESS, _guestResult, "",
                0, -1, -1, "", -1, _steps)
        }
    }
}
