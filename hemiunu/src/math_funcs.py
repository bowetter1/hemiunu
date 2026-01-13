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


def fibonacci(n):
    """
    Returnerar det n:te Fibonacci-talet.
    
    Fibonacci-sekvensen: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
    där F(0) = 0, F(1) = 1, och F(n) = F(n-1) + F(n-2) för n > 1.
    
    Args:
        n (int): Index i Fibonacci-sekvensen (icke-negativt heltal)
        
    Returns:
        int: Det n:te Fibonacci-talet
        
    Raises:
        ValueError: Om n är negativt
        TypeError: Om n inte är ett heltal
    
    Examples:
        >>> fibonacci(0)
        0
        >>> fibonacci(1)
        1
        >>> fibonacci(10)
        55
        >>> fibonacci(20)
        6765
    """
    if not isinstance(n, int):
        raise TypeError("n måste vara ett heltal")
    
    if n < 0:
        raise ValueError("n måste vara icke-negativt")
    
    if n == 0:
        return 0
    elif n == 1:
        return 1
    
    # Iterativ implementation för effektivitet
    prev, curr = 0, 1
    for i in range(2, n + 1):
        prev, curr = curr, prev + curr
    
    return curr