import cvm as CVM

class AssemblyError : public Exception {
    int column
    int line
    AssemblyError(String message, int row, int col) {
        super Exception(message)
        line = row
        column = col
    }
}

class Symbol {
    String name
    int value
    Symbol(String n, int v) {
        name = n
        value = v
    }
}

class Instruction {
    int opcode
    String operand
    int line
    int column
    int offset
    int value
    Instruction(int op, String arg, int row, int col, int at) {
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
    int parameters
    int result
    int length
    int line
    bool started
    Function(String n, int r, int row) {
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
    int owner
    int element
    int count
    buffer data
    ArrayDeclaration(String n, int o, int e, int c, buffer d) {
        name = n
        owner = o
        element = e
        count = c
        data = d
    }
}

class GlobalDeclaration {
    String name
    int valueType
    int value
    GlobalDeclaration(String n, int t, int v) {
        name = n
        valueType = t
        value = v
    }
}
