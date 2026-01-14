"""
Geometriska beräkningar.
"""

import math


def circle_area(radius):
    """
    Beräknar arean av en cirkel.
    
    Args:
        radius (float): Radien av cirkeln
        
    Returns:
        float: Arean av cirkeln (π * r²)
        
    Raises:
        ValueError: Om radius är negativ
        TypeError: Om radius inte är ett nummer
    """
    if not isinstance(radius, (int, float)):
        raise TypeError("Radius måste vara ett nummer")
    
    if radius < 0:
        raise ValueError("Radius kan inte vara negativ")
    
    return math.pi * radius ** 2


def rectangle_area(width, height):
    """
    Beräknar arean av en rektangel.
    
    Args:
        width (float): Bredden av rektangeln
        height (float): Höjden av rektangeln
        
    Returns:
        float: Arean av rektangeln (bredd * höjd)
        
    Raises:
        ValueError: Om bredd eller höjd är negativ
        TypeError: Om bredd eller höjd inte är ett nummer
    """
    if not isinstance(width, (int, float)):
        raise TypeError("Bredd måste vara ett nummer")
    
    if not isinstance(height, (int, float)):
        raise TypeError("Höjd måste vara ett nummer")
    
    if width < 0:
        raise ValueError("Bredd kan inte vara negativ")
        
    if height < 0:
        raise ValueError("Höjd kan inte vara negativ")
    
    return width * height


def triangle_area(base, height):
    """
    Beräknar arean av en triangel.
    
    Args:
        base (float): Basen av triangeln
        height (float): Höjden av triangeln
        
    Returns:
        float: Arean av triangeln ((bas * höjd) / 2)
        
    Raises:
        ValueError: Om bas eller höjd är negativ
        TypeError: Om bas eller höjd inte är ett nummer
    """
    if not isinstance(base, (int, float)):
        raise TypeError("Bas måste vara ett nummer")
    
    if not isinstance(height, (int, float)):
        raise TypeError("Höjd måste vara ett nummer")
    
    if base < 0:
        raise ValueError("Bas kan inte vara negativ")
        
    if height < 0:
        raise ValueError("Höjd kan inte vara negativ")
    
    return (base * height) / 2