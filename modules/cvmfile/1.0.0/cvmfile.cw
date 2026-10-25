import system as Sys

namespace CVMFile {
    class Result {
        private:
        buffer _bytes
        String _error
        int64 _category

        public:
        enum { OK = 0, IO_ERROR = 1, LIMIT_EXCEEDED = 2 }

        Result(buffer bytes, String error) {
            _bytes = bytes
            _error = error
            _category = IO_ERROR
            if (_error.equals("")) { _category = OK }
        }

        Result(buffer bytes, String error, int64 category) {
            _bytes = bytes
            _error = error
            _category = category
        }
        bool ok() { return(_error.equals("")) }
        buffer bytes() { return(_bytes) }
        String error() { return(_error) }
        int64 category() { return(_category) }
    }

    class Files {
        public:
        Result read(String path) {
            return(readLimited(path, 9223372036854775807))
        }

        Result readLimited(String path, int64 maximumBytes) {
            if (maximumBytes < 0) { return(Result(buffer[], "maximum read size cannot be negative")) }
            Sys.File file = null
            try {
                file = Sys.File(path, "rb")
            } except(Exception) as error {
                return(Result(buffer[], error.message))
            }
            buffer bytes = buffer[]
            String failure = ""
            bool limitExceeded = false
            try {
                bool finished = false
                while (!finished && failure.equals("")) {
                    int64 requestSize = 65536
                    int64 remaining = maximumBytes - bytes.length
                    if (remaining < requestSize) { requestSize = remaining + 1 }
                    buffer part = file.readBytes(requestSize)
                    failure = Sys.System().lastError()
                    if (failure.equals("")) {
                        if (part.length > remaining) {
                            failure = format("input exceeds configured byte limit ({})", maximumBytes)
                            limitExceeded = true
                        } else {
                            int64 index = 0
                            while (index < part.length) {
                                bytes.append(part[index])
                                index = index + 1
                            }
                            finished = file.eof()
                            if (!finished && part.length == 0) { failure = "read made no progress" }
                        }
                    }
                }
            } finally {
                file.close()
                String closeError = Sys.System().lastError()
                if (failure.equals("") && !closeError.equals("")) { failure = closeError }
            }
            if (!failure.equals("")) {
                int64 category = Result.IO_ERROR
                if (limitExceeded) { category = Result.LIMIT_EXCEEDED }
                return(Result(buffer[], format("read '{}': {}", path, failure), category))
            }
            return(Result(bytes, "", Result.OK))
        }

        Result write(String path, buffer bytes) {
            if (bytes == null) { return(Result(buffer[], "write requires a byte buffer")) }
            Sys.File file = null
            try {
                file = Sys.File(path, "wb")
            } except(Exception) as error {
                return(Result(buffer[], error.message))
            }
            String failure = ""
            try {
                int64 offset = 0
                while (offset < bytes.length && failure.equals("")) {
                    int64 end = offset + 65536
                    if (end > bytes.length) { end = bytes.length }
                    int64 count = file.writeBytes(bytes[offset:end])
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
            if (!failure.equals("")) { return(Result(buffer[], format("write '{}': {}", path, failure))) }
            return(Result(buffer[], ""))
        }
    }
}
