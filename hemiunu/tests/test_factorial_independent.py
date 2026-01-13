"""
Oberoende tester för factorial funktionen
Dessa tester skrivs baserat på kontraktet, inte implementationen
"""

import pytest
import sys
import os

# Lägg till src-mappen i path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from math_funcs import factorial


class TestFactorial:
    
    def test_factorial_zero(self):
        """Test att 0! = 1 enligt definition"""
        assert factorial(0) == 1
    
    def test_factorial_one(self):
        """Test att 1! = 1"""
        assert factorial(1) == 1
    
    def test_factorial_small_numbers(self):
        """Test faktorial för små positiva heltal"""
        assert factorial(2) == 2
        assert factorial(3) == 6
        assert factorial(4) == 24
        assert factorial(5) == 120
    
    def test_factorial_larger_numbers(self):
        """Test faktorial för något större tal"""
        assert factorial(6) == 720
        assert factorial(7) == 5040
        assert factorial(10) == 3628800
    
    def test_factorial_return_type(self):
        """Test att funktionen returnerar rätt typ (integer)"""
        result = factorial(5)
        assert isinstance(result, int)
    
    def test_factorial_negative_input(self):
        """Test att negativa tal hanteras korrekt (bör ge ValueError)"""
        with pytest.raises(ValueError):
            factorial(-1)
        
        with pytest.raises(ValueError):
            factorial(-5)
    
    def test_factorial_non_integer_input(self):
        """Test att icke-heltal hanteras korrekt"""
        with pytest.raises((TypeError, ValueError)):
            factorial(3.5)
        
        with pytest.raises((TypeError, ValueError)):
            factorial("5")
    
    def test_factorial_mathematical_property(self):
        """Test matematisk egenskap: n! = n × (n-1)!"""
        for n in range(1, 8):
            assert factorial(n) == n * factorial(n-1)