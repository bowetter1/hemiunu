#!/usr/bin/env python3
"""
OBEROENDE TESTER för is_prime(n) funktionen
Skrivna av TESTER baserat på kontraktet, inte implementationen.

KONTRAKT: is_prime(n) returnerar True om n är ett primtal, annars False.

Ett primtal är ett naturligt tal större än 1 som endast är delbart av 1 och sig själv.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.prime import is_prime

def test_basic_primes():
    """Test grundläggande primtal"""
    # Små primtal
    assert is_prime(2) == True, "2 är det minsta primtalet"
    assert is_prime(3) == True, "3 är ett primtal"
    assert is_prime(5) == True, "5 är ett primtal"
    assert is_prime(7) == True, "7 är ett primtal"
    assert is_prime(11) == True, "11 är ett primtal"
    assert is_prime(13) == True, "13 är ett primtal"
    
    # Större primtal
    assert is_prime(17) == True, "17 är ett primtal"
    assert is_prime(19) == True, "19 är ett primtal"
    assert is_prime(23) == True, "23 är ett primtal"
    assert is_prime(29) == True, "29 är ett primtal"
    assert is_prime(97) == True, "97 är ett primtal"
    
    print("✓ Grundläggande primtal: PASS")

def test_non_primes():
    """Test tal som INTE är primtal"""
    # Sammansatta tal
    assert is_prime(4) == False, "4 = 2×2, inte primtal"
    assert is_prime(6) == False, "6 = 2×3, inte primtal"
    assert is_prime(8) == False, "8 = 2×4, inte primtal"
    assert is_prime(9) == False, "9 = 3×3, inte primtal"
    assert is_prime(10) == False, "10 = 2×5, inte primtal"
    assert is_prime(12) == False, "12 = 3×4, inte primtal"
    assert is_prime(15) == False, "15 = 3×5, inte primtal"
    assert is_prime(21) == False, "21 = 3×7, inte primtal"
    assert is_prime(25) == False, "25 = 5×5, inte primtal"
    assert is_prime(100) == False, "100 = 10×10, inte primtal"
    
    print("✓ Icke-primtal: PASS")

def test_edge_cases():
    """Test kantfall"""
    # 0 och 1 är per definition inte primtal
    assert is_prime(0) == False, "0 är inte primtal"
    assert is_prime(1) == False, "1 är inte primtal per definition"
    
    print("✓ Kantfall: PASS")

def test_negative_numbers():
    """Test negativa tal - dessa ska inte vara primtal"""
    assert is_prime(-1) == False, "Negativa tal är inte primtal"
    assert is_prime(-2) == False, "Negativa tal är inte primtal"
    assert is_prime(-7) == False, "Negativa tal är inte primtal"
    
    print("✓ Negativa tal: PASS")

def test_larger_primes():
    """Test några större primtal"""
    assert is_prime(101) == True, "101 är ett primtal"
    assert is_prime(103) == True, "103 är ett primtal"
    assert is_prime(107) == True, "107 är ett primtal"
    assert is_prime(109) == True, "109 är ett primtal"
    
    print("✓ Större primtal: PASS")

def test_larger_non_primes():
    """Test några större icke-primtal"""
    assert is_prime(102) == False, "102 = 2×51, inte primtal"
    assert is_prime(104) == False, "104 = 8×13, inte primtal"  
    assert is_prime(105) == False, "105 = 3×5×7, inte primtal"
    assert is_prime(121) == False, "121 = 11×11, inte primtal"
    
    print("✓ Större icke-primtal: PASS")

def run_all_tests():
    """Kör alla tester"""
    print("=== KÖR OBEROENDE TESTER FÖR is_prime(n) ===")
    
    try:
        test_basic_primes()
        test_non_primes()
        test_edge_cases()
        test_negative_numbers()
        test_larger_primes() 
        test_larger_non_primes()
        
        print("\n🎉 ALLA OBEROENDE TESTER PASSERADE!")
        return True
        
    except AssertionError as e:
        print(f"\n❌ TEST MISSLYCKADES: {e}")
        return False
    except Exception as e:
        print(f"\n💥 OVÄNTAT FEL: {e}")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)