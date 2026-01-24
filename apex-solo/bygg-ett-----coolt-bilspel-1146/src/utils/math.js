/**
 * GRAVSHIFT - Math Utilities
 * Mathematical helper functions for physics and rendering
 */

const MathUtils = {
    /**
     * Clamp a value between min and max
     */
    clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    },
    
    /**
     * Linear interpolation
     */
    lerp(start, end, t) {
        return start + (end - start) * t;
    },
    
    /**
     * Smooth interpolation (ease in-out)
     */
    smoothLerp(start, end, t) {
        t = t * t * (3 - 2 * t);
        return start + (end - start) * t;
    },
    
    /**
     * Map value from one range to another
     */
    map(value, inMin, inMax, outMin, outMax) {
        return ((value - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin;
    },
    
    /**
     * Convert degrees to radians
     */
    degToRad(degrees) {
        return degrees * (Math.PI / 180);
    },
    
    /**
     * Convert radians to degrees
     */
    radToDeg(radians) {
        return radians * (180 / Math.PI);
    },
    
    /**
     * Normalize angle to 0-360 range
     */
    normalizeAngle(angle) {
        while (angle < 0) angle += 360;
        while (angle >= 360) angle -= 360;
        return angle;
    },
    
    /**
     * Get shortest angle difference between two angles
     */
    angleDifference(a, b) {
        const diff = ((b - a + 180) % 360) - 180;
        return diff < -180 ? diff + 360 : diff;
    },
    
    /**
     * Distance between two points
     */
    distance(x1, y1, x2, y2) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return Math.sqrt(dx * dx + dy * dy);
    },
    
    /**
     * Distance squared (faster, no sqrt)
     */
    distanceSquared(x1, y1, x2, y2) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return dx * dx + dy * dy;
    },
    
    /**
     * Random float between min and max
     */
    randomRange(min, max) {
        return min + Math.random() * (max - min);
    },
    
    /**
     * Random integer between min and max (inclusive)
     */
    randomInt(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    },
    
    /**
     * Pick random element from array
     */
    randomElement(array) {
        return array[Math.floor(Math.random() * array.length)];
    },
    
    /**
     * Shuffle array in place
     */
    shuffle(array) {
        for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
        }
        return array;
    },
    
    /**
     * Check if point is inside rectangle
     */
    pointInRect(px, py, rx, ry, rw, rh) {
        return px >= rx && px <= rx + rw && py >= ry && py <= ry + rh;
    },
    
    /**
     * Check if two rectangles overlap
     */
    rectsOverlap(r1x, r1y, r1w, r1h, r2x, r2y, r2w, r2h) {
        return r1x < r2x + r2w && r1x + r1w > r2x && r1y < r2y + r2h && r1y + r1h > r2y;
    },
    
    /**
     * Check if two circles overlap
     */
    circlesOverlap(c1x, c1y, c1r, c2x, c2y, c2r) {
        const dist = this.distanceSquared(c1x, c1y, c2x, c2y);
        const radiiSum = c1r + c2r;
        return dist < radiiSum * radiiSum;
    },
    
    /**
     * Get point on bezier curve
     */
    bezierPoint(t, p0, p1, p2, p3) {
        const u = 1 - t;
        const tt = t * t;
        const uu = u * u;
        const uuu = uu * u;
        const ttt = tt * t;
        
        return {
            x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x,
            y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y,
        };
    },
    
    /**
     * Rotate a point around origin
     */
    rotatePoint(x, y, angle) {
        const rad = this.degToRad(angle);
        const cos = Math.cos(rad);
        const sin = Math.sin(rad);
        return {
            x: x * cos - y * sin,
            y: x * sin + y * cos,
        };
    },
    
    /**
     * Rotate a point around another point
     */
    rotatePointAround(x, y, cx, cy, angle) {
        const rad = this.degToRad(angle);
        const cos = Math.cos(rad);
        const sin = Math.sin(rad);
        const nx = cos * (x - cx) - sin * (y - cy) + cx;
        const ny = sin * (x - cx) + cos * (y - cy) + cy;
        return { x: nx, y: ny };
    },
    
    /**
     * Exponential decay (useful for smooth following)
     */
    expDecay(current, target, decay, dt) {
        return target + (current - target) * Math.exp(-decay * dt);
    },
    
    /**
     * Spring physics calculation
     */
    spring(current, target, velocity, stiffness, damping, dt) {
        const diff = target - current;
        const acceleration = diff * stiffness - velocity * damping;
        const newVelocity = velocity + acceleration * dt;
        const newPosition = current + newVelocity * dt;
        return { position: newPosition, velocity: newVelocity };
    },
    
    /**
     * Perlin-like noise (simplified)
     */
    noise(x, y = 0, z = 0) {
        const p = [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,
            69,142,8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,
            219,203,117,35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,
            68,175,74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,
            133,230,220,105,92,41,55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,
            73,209,76,132,187,208,89,18,169,200,196,135,130,116,188,159,86,164,100,
            109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,118,126,255,82,
            85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,119,248,
            152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,108,
            110,79,113,224,232,178,185,112,104,218,246,97,228,251,34,242,193,238,210,
            144,12,191,179,162,241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,
            106,157,184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,
            67,29,24,72,243,141,128,195,78,66,215,61,156,180];
        
        const fade = t => t * t * t * (t * (t * 6 - 15) + 10);
        const lerp = (t, a, b) => a + t * (b - a);
        
        const X = Math.floor(x) & 255;
        const Y = Math.floor(y) & 255;
        const Z = Math.floor(z) & 255;
        
        x -= Math.floor(x);
        y -= Math.floor(y);
        z -= Math.floor(z);
        
        const u = fade(x);
        const v = fade(y);
        const w = fade(z);
        
        const A = p[X] + Y;
        const AA = p[A] + Z;
        const AB = p[A + 1] + Z;
        const B = p[X + 1] + Y;
        const BA = p[B] + Z;
        const BB = p[B + 1] + Z;
        
        const grad = (hash, x, y, z) => {
            const h = hash & 15;
            const u = h < 8 ? x : y;
            const v = h < 4 ? y : h === 12 || h === 14 ? x : z;
            return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
        };
        
        return lerp(w,
            lerp(v,
                lerp(u, grad(p[AA], x, y, z), grad(p[BA], x - 1, y, z)),
                lerp(u, grad(p[AB], x, y - 1, z), grad(p[BB], x - 1, y - 1, z))
            ),
            lerp(v,
                lerp(u, grad(p[AA + 1], x, y, z - 1), grad(p[BA + 1], x - 1, y, z - 1)),
                lerp(u, grad(p[AB + 1], x, y - 1, z - 1), grad(p[BB + 1], x - 1, y - 1, z - 1))
            )
        );
    },
    
    /**
     * Format number with commas
     */
    formatNumber(num) {
        return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    },
    
    /**
     * Format time as MM:SS.ms
     */
    formatTime(ms) {
        const minutes = Math.floor(ms / 60000);
        const seconds = Math.floor((ms % 60000) / 1000);
        const millis = Math.floor((ms % 1000) / 10);
        return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}.${millis.toString().padStart(2, '0')}`;
    },
};

// Export
if (typeof window !== 'undefined') {
    window.MathUtils = MathUtils;
}
