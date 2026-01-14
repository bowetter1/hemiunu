"""
Temperature conversion module.

This module provides functions to convert temperatures between different scales:
- Celsius to Fahrenheit
- Celsius to Kelvin
- Fahrenheit to Celsius
- Fahrenheit to Kelvin

Formulas:
- Fahrenheit = (Celsius * 9/5) + 32
- Celsius = (Fahrenheit - 32) * 5/9
- Kelvin = Celsius + 273.15
"""


def celsius_to_fahrenheit(celsius):
    """
    Convert temperature from Celsius to Fahrenheit.
    
    Args:
        celsius (float): Temperature in Celsius
        
    Returns:
        float: Temperature in Fahrenheit
        
    Example:
        >>> celsius_to_fahrenheit(0)
        32.0
        >>> celsius_to_fahrenheit(100)
        212.0
    """
    return (celsius * 9/5) + 32


def celsius_to_kelvin(celsius):
    """
    Convert temperature from Celsius to Kelvin.
    
    Args:
        celsius (float): Temperature in Celsius
        
    Returns:
        float: Temperature in Kelvin
        
    Example:
        >>> celsius_to_kelvin(0)
        273.15
        >>> celsius_to_kelvin(100)
        373.15
    """
    return celsius + 273.15


def fahrenheit_to_celsius(fahrenheit):
    """
    Convert temperature from Fahrenheit to Celsius.
    
    Args:
        fahrenheit (float): Temperature in Fahrenheit
        
    Returns:
        float: Temperature in Celsius
        
    Example:
        >>> fahrenheit_to_celsius(32)
        0.0
        >>> fahrenheit_to_celsius(212)
        100.0
    """
    return (fahrenheit - 32) * 5/9


def fahrenheit_to_kelvin(fahrenheit):
    """
    Convert temperature from Fahrenheit to Kelvin.
    
    Args:
        fahrenheit (float): Temperature in Fahrenheit
        
    Returns:
        float: Temperature in Kelvin
        
    Example:
        >>> fahrenheit_to_kelvin(32)
        273.15
        >>> fahrenheit_to_kelvin(212)
        373.15
    """
    celsius = fahrenheit_to_celsius(fahrenheit)
    return celsius_to_kelvin(celsius)


if __name__ == "__main__":
    # Test the functions
    print("Temperature Conversion Tests:")
    print(f"0°C = {celsius_to_fahrenheit(0)}°F")
    print(f"100°C = {celsius_to_fahrenheit(100)}°F")
    print(f"0°C = {celsius_to_kelvin(0)}K")
    print(f"100°C = {celsius_to_kelvin(100)}K")
    print(f"32°F = {fahrenheit_to_celsius(32)}°C")
    print(f"212°F = {fahrenheit_to_celsius(212)}°C")
    print(f"32°F = {fahrenheit_to_kelvin(32)}K")
    print(f"212°F = {fahrenheit_to_kelvin(212)}K")