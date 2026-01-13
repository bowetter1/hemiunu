"""
Oberoende tester för factorial funktionen (utan pytest)
Dessa tester skrivs baserat på kontraktet, inte implementationen
"""

import sys
import os

# Lägg till src-mappen i path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from math_funcs import factorial


def test_factorial_zero():
    """Test att 0! = 1 enligt definition"""
    result = factorial(0)
    assert result == 1, f"Expected 1, got {result}"
    print("✓ test_factorial_zero passed")


def test_factorial_one():
    """Test att 1! = 1"""
    result = factorial(1)
    assert result == 1, f"Expected 1, got {result}"
    print("✓ test_factorial_one passed")


def test_factorial_small_numbers():
    """Test faktorial för små positiva heltal"""
    test_cases = [
        (2, 2),
        (3, 6),
        (4, 24),
        (5, 120)
    ]
    
    for n, expected in test_cases:
        result = factorial(n)
        assert result == expected, f"factorial({n}): expected {expected}, got {result}"
    print("✓ test_factorial_small_numbers passed")


def test_factorial_larger_numbers():
    """Test faktorial för något större tal"""
    test_cases = [
        (6, 720),
        (7, 5040),
        (10, 3628800)
    ]
    
    for n, expected in test_cases:
        result = factorial(n)
        assert result == expected, f"factorial({n}): expected {expected}, got {result}"
    print("✓ test_factorial_larger_numbers passed")


def test_factorial_return_type():
    """Test att funktionen returnerar rätt typ (integer)"""
    result = factorial(5)
    assert isinstance(result, int), f"Expected int, got {type(result)}"
    print("✓ test_factorial_return_type passed")


def test_factorial_negative_input():
    """Test att negativa tal hanteras korrekt (bör ge ValueError)"""
    test_cases = [-1, -5]
    
    for n in test_cases:
        try:
            result = factorial(n)
            assert False, f"factorial({n}) should raise ValueError, but returned {result}"
        except ValueError:
            pass  # Expected
        except Exception as e:
            assert False, f"factorial({n}) should raise ValueError, but raised {type(e).__name__}: {e}"
    
    print("✓ test_factorial_negative_input passed")


def test_factorial_non_integer_input():
    """Test att icke-heltal hanteras korrekt"""
    test_cases = [3.5, "5"]
    
    for n in test_cases:
        try:
            result = factorial(n)
            assert False, f"factorial({n}) should raise TypeError or ValueError, but returned {result}"
        except (TypeError, ValueError):
            pass  # Expected
        except Exception as e:
            assert False, f"factorial({n}) should raise TypeError or ValueError, but raised {type(e).__name__}: {e}"
    
    print("✓ test_factorial_non_integer_input passed")


def test_factorial_mathematical_property():
    """Test matematisk egenskap: n! = n × (n-1)!"""
    for n in range(1, 8):
        result_n = factorial(n)
        result_n_minus_1 = factorial(n-1)
        expected = n * result_n_minus_1
        assert result_n == expected, f"factorial({n}) = {result_n}, but {n} × factorial({n-1}) = {expected}"
    
    print("✓ test_factorial_mathematical_property passed")


def run_all_tests():
    """Kör alla tester"""
    print("Running independent factorial tests...")
    print("=" * 50)
    
    tests = [
        test_factorial_zero,
        test_factorial_one,
        test_factorial_small_numbers,
        test_factorial_larger_numbers,
        test_factorial_return_type,
        test_factorial_negative_input,
        test_factorial_non_integer_input,
        test_factorial_mathematical_property
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed += 1
    
    print("=" * 50)
    print(f"Tests passed: {passed}")
    print(f"Tests failed: {failed}")
    print(f"Total tests: {passed + failed}")
    
    return passed, failed


if __name__ == "__main__":
    run_all_tests()