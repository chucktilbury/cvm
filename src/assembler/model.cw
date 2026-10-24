import cvm as CVM

class AssemblyError : public Exception {
    int64 column
    int64 line
    AssemblyError(String message, int64 row, int64 col) {
        super Exception(message)
        line = row
        column = col
    }
}

class Symbol {
    String name
    int64 value
    Symbol(String n, int64 v) {
        name = n
        value = v
    }
}

class Instruction {
    int64 opcode
    String operand
    int64 line
    int64 column
    int64 offset
    int64 value
    Instruction(int64 op, String arg, int64 row, int64 col, int64 at) {
        opcode = op
        operand = arg
        line = row
        column = col
        offset = at
        value = 0
    }
}

class Function {
    String name
    list locals
    buffer types
    list labels
    list instructions
    int64 parameters
    int64 result
    int64 length
    int64 line
    bool started
    Function(String n, int64 r, int64 row) {
        name = n
        result = r
        line = row
        locals = []
        types = buffer[]
        labels = []
        instructions = []
        parameters = 0
        length = 0
        started = false
    }
}

class ArrayDeclaration {
    String name
    int64 owner
    int64 element
    int64 count
    buffer data
    ArrayDeclaration(String n, int64 o, int64 e, int64 c, buffer d) {
        name = n
        owner = o
        element = e
        count = c
        data = d
    }
}

class GlobalDeclaration {
    String name
    int64 valueType
    int64 value
    GlobalDeclaration(String n, int64 t, int64 v) {
        name = n
        valueType = t
        value = v
    }
}
