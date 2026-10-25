class Literals {
    void fail(String message, int64 row, int64 col) { raise(AssemblyError(message, row, col)) }

    int64 digit(int64 byte) {
        if (byte >= 48 && byte <= 57) { return(byte - 48) }
        if (byte >= 65 && byte <= 70) { return(byte - 55) }
        if (byte >= 97 && byte <= 102) { return(byte - 87) }
        return(-1)
    }

    bool identifier(String name) {
        int64 index = 0
        while (index < name.length) {
            int64 byte = int64(name.byteAt(index))
            if (!((byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 95 || (index > 0 && byte >= 48 && byte <= 57))) { return(false) }
            index = index + 1
        }
        return(name.length > 0)
    }

    int64 number(String text, int64 row, int64 col) {
        int64 sign = 1
        int64 index = 0
        if (text.startsWith("-")) { sign = -1
            index = 1 }
        else { if (text.startsWith("+")) { index = 1 } }
        int64 radix = 10
        if (text.slice(index, text.length).startsWith("0x")) {
            radix = 16
            index = index + 2
        }
        int64 result = 0
        if (index == text.length) { fail("expected integer", row, col) }
        while (index < text.length) {
            int64 value = digit(int64(text.byteAt(index)))
            if (value < 0 || value >= radix || result > (4294967295 - value) / radix) { fail("integer out of range", row, col) }
            result = result * radix + value
            index = index + 1
        }
        return(sign * result)
    }

    buffer quoted(String text, int64 row, int64 col) {
        buffer result = buffer[]
        int64 index = 1
        while (index < text.length - 1) {
            int64 byte = int64(text.byteAt(index))
            if (byte == 92) {
                index = index + 1
                int64 escape = int64(text.byteAt(index))
                if (escape == 110) { byte = 10 }
                else { if (escape == 114) { byte = 13 }
                else { if (escape == 116) { byte = 9 }
                else { if (escape == 48) { byte = 0 }
                else { if (escape == 92 || escape == 34 || escape == 39) { byte = escape }
                else { if (escape == 120) {
                    if (index + 2 >= text.length - 1) { fail("expected exactly two hexadecimal escape digits", row, col + index) }
                    int64 first = digit(int64(text.byteAt(index + 1)))
                    int64 second = digit(int64(text.byteAt(index + 2)))
                    if (first < 0 || second < 0) { fail("invalid hexadecimal escape", row, col + index) }
                    byte = first * 16 + second
                    index = index + 2
                } else { fail("unknown escape", row, col + index) } } } } } }
            }
            result.append(byte)
            index = index + 1
        }
        if (text.startsWith("'") && result.length != 1) { fail("character literal must decode to one byte", row, col) }
        return(result)
    }

    int64 scalar(AstNode node, int64 element, int64 row, int64 col) {
        AstNode token = node.childAt(0)
        if (!token.kind().equals("INTEGER")) { fail("expected literal operand", row, col) }
        int64 value = number(token.lexeme(), row, col)
        if ((element == 1 && (value < -2147483648 || value > 2147483647)) || (element == 2 && (value < 0 || value > 255))) { fail("literal out of range for type", row, col) }
        return(value)
    }

    int64 valueType(String name, bool allowVoid, int64 row, int64 col) {
        if (name.equals("i32")) { return(1) }
        if (name.equals("u8")) { return(2) }
        if (name.equals("file")) { return(3) }
        if (allowVoid && name.equals("void")) { return(0) }
        fail("invalid type", row, col)
        return(-1)
    }
}
