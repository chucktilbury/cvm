class Literals {
    void fail(String message, int row, int col) { raise(AssemblyError(message, row, col)) }

    int digit(int byte) {
        if (byte >= 48 && byte <= 57) { return byte - 48 }
        if (byte >= 65 && byte <= 70) { return byte - 55 }
        if (byte >= 97 && byte <= 102) { return byte - 87 }
        return -1
    }

    bool identifier(String name) {
        int index = 0
        while (index < name.length) {
            int byte = int(name.byteAt(index))
            if (!((byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 95 || (index > 0 && byte >= 48 && byte <= 57))) { return false }
            index = index + 1
        }
        return name.length > 0
    }

    int number(String text, int row, int col) {
        int sign = 1
        int index = 0
        if (text.startsWith("-")) { sign = -1
            index = 1 }
        else { if (text.startsWith("+")) { index = 1 } }
        int radix = 10
        if (text.slice(index, text.length).startsWith("0x")) {
            radix = 16
            index = index + 2
        }
        int result = 0
        if (index == text.length) { fail("expected integer", row, col) }
        while (index < text.length) {
            int value = digit(int(text.byteAt(index)))
            if (value < 0 || value >= radix || result > (4294967295 - value) / radix) { fail("integer out of range", row, col) }
            result = result * radix + value
            index = index + 1
        }
        return sign * result
    }

    buffer quoted(String text, int row, int col) {
        buffer result = buffer[]
        int index = 1
        while (index < text.length - 1) {
            int byte = int(text.byteAt(index))
            if (byte == 92) {
                index = index + 1
                int escape = int(text.byteAt(index))
                if (escape == 110) { byte = 10 }
                else { if (escape == 114) { byte = 13 }
                else { if (escape == 116) { byte = 9 }
                else { if (escape == 48) { byte = 0 }
                else { if (escape == 92 || escape == 34 || escape == 39) { byte = escape }
                else { if (escape == 120) {
                    if (index + 2 >= text.length - 1) { fail("expected exactly two hexadecimal escape digits", row, col + index) }
                    int first = digit(int(text.byteAt(index + 1)))
                    int second = digit(int(text.byteAt(index + 2)))
                    if (first < 0 || second < 0) { fail("invalid hexadecimal escape", row, col + index) }
                    byte = first * 16 + second
                    index = index + 2
                } else { fail("unknown escape", row, col + index) } } } } } }
            }
            result.append(byte)
            index = index + 1
        }
        if (text.startsWith("'") && result.length != 1) { fail("character literal must decode to one byte", row, col) }
        return result
    }

    int scalar(AstNode node, int element, int row, int col) {
        AstNode token = node.childAt(0)
        if (!token.kind().equals("INTEGER")) { fail("expected literal operand", row, col) }
        int value = number(token.lexeme(), row, col)
        if ((element == 1 && (value < -2147483648 || value > 2147483647)) || (element == 2 && (value < 0 || value > 255))) { fail("literal out of range for type", row, col) }
        return value
    }

    int valueType(String name, bool allowVoid, int row, int col) {
        if (name.equals("i32")) { return 1 }
        if (name.equals("u8")) { return 2 }
        if (name.equals("file")) { return 3 }
        if (allowVoid && name.equals("void")) { return 0 }
        fail("invalid type", row, col)
        return -1
    }
}
