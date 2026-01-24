/**
 * GRAVSHIFT - Color Utilities
 * Color manipulation and palette management
 */

const ColorUtils = {
    /**
     * Convert hex color to RGB object
     */
    hexToRgb(hex) {
        const r = (hex >> 16) & 255;
        const g = (hex >> 8) & 255;
        const b = hex & 255;
        return { r, g, b };
    },
    
    /**
     * Convert RGB to hex
     */
    rgbToHex(r, g, b) {
        return (r << 16) + (g << 8) + b;
    },
    
    /**
     * Convert hex to CSS string
     */
    hexToCss(hex) {
        return '#' + hex.toString(16).padStart(6, '0');
    },
    
    /**
     * Interpolate between two colors
     */
    lerpColor(color1, color2, t) {
        const rgb1 = this.hexToRgb(color1);
        const rgb2 = this.hexToRgb(color2);
        
        const r = Math.round(rgb1.r + (rgb2.r - rgb1.r) * t);
        const g = Math.round(rgb1.g + (rgb2.g - rgb1.g) * t);
        const b = Math.round(rgb1.b + (rgb2.b - rgb1.b) * t);
        
        return this.rgbToHex(r, g, b);
    },
    
    /**
     * Lighten a color
     */
    lighten(hex, amount) {
        const rgb = this.hexToRgb(hex);
        const r = Math.min(255, Math.round(rgb.r + (255 - rgb.r) * amount));
        const g = Math.min(255, Math.round(rgb.g + (255 - rgb.g) * amount));
        const b = Math.min(255, Math.round(rgb.b + (255 - rgb.b) * amount));
        return this.rgbToHex(r, g, b);
    },
    
    /**
     * Darken a color
     */
    darken(hex, amount) {
        const rgb = this.hexToRgb(hex);
        const r = Math.round(rgb.r * (1 - amount));
        const g = Math.round(rgb.g * (1 - amount));
        const b = Math.round(rgb.b * (1 - amount));
        return this.rgbToHex(r, g, b);
    },
    
    /**
     * Add alpha to hex color for Phaser
     */
    withAlpha(hex, alpha) {
        return { color: hex, alpha: alpha };
    },
    
    /**
     * Convert HSL to RGB hex
     */
    hslToHex(h, s, l) {
        h = h / 360;
        s = s / 100;
        l = l / 100;
        
        let r, g, b;
        
        if (s === 0) {
            r = g = b = l;
        } else {
            const hue2rgb = (p, q, t) => {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1/6) return p + (q - p) * 6 * t;
                if (t < 1/2) return q;
                if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
                return p;
            };
            
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            const p = 2 * l - q;
            r = hue2rgb(p, q, h + 1/3);
            g = hue2rgb(p, q, h);
            b = hue2rgb(p, q, h - 1/3);
        }
        
        return this.rgbToHex(
            Math.round(r * 255),
            Math.round(g * 255),
            Math.round(b * 255)
        );
    },
    
    /**
     * Get color from gradient based on position
     */
    getGradientColor(colors, t) {
        if (colors.length === 0) return 0x000000;
        if (colors.length === 1) return colors[0];
        
        t = Math.max(0, Math.min(1, t));
        const segment = t * (colors.length - 1);
        const index = Math.floor(segment);
        const localT = segment - index;
        
        if (index >= colors.length - 1) return colors[colors.length - 1];
        
        return this.lerpColor(colors[index], colors[index + 1], localT);
    },
    
    /**
     * Generate rainbow color from hue (0-1)
     */
    rainbow(t) {
        return this.hslToHex(t * 360, 100, 50);
    },
    
    /**
     * GRAVSHIFT color palettes
     */
    palettes: {
        neonCyan: {
            primary: 0x00ffff,
            secondary: 0x0088ff,
            accent: 0x00ffaa,
            dark: 0x001a1a,
            glow: 0x00ffff,
        },
        neonMagenta: {
            primary: 0xff00ff,
            secondary: 0xff0088,
            accent: 0xaa00ff,
            dark: 0x1a001a,
            glow: 0xff00ff,
        },
        neonYellow: {
            primary: 0xffff00,
            secondary: 0xffaa00,
            accent: 0xaaff00,
            dark: 0x1a1a00,
            glow: 0xffff00,
        },
        vaporwave: {
            primary: 0xff6ad5,
            secondary: 0xc774e8,
            accent: 0xad8cff,
            dark: 0x1a0a2e,
            glow: 0xff71ce,
        },
        cyber: {
            primary: 0x00ff41,
            secondary: 0x008f11,
            accent: 0x00ff00,
            dark: 0x0a1a0a,
            glow: 0x00ff41,
        },
        sunset: {
            primary: 0xff6b35,
            secondary: 0xf7c59f,
            accent: 0xff0054,
            dark: 0x2a0a1a,
            glow: 0xff6b35,
        },
        ice: {
            primary: 0x7fdbff,
            secondary: 0xb8e2f2,
            accent: 0x39cccc,
            dark: 0x0a1a2a,
            glow: 0x7fdbff,
        },
        void: {
            primary: 0xffffff,
            secondary: 0x888888,
            accent: 0xff0040,
            dark: 0x000008,
            glow: 0xffffff,
        },
    },
    
    /**
     * Get palette for level zone
     */
    getPaletteForZone(zoneName) {
        const mapping = {
            'initiation': 'neonCyan',
            'distortion': 'neonMagenta',
            'chaos': 'neonYellow',
            'beyond': 'void',
        };
        return this.palettes[mapping[zoneName] || 'neonCyan'];
    },
    
    /**
     * Create pulsing color effect
     */
    pulseColor(baseColor, time, speed = 1, intensity = 0.3) {
        const pulse = (Math.sin(time * speed) + 1) / 2;
        return this.lighten(baseColor, pulse * intensity);
    },
    
    /**
     * Create gradient array for particle effects
     */
    createGradient(startColor, endColor, steps = 10) {
        const colors = [];
        for (let i = 0; i < steps; i++) {
            colors.push(this.lerpColor(startColor, endColor, i / (steps - 1)));
        }
        return colors;
    },
};

// Export
if (typeof window !== 'undefined') {
    window.ColorUtils = ColorUtils;
}
