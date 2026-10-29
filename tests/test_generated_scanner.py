import pathlib
import unittest

import importlib.util

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "rewrite_generated_scanner.py"
spec = importlib.util.spec_from_file_location("rewrite_generated_scanner", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


OLD = """class InputScanner {
    String input
    bool startsAt(int64 at, String marker) {
        return(input.length - at >= marker.length && input.slice(at, at + marker.length).equals(marker))
    }
    int64 matchQuote(int64 at, int64 quote) {
        if (int64(input.byteAt(at)) != quote) { return(-1) }
        return(0)
    }
    bool scan() {
        if (input.length - i >= 1 && input.slice(i, i + 1).equals(":")) { return(true) }
        if (!skip) { tokens.append(LexToken(bestKind, input.slice(i, bestEnd), i)) }
        return(true)
    }
}
"""

CURRENT = """class InputScanner {
    String byteSpan(String text, int64 first, int64 last) { return(text) }
    bool startsAt(int64 at, String marker) {
        return(byteSpan(input, at, at + marker.length).equals(marker))
    }
    int64 matchQuote(int64 at, int64 quote) {
        if (int64(input[at]) != quote) { return(-1) }
        return(0)
    }
}
"""


class RewriteGeneratedScannerTest(unittest.TestCase):
    def test_old_generator_uses_indexing_and_keeps_empty_spans(self):
        updated = module.rewrite(OLD)
        self.assertNotIn(".slice(", updated)
        self.assertNotIn(".byteAt(", updated)
        self.assertIn("int64(input[at])", updated)
        self.assertIn("byteSpan(input, i, bestEnd)", updated)
        self.assertIn("String byteSpan(String text, int64 first, int64 last)", updated)
        self.assertIn("text[lower..(end - 1)]", updated)
        self.assertEqual(module.rewrite(updated), updated)

    def test_current_generator_is_unchanged(self):
        self.assertEqual(module.rewrite(CURRENT), CURRENT)


if __name__ == "__main__":
    unittest.main()
