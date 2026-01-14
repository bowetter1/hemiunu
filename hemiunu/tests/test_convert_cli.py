#!/usr/bin/env python3
"""
TESTER's oberoende tester för convert.py CLI
Baserat på kontrakt: CLI-verktyg för enhetskonvertering
"""

import subprocess
import sys
import os

def run_convert(args):
    """Kör convert.py med givna argument och returnera resultat"""
    try:
        result = subprocess.run([sys.executable, "../convert.py"] + args, 
                              capture_output=True, text=True)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return -1, "", str(e)

def test_basic_temperature_conversion():
    """Test 1: Grundläggande temperaturkonvertering C till F"""
    print("Test 1: Grundläggande C till F konvertering...")
    code, stdout, stderr = run_convert(["100", "C", "F"])
    
    if code != 0:
        print(f"FAIL: Fel exit code {code}. stderr: {stderr}")
        return False
    
    # 100°C = 212°F, men vi behöver hantera formatterad output
    if "212" in stdout and "F" in stdout:
        print("PASS: Korrekt konvertering 100°C = 212°F")
        return True
    else:
        print(f"FAIL: Oväntat output format: '{stdout}'")
        return False

def test_reverse_temperature_conversion():
    """Test 2: Omvänd temperaturkonvertering F till C"""
    print("Test 2: F till C konvertering...")
    code, stdout, stderr = run_convert(["212", "F", "C"])
    
    if code != 0:
        print(f"FAIL: Fel exit code {code}")
        return False
    
    # 212°F = 100°C
    if "100" in stdout and "C" in stdout:
        print("PASS: Korrekt konvertering 212°F = 100°C")
        return True
    else:
        print(f"FAIL: Oväntat output format: '{stdout}'")
        return False

def test_zero_celsius():
    """Test 3: Edge case - 0°C till F"""
    print("Test 3: Edge case 0°C...")
    code, stdout, stderr = run_convert(["0", "C", "F"])
    
    if code != 0:
        print(f"FAIL: Fel exit code {code}")
        return False
    
    # 0°C = 32°F
    if "32" in stdout and "F" in stdout:
        print("PASS: Korrekt konvertering 0°C = 32°F")
        return True
    else:
        print(f"FAIL: Oväntat output format: '{stdout}'")
        return False

def test_negative_temperature():
    """Test 4: Negativ temperatur"""
    print("Test 4: Negativ temperatur -40°C...")
    code, stdout, stderr = run_convert(["-40", "C", "F"])
    
    if code != 0:
        print(f"FAIL: Fel exit code {code}")
        return False
    
    # -40°C = -40°F (speciell punkt där C och F möts)
    if "-40" in stdout and "F" in stdout:
        print("PASS: Korrekt konvertering -40°C = -40°F")
        return True
    else:
        print(f"FAIL: Oväntat output format: '{stdout}'")
        return False

def test_invalid_arguments_count():
    """Test 5: Fel antal argument"""
    print("Test 5: Fel antal argument...")
    code, stdout, stderr = run_convert(["100", "C"])
    
    if code == 0:
        print("FAIL: Borde ha gett fel för för få argument")
        return False
    else:
        print("PASS: Korrekt fel för fel antal argument")
        return True

def test_invalid_number():
    """Test 6: Ogiltigt nummer"""
    print("Test 6: Ogiltigt nummer...")
    code, stdout, stderr = run_convert(["abc", "C", "F"])
    
    if code == 0:
        print("FAIL: Borde ha gett fel för ogiltigt nummer")
        return False
    else:
        print("PASS: Korrekt fel för ogiltigt nummer")
        return True

def test_same_units():
    """Test 7: Samma enheter (C till C)"""
    print("Test 7: Samma enheter C till C...")
    code, stdout, stderr = run_convert(["25", "C", "C"])
    
    if code != 0:
        print(f"FAIL: Fel exit code {code}")
        return False
    
    # 25°C = 25°C
    if "25" in stdout and "C" in stdout:
        print("PASS: Korrekt konvertering C till C")
        return True
    else:
        print(f"FAIL: Oväntat output format: '{stdout}'")
        return False

def main():
    """Kör alla tester"""
    print("=== TESTER's Oberoende CLI-tester för convert.py ===\n")
    
    tests = [
        test_basic_temperature_conversion,
        test_reverse_temperature_conversion, 
        test_zero_celsius,
        test_negative_temperature,
        test_invalid_arguments_count,
        test_invalid_number,
        test_same_units
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"=== RESULTAT: {passed}/{total} tester passerade ===")
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)