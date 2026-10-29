class NodeLocation {
    AstNode node
    int64 column
    int64 offset
    NodeLocation(AstNode n, int64 col, int64 at) { node = n
        offset = at
        column = col }
}

class SourceLine {
    String text
    list columns
    list locations
    list tokens
    int64 cursor
    int64 row

    SourceLine(buffer input, int64 line) {
        row = line
        columns = []
        locations = []
        cursor = 0
        text = ""
        int64 quote = 0
        bool escaped = false
        bool comment = false
        String hex = "0123456789abcdef"
        int64 index = 0
        while (index < input.length) {
            int64 byte = int64(input[index])
            if (byte >= 128 && quote != 0 && !escaped && !comment) {
                text.append("\\x")
                text.append(byteSpan(hex, byte / 16, byte / 16 + 1))
                text.append(byteSpan(hex, byte % 16, byte % 16 + 1))
                int64 part = 0
                while (part < 4) { columns.append(index + 1)
                    part = part + 1 }
            } else {
                if (byte >= 128 && !comment) { raise(AssemblyError("non-ASCII byte outside a string or comment", row, index + 1)) }
                if (byte >= 128) { text.append(" ") }
                else { text.append(format("{:c}", byte)) }
                columns.append(index + 1)
            }
            if (!comment) {
                if (escaped) { escaped = false }
                else { if (byte == 92 && quote != 0) { escaped = true }
                else { if (quote == 0 && byte == 59) { comment = true }
                else { if (quote == 0 && (byte == 34 || byte == 39)) { quote = byte }
                else { if (byte == quote) { quote = 0 } } } } }
            }
            index = index + 1
        }
        columns.append(input.length + 1)
    }

    int64 columnAt(int64 offset) {
        if (offset < 0) { return(1) }
        if (offset >= columns.length) { return(columns[columns.length - 1] as int64) }
        return(columns[offset] as int64)
    }

    void locate(AstNode node) {
        int64 offset = text.length
        if (cursor < tokens.length) { offset = (tokens[cursor] as LexToken).offset }
        locations.append(NodeLocation(node, columnAt(offset), offset))
        if (node.childCount() == 0) { cursor = cursor + 1 }
        else {
            int64 index = 0
            while (index < node.childCount()) { locate(node.childAt(index))
                index = index + 1 }
        }
    }

    int64 column(AstNode node) {
        int64 index = 0
        while (index < locations.length) {
            NodeLocation location = locations[index] as NodeLocation
            if (location.node == node) { return(location.column) }
            index = index + 1
        }
        return(1)
    }

    buffer quoted(AstNode token, Literals literals) {
        int64 index = 0
        while (index < locations.length) {
            NodeLocation location = locations[index] as NodeLocation
            if (location.node == token) {
                try {
                    return(literals.quoted(token.lexeme(), row, location.offset + 1))
                } except(AssemblyError) as diagnostic {
                    AssemblyError located = diagnostic as AssemblyError
                    raise(AssemblyError(located.message, row, columnAt(located.column - 1)))
                }
            }
            index = index + 1
        }
        raise(AssemblyError("missing literal location", row, 1))
    }

    int64 scalar(AstNode node, int64 element, Literals literals) {
        AstNode token = node.childAt(0)
        if (!token.kind().equals("CHAR")) { return(literals.scalar(node, element, row, column(node))) }
        return(int64(quoted(token, literals)[0]))
    }

    AstNode parse() {
        InputScanner scanner = InputScanner(text)
        if (!scanner.scan()) { raise(AssemblyError(scanner.problem, row, columnAt(scanner.errorOffset))) }
        tokens = scanner.tokens
        if (tokens.length == 0) { return(null) }
        GeneratedParser parser = GeneratedParser(tokens)
        AstNode root = parser.parseAll()
        if (root == null) {
            int64 at = text.length
            if (parser.errorPosition >= 0 && parser.errorPosition < tokens.length) { at = (tokens[parser.errorPosition] as LexToken).offset }
            raise(AssemblyError(parser.problem, row, columnAt(at)))
        }
        locate(root)
        return(root.childAt(0))
    }

    int64 byteSpanBound(int64 value, int64 length) {
        int64 index = value
        if (index < 0) { index = index + length }
        if (index < 0) { return(0) }
        if (index > length) { return(length) }
        return(index)
    }
    String byteSpan(String text, int64 first, int64 last) {
        int64 lower = byteSpanBound(first, text.length)
        int64 end = byteSpanBound(last, text.length)
        if (end <= lower) { return("") }
        return(text[lower..(end - 1)])
    }
}

class SourceText {
    void validate(buffer text) {
        int64 index = 0
        int64 row = 1
        int64 col = 1
        while (index < text.length) {
            int64 byte = int64(text[index])
            int64 width = 1
            if (byte >= 194 && byte <= 223) { width = 2 }
            else { if (byte >= 224 && byte <= 239) { width = 3 }
            else { if (byte >= 240 && byte <= 244) { width = 4 }
            else { if (byte >= 128 || byte == 0) { raise(AssemblyError("invalid UTF-8 source byte", row, col)) } } } }
            if (index + width > text.length) { raise(AssemblyError("truncated UTF-8 source", row, col)) }
            int64 next = 1
            while (next < width) {
                int64 continuation = int64(text[index + next])
                if (continuation < 128 || continuation > 191 || (next == 1 && ((byte == 224 && continuation < 160) || (byte == 237 && continuation > 159) || (byte == 240 && continuation < 144) || (byte == 244 && continuation > 143)))) { raise(AssemblyError("invalid UTF-8 source", row, col)) }
                next = next + 1
            }
            if (byte == 10) { row = row + 1
                col = 1 }
            else { col = col + width }
            index = index + width
        }
    }
}
