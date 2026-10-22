class NodeLocation {
    AstNode node
    int column
    int offset
    NodeLocation(AstNode n, int col, int at) { node = n
        offset = at
        column = col }
}

class SourceLine {
    String text
    list columns
    list locations
    list tokens
    int cursor
    int row

    SourceLine(buffer input, int line) {
        row = line
        columns = []
        locations = []
        cursor = 0
        text = ""
        int quote = 0
        bool escaped = false
        bool comment = false
        String hex = "0123456789abcdef"
        int index = 0
        while (index < input.length) {
            int byte = int(input[index])
            if (byte >= 128 && quote != 0 && !escaped && !comment) {
                text.append("\\x")
                text.append(hex.slice(byte / 16, byte / 16 + 1))
                text.append(hex.slice(byte % 16, byte % 16 + 1))
                int part = 0
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

    int columnAt(int offset) {
        if (offset < 0) { return 1 }
        if (offset >= columns.length) { return columns[columns.length - 1] as int }
        return columns[offset] as int
    }

    void locate(AstNode node) {
        int offset = text.length
        if (cursor < tokens.length) { offset = (tokens[cursor] as LexToken).offset }
        locations.append(NodeLocation(node, columnAt(offset), offset))
        if (node.childCount() == 0) { cursor = cursor + 1 }
        else {
            int index = 0
            while (index < node.childCount()) { locate(node.childAt(index))
                index = index + 1 }
        }
    }

    int column(AstNode node) {
        int index = 0
        while (index < locations.length) {
            NodeLocation location = locations[index] as NodeLocation
            if (location.node == node) { return location.column }
            index = index + 1
        }
        return 1
    }

    buffer quoted(AstNode token, Literals literals) {
        int index = 0
        while (index < locations.length) {
            NodeLocation location = locations[index] as NodeLocation
            if (location.node == token) {
                try {
                    return literals.quoted(token.lexeme(), row, location.offset + 1)
                } except(AssemblyError) as diagnostic {
                    AssemblyError located = diagnostic as AssemblyError
                    raise(AssemblyError(located.message, row, columnAt(located.column - 1)))
                }
            }
            index = index + 1
        }
        raise(AssemblyError("missing literal location", row, 1))
    }

    int scalar(AstNode node, int element, Literals literals) {
        AstNode token = node.childAt(0)
        if (!token.kind().equals("CHAR")) { return literals.scalar(node, element, row, column(node)) }
        return int(quoted(token, literals)[0])
    }

    AstNode parse() {
        InputScanner scanner = InputScanner(text)
        if (!scanner.scan()) { raise(AssemblyError(scanner.problem, row, columnAt(scanner.errorOffset))) }
        tokens = scanner.tokens
        if (tokens.length == 0) { return null }
        GeneratedParser parser = GeneratedParser(tokens)
        AstNode root = parser.parseAll()
        if (root == null) {
            int at = text.length
            if (parser.errorPosition >= 0 && parser.errorPosition < tokens.length) { at = (tokens[parser.errorPosition] as LexToken).offset }
            raise(AssemblyError(parser.problem, row, columnAt(at)))
        }
        locate(root)
        return root.childAt(0)
    }
}

class SourceText {
    void validate(buffer text) {
        int index = 0
        int row = 1
        int col = 1
        while (index < text.length) {
            int byte = int(text[index])
            int width = 1
            if (byte >= 194 && byte <= 223) { width = 2 }
            else { if (byte >= 224 && byte <= 239) { width = 3 }
            else { if (byte >= 240 && byte <= 244) { width = 4 }
            else { if (byte >= 128 || byte == 0) { raise(AssemblyError("invalid UTF-8 source byte", row, col)) } } } }
            if (index + width > text.length) { raise(AssemblyError("truncated UTF-8 source", row, col)) }
            int next = 1
            while (next < width) {
                int continuation = int(text[index + next])
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
