"""
Matematikbibliotek för primtal och andra matematiska funktioner.
"""

from .prime import is_prime
from .math_funcs import factorial
from .geometry import circle_area, rectangle_area, triangle_area

__all__ = ['is_prime', 'factorial', 'circle_area', 'rectangle_area', 'triangle_area']