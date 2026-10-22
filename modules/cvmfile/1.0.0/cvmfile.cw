import system as Sys

namespace CVMFile {
    class Result {
        private:
        buffer _bytes
        String _error

        public:
        Result(buffer bytes, String error) {
            _bytes = bytes
            _error = error
        }
        bool ok() { return _error.equals("") }
        buffer bytes() { return _bytes }
        String error() { return _error }
    }

    class Files {
        public:
        Result read(String path) {
            Sys.File file = null
            try {
                file = Sys.File(path, "rb")
            } except(Exception) as error {
                return Result(buffer[], error.message)
            }
            buffer bytes = buffer[]
            String failure = ""
            try {
                bool finished = false
                while (!finished && failure.equals("")) {
                    buffer part = file.readBytes(65536)
                    failure = Sys.System().lastError()
                    if (failure.equals("")) {
                        int index = 0
                        while (index < part.length) {
                            bytes.append(part[index])
                            index = index + 1
                        }
                        finished = file.eof()
                        if (!finished && part.length == 0) { failure = "read made no progress" }
                    }
                }
            } finally {
                file.close()
                String closeError = Sys.System().lastError()
                if (failure.equals("") && !closeError.equals("")) { failure = closeError }
            }
            if (!failure.equals("")) { return Result(buffer[], format("read '{}': {}", path, failure)) }
            return Result(bytes, "")
        }

        Result write(String path, buffer bytes) {
            if (bytes == null) { return Result(buffer[], "write requires a byte buffer") }
            Sys.File file = null
            try {
                file = Sys.File(path, "wb")
            } except(Exception) as error {
                return Result(buffer[], error.message)
            }
            String failure = ""
            try {
                int offset = 0
                while (offset < bytes.length && failure.equals("")) {
                    int end = offset + 65536
                    if (end > bytes.length) { end = bytes.length }
                    int count = file.writeBytes(bytes[offset:end])
                    failure = Sys.System().lastError()
                    if (failure.equals("")) {
                        if (count <= 0 || count > end - offset) { failure = "invalid write progress" }
                        else { offset = offset + count }
                    }
                }
            } finally {
                file.close()
                String closeError = Sys.System().lastError()
                if (failure.equals("") && !closeError.equals("")) { failure = closeError }
            }
            if (!failure.equals("")) { return Result(buffer[], format("write '{}': {}", path, failure)) }
            return Result(buffer[], "")
        }
    }
}
