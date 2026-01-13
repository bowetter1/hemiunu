"""
Primtalsmodul för matematikbiblioteket.
Innehåller funktioner för att arbeta med primtal.
"""

import math


def is_prime(n):
    """
    Kontrollerar om ett tal är ett primtal.
    
    Args:
        n (int): Talet som ska kontrolleras
        
    Returns:
        bool: True om n är ett primtal, False annars
        
    Examples:
        >>> is_prime(2)
        True
        >>> is_prime(4)
        False
        >>> is_prime(17)
        True
    """
    # Hantera specialfall
    if not isinstance(n, int):
        return False
    
    if n < 2:
        return False
    
    if n == 2:
        return True
    
    if n % 2 == 0:
        return False
    
    # Kontrollera udda delare upp till sqrt(n)
    for i in range(3, int(math.sqrt(n)) + 1, 2):
        if n % i == 0:
            return False
    
    return True