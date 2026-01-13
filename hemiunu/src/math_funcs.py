"""
Matematiska funktioner för grundläggande beräkningar.
"""

def factorial(n):
    """
    Beräknar faktorial av n (n!)
    
    Args:
        n (int): Ett icke-negativt heltal
        
    Returns:
        int: Faktorialen av n
        
    Raises:
        ValueError: Om n är negativt
        TypeError: Om n inte är ett heltal
    
    Examples:
        >>> factorial(0)
        1
        >>> factorial(1)
        1
        >>> factorial(5)
        120
    """
    if not isinstance(n, int):
        raise TypeError("n måste vara ett heltal")
    
    if n < 0:
        raise ValueError("n måste vara icke-negativt")
    
    if n == 0 or n == 1:
        return 1
    
    result = 1
    for i in range(2, n + 1):
        result *= i
    
    return result