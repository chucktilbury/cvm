include "parser.cw"
include "model.cw"
include "literals.cw"
include "source.cw"
include "stack.cw"
import cvmfile as IO

class Assembler {
    list functions
    list globals
    list arrays
    list functionNames
    list globalNames
    list arrayNames
    Function current
    String entry
    int entryLine
    bool version
    Literals literals
    CVM.Opcode schema

    Assembler() {
        functions = []
        globals = []
        arrays = []
        functionNames = []
        globalNames = []
        arrayNames = []
        current = null
        entry = ""
        entryLine = 1
        version = false
        literals = Literals()
        schema = CVM.Opcode()
    }

    void fail(String message, int row, int col) { raise(AssemblyError(message, row, col)) }

    int find(list symbols, String name) {
        int index = 0
        while (index < symbols.length) {
            Symbol symbol = symbols[index] as Symbol
            if (symbol.name.equals(name)) { return symbol.value }
            index = index + 1
        }
        return -1
    }

    void declare(list symbols, String name, int value, int row, int col) {
        if (!literals.identifier(name)) { fail("invalid identifier", row, col) }
        if (find(symbols, name) >= 0) { fail(format("duplicate symbol '{}'", name), row, col) }
        symbols.append(Symbol(name, value))
    }

    void local(String name, int valueType, int row, int col) {
        if (current.started) { fail("local declarations must precede statements", row, col) }
        if (current.types.length >= 65536) { fail("too many parameters and locals", row, col) }
        declare(current.locals, name, current.types.length, row, col)
        current.types.append(valueType)
    }

    void arrayDeclaration(AstNode node, SourceLine source) {
        int row = source.row
        int col = source.column(node)
        String name = node.childAt(1).lexeme()
        int element = literals.valueType(node.childAt(3).lexeme(), false, row, source.column(node.childAt(3)))
        if (element == 3) { fail("arrays require i32 or u8 elements", row, col) }
        int count = literals.number(node.childAt(5).lexeme(), row, source.column(node.childAt(5)))
        if (count <= 0 || count > 4294967295) { fail("array capacity out of range", row, col) }
        if (arrays.length >= 65536) { fail("too many arrays", row, col) }
        int owner = 65535
        if (current != null) {
            if (current.started) { fail("local declarations must precede statements", row, col) }
            owner = functions.length - 1
        }
        declare(arrayNames, name, arrays.length, row, source.column(node.childAt(1)))
        buffer data = buffer[]
        if (node.childCount() > 7) {
            int elementWidth = 1
            if (element == 1) { elementWidth = 4 }
            if (count > 4294967295 / elementWidth) { fail("array initializer byte length exceeds v1 range", row, col) }
            AstNode initializer = node.childAt(8)
            CVM.ByteWriter writer = CVM.ByteWriter()
            if (initializer.childAt(0).kind().equals("STRING")) {
                if (element != 2) { fail("string initializer requires u8 array", row, col) }
                data = source.quoted(initializer.childAt(0), literals)
                data.append(0)
                if (data.length > count) { fail("string initializer exceeds capacity including NUL", row, col) }
            } else {
                int index = 1
                int used = 0
                while (index < initializer.childCount() - 1) {
                    if (used >= count) { fail("array initializer exceeds capacity", row, source.column(initializer.childAt(index))) }
                    int value = source.scalar(initializer.childAt(index), element, literals)
                    if (element == 1) { writer.writeI32(value) }
                    else { writer.writeU8(value) }
                    used = used + 1
                    index = index + 2
                }
                data = writer.bytes()
            }
            int width = 1
            if (element == 1) { width = 4 }
            while (data.length < count * width) { data.append(0) }
        }
        arrays.append(ArrayDeclaration(name, owner, element, count, data))
    }

    void consume(AstNode node, SourceLine source) {
        String kind = node.kind()
        int row = source.row
        int col = source.column(node)
        if (!version) {
            if (!kind.equals("version")) { fail("file must start with .version 1.0", row, col) }
            version = true
            return
        }
        if (kind.equals("version")) { fail("duplicate .version", row, col) }
        if (entry.equals("")) {
            if (!kind.equals("entry")) { fail("expected .entry main before declarations", row, col) }
            entry = node.childAt(1).lexeme()
            entryLine = row
            if (!entry.equals("main")) { fail("v1 entry must be main() -> i32", row, source.column(node.childAt(1))) }
            return
        }
        if (kind.equals("entry")) { fail("duplicate .entry", row, col) }
        if (kind.equals("array_decl")) { arrayDeclaration(node, source)
            return }
        if (kind.equals("global_decl")) {
            if (current != null) { fail("global declaration inside function", row, col) }
            if (globals.length >= 65536) { fail("too many globals", row, col) }
            String name = node.childAt(1).lexeme()
            int valueType = literals.valueType(node.childAt(3).lexeme(), false, row, source.column(node.childAt(3)))
            if (valueType == 3) { fail("global type must be i32 or u8", row, col) }
            int value = source.scalar(node.childAt(5), valueType, literals)
            declare(globalNames, name, globals.length, row, source.column(node.childAt(1)))
            globals.append(GlobalDeclaration(name, valueType, value))
            return
        }
        if (kind.equals("function_decl")) {
            if (current != null) { fail("nested function", row, col) }
            if (functions.length >= 65535) { fail("too many functions", row, col) }
            String name = node.childAt(1).lexeme()
            declare(functionNames, name, functions.length, row, source.column(node.childAt(1)))
            int valueType = literals.valueType(node.childAt(node.childCount() - 1).lexeme(), true, row, col)
            current = Function(name, valueType, row)
            functions.append(current)
            int index = 3
            while (index < node.childCount() - 3) {
                AstNode parameter = node.childAt(index)
                int parameterType = literals.valueType(parameter.childAt(2).lexeme(), false, row, source.column(parameter.childAt(2)))
                local(parameter.childAt(0).lexeme(), parameterType, row, source.column(parameter))
                current.parameters = current.parameters + 1
                if (current.parameters > 65535) { fail("too many parameters", row, col) }
                index = index + 2
            }
            return
        }
        if (current == null) { fail("expected declaration outside function", row, col) }
        if (kind.equals("end_decl")) {
            if (current.length == 0) { fail("function must contain instructions", row, col) }
            current = null
            return
        }
        if (kind.equals("local_decl")) {
            int valueType = literals.valueType(node.childAt(3).lexeme(), false, row, source.column(node.childAt(3)))
            if (current.types.length - current.parameters >= 65535) { fail("too many locals", row, col) }
            local(node.childAt(1).lexeme(), valueType, row, source.column(node.childAt(1)))
            return
        }
        current.started = true
        if (kind.equals("label")) {
            declare(current.labels, node.childAt(0).lexeme(), current.length, row, col)
            return
        }
        if (!kind.equals("instruction")) { fail("unexpected directive", row, col) }
        String mnemonic = node.childAt(0).lexeme()
        int opcode = CVM.Opcode.NOP
        while (opcode <= CVM.Opcode.RET_FILE && !schema.mnemonic(opcode).equals(mnemonic)) { opcode = opcode + 1 }
        if (!schema.isValid(opcode)) { fail(format("unknown instruction '{}'", mnemonic), row, col) }
        bool hasOperand = schema.operandWidth(opcode) != 0
        if ((!hasOperand && node.childCount() != 1) || (hasOperand && node.childCount() != 2)) { fail("wrong operand count", row, col) }
        String operand = ""
        String operandKind = ""
        int literalValue = 0
        if (hasOperand) {
            AstNode value = node.childAt(1)
            AstNode token = value.childAt(0)
            operand = token.lexeme()
            operandKind = token.kind()
            int expected = schema.operandKind(opcode)
            if (expected == 1 || (expected == 2 && opcode != CVM.Opcode.SYS)) {
                literalValue = source.scalar(value, expected, literals)
            } else {
                if (!operandKind.equals("IDENT") || !literals.identifier(operand)) { fail("expected named operand", row, source.column(value)) }
            }
            col = source.column(value)
        }
        Instruction instruction = Instruction(opcode, operand, row, col, current.length)
        instruction.value = literalValue
        current.instructions.append(instruction)
        current.length = current.length + 1 + schema.operandWidth(opcode)
        if (current.length > 4294967295) { fail("function code too large", row, col) }
    }

    int resolve(list names, String name, Instruction instruction) {
        int index = find(names, name)
        if (index < 0) { fail(format("unresolved symbol '{}'", name), instruction.line, instruction.column) }
        return index
    }

    buffer encode(buffer text) {
        SourceText().validate(text)
        int index = 0
        int lineStart = 0
        int row = 1
        while (index <= text.length) {
            if (index == text.length || int(text[index]) == 10) {
                SourceLine line = SourceLine(text[lineStart:index], row)
                AstNode node = line.parse()
                if (node != null) { consume(node, line) }
                row = row + 1
                lineStart = index + 1
            }
            index = index + 1
        }
        if (!version || entry.equals("")) { fail("missing .version or .entry", 1, 1) }
        if (current != null) { fail("missing .end", current.line, 1) }
        int entryIndex = find(functionNames, entry)
        if (entryIndex < 0) { fail("unresolved entry function", entryLine, 1) }
        Function main = functions[entryIndex] as Function
        if (main.parameters != 0 || main.result != 1) { fail("entry must be main() -> i32", main.line, 1) }
        CVM.ContainerBuilder builder = CVM.ContainerBuilder()
        builder.setEntry(entryIndex)
        index = 0
        while (index < functions.length) {
            Function function = functions[index] as Function
            CVM.InstructionBuilder code = CVM.InstructionBuilder()
            int at = 0
            while (at < function.instructions.length) {
                Instruction instruction = function.instructions[at] as Instruction
                int kind = schema.operandKind(instruction.opcode)
                int value = instruction.value
                if (instruction.opcode == CVM.Opcode.SYS) {
                    CVM.Service services = CVM.Service()
                    while (value <= CVM.Service.FILE_CLOSE && !services.name(value).equals(instruction.operand)) { value = value + 1 }
                    if (value > CVM.Service.FILE_CLOSE) { fail("unknown service", instruction.line, instruction.column) }
                }
                if (kind == 3) { value = resolve(function.locals, instruction.operand, instruction) }
                if (kind == 4) { value = resolve(globalNames, instruction.operand, instruction) }
                if (kind == 5) {
                    value = resolve(arrayNames, instruction.operand, instruction)
                    ArrayDeclaration array = arrays[value] as ArrayDeclaration
                    if (array.owner != 65535 && array.owner != index) { fail("array belongs to another function", instruction.line, instruction.column) }
                }
                if (kind == 6) {
                    value = resolve(function.labels, instruction.operand, instruction)
                    if (value >= function.length) { fail("label target is past function end", instruction.line, instruction.column) }
                }
                if (kind == 7) { value = resolve(functionNames, instruction.operand, instruction) }
                instruction.value = value
                bool ok = true
                if (kind == 0) { ok = code.emitNoOperand(instruction.opcode) }
                else { ok = code.emit(instruction.opcode, value) }
                if (!ok) { fail(code.errorMessage(), instruction.line, instruction.column) }
                at = at + 1
            }
            int maximum = StackDepth().maximum(function, functions)
            if (!builder.addFunction(function.name, code.bytes(), function.types, function.parameters, function.types.length - function.parameters, maximum, function.result)) { fail(builder.errorMessage(), function.line, 1) }
            index = index + 1
        }
        index = 0
        while (index < globals.length) {
            GlobalDeclaration global = globals[index] as GlobalDeclaration
            if (!builder.addGlobal(global.name, global.valueType, global.value)) { fail(builder.errorMessage(), 1, 1) }
            index = index + 1
        }
        index = 0
        while (index < arrays.length) {
            ArrayDeclaration array = arrays[index] as ArrayDeclaration
            if (!builder.addArray(array.name, array.owner, array.element, array.count, array.data)) { fail(builder.errorMessage(), 1, 1) }
            index = index + 1
        }
        CVM.BuildResult result = builder.encode()
        if (!result.ok()) { fail(result.message(), 1, 1) }
        CVM.ValidationResult validation = CVM.ContainerValidator().validate(result.bytes())
        if (!validation.valid()) { fail(format("structural validation: {}", validation.message()), 1, 1) }
        return result.bytes()
    }
}

class AssemblerCLI {
    int run() {
        Sys.Process process = Sys.Process()
        if (process.argc() == 2 && process.arg(1).equals("--help")) {
            Sys.StandardIO().writeLine("usage: cvm-as INPUT.asm -o OUTPUT.cvm")
            return 0
        }
        if (process.argc() != 4 || !process.arg(2).equals("-o")) {
            Sys.StandardIO().writeErrorLine("usage: cvm-as INPUT.asm -o OUTPUT.cvm")
            return 2
        }
        String input = process.arg(1)
        try {
            IO.Result source = IO.Files().read(input)
            if (!source.ok()) { raise(Exception(source.error())) }
            buffer bytes = Assembler().encode(source.bytes())
            IO.Result saved = IO.Files().write(process.arg(3), bytes)
            if (!saved.ok()) { raise(Exception(saved.error())) }
        } except(AssemblyError) as diagnostic {
            AssemblyError located = diagnostic as AssemblyError
            Sys.StandardIO().writeErrorLine(format("{}:{}:{}: {}", input, located.line, located.column, located.message))
            return 1
        } except(Exception) as error {
            Sys.StandardIO().writeErrorLine(format("{}: I/O: {}", input, error.message))
            return 1
        }
        return 0
    }
}

start { Sys.Process().exit(AssemblerCLI().run()) }
