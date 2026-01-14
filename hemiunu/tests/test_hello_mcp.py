import unittest
import sys
import os

# Lägg till src-mappen i Python-sökvägen
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from hello_mcp import hello

class TestHelloMCP(unittest.TestCase):
    
    def test_hello_returns_correct_string(self):
        """Test att hello() returnerar exakt strängen 'Hello MCP'"""
        result = hello()
        self.assertEqual(result, "Hello MCP")
    
    def test_hello_returns_string_type(self):
        """Test att hello() returnerar en sträng"""
        result = hello()
        self.assertIsInstance(result, str)
    
    def test_hello_no_parameters(self):
        """Test att hello() kan anropas utan parametrar"""
        try:
            result = hello()
            self.assertIsNotNone(result)
        except TypeError:
            self.fail("hello() ska kunna anropas utan parametrar")
    
    def test_hello_consistent_output(self):
        """Test att hello() ger samma resultat vid flera anrop"""
        result1 = hello()
        result2 = hello()
        self.assertEqual(result1, result2)

if __name__ == '__main__':
    unittest.main()