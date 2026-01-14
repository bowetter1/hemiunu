#!/usr/bin/env python3
"""
Enhetskonverterare - CLI-verktyg för konvertering mellan enheter
"""

import sys
import argparse


def celsius_to_fahrenheit(celsius):
    """Konvertera Celsius till Fahrenheit"""
    return (celsius * 9/5) + 32


def fahrenheit_to_celsius(fahrenheit):
    """Konvertera Fahrenheit till Celsius"""
    return (fahrenheit - 32) * 5/9


def celsius_to_kelvin(celsius):
    """Konvertera Celsius till Kelvin"""
    return celsius + 273.15


def kelvin_to_celsius(kelvin):
    """Konvertera Kelvin till Celsius"""
    return kelvin - 273.15


def fahrenheit_to_kelvin(fahrenheit):
    """Konvertera Fahrenheit till Kelvin"""
    return celsius_to_kelvin(fahrenheit_to_celsius(fahrenheit))


def kelvin_to_fahrenheit(kelvin):
    """Konvertera Kelvin till Fahrenheit"""
    return celsius_to_fahrenheit(kelvin_to_celsius(kelvin))


def convert_temperature(value, from_unit, to_unit):
    """Konvertera temperatur mellan olika enheter"""
    from_unit = from_unit.upper()
    to_unit = to_unit.upper()
    
    # Konverteringstabellen
    conversions = {
        ('C', 'F'): celsius_to_fahrenheit,
        ('F', 'C'): fahrenheit_to_celsius,
        ('C', 'K'): celsius_to_kelvin,
        ('K', 'C'): kelvin_to_celsius,
        ('F', 'K'): fahrenheit_to_kelvin,
        ('K', 'F'): kelvin_to_fahrenheit,
    }
    
    # Om samma enhet, returnera samma värde
    if from_unit == to_unit:
        return value
    
    # Hitta konverteringsfunktionen
    conversion_key = (from_unit, to_unit)
    if conversion_key in conversions:
        return conversions[conversion_key](value)
    else:
        raise ValueError(f"Konvertering från {from_unit} till {to_unit} stöds inte")


def main():
    """Huvudfunktion för CLI"""
    if len(sys.argv) != 4:
        print("Användning: python convert.py <värde> <från-enhet> <till-enhet>")
        print("Exempel: python convert.py 100 C F")
        print("Stödda temperaturenheter: C (Celsius), F (Fahrenheit), K (Kelvin)")
        sys.exit(1)
    
    try:
        # Läs argumenten
        value_str = sys.argv[1]
        from_unit = sys.argv[2]
        to_unit = sys.argv[3]
        
        # Konvertera värdet till float
        value = float(value_str)
        
        # Utför konverteringen
        result = convert_temperature(value, from_unit, to_unit)
        
        # Visa resultatet
        print(f"{value}°{from_unit.upper()} = {result:.2f}°{to_unit.upper()}")
        
    except ValueError as e:
        print(f"Fel: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Oväntat fel: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()