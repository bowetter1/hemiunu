/**
 * GRAVSHIFT - Easing Functions
 * Smooth animation curves for UI and gameplay
 */

const Easing = {
    // Linear
    linear(t) {
        return t;
    },
    
    // Quadratic
    easeInQuad(t) {
        return t * t;
    },
    
    easeOutQuad(t) {
        return t * (2 - t);
    },
    
    easeInOutQuad(t) {
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    },
    
    // Cubic
    easeInCubic(t) {
        return t * t * t;
    },
    
    easeOutCubic(t) {
        return (--t) * t * t + 1;
    },
    
    easeInOutCubic(t) {
        return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
    },
    
    // Quartic
    easeInQuart(t) {
        return t * t * t * t;
    },
    
    easeOutQuart(t) {
        return 1 - (--t) * t * t * t;
    },
    
    easeInOutQuart(t) {
        return t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (--t) * t * t * t;
    },
    
    // Quintic
    easeInQuint(t) {
        return t * t * t * t * t;
    },
    
    easeOutQuint(t) {
        return 1 + (--t) * t * t * t * t;
    },
    
    easeInOutQuint(t) {
        return t < 0.5 ? 16 * t * t * t * t * t : 1 + 16 * (--t) * t * t * t * t;
    },
    
    // Sinusoidal
    easeInSine(t) {
        return 1 - Math.cos((t * Math.PI) / 2);
    },
    
    easeOutSine(t) {
        return Math.sin((t * Math.PI) / 2);
    },
    
    easeInOutSine(t) {
        return -(Math.cos(Math.PI * t) - 1) / 2;
    },
    
    // Exponential
    easeInExpo(t) {
        return t === 0 ? 0 : Math.pow(2, 10 * t - 10);
    },
    
    easeOutExpo(t) {
        return t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
    },
    
    easeInOutExpo(t) {
        if (t === 0) return 0;
        if (t === 1) return 1;
        if (t < 0.5) return Math.pow(2, 20 * t - 10) / 2;
        return (2 - Math.pow(2, -20 * t + 10)) / 2;
    },
    
    // Circular
    easeInCirc(t) {
        return 1 - Math.sqrt(1 - t * t);
    },
    
    easeOutCirc(t) {
        return Math.sqrt(1 - (--t) * t);
    },
    
    easeInOutCirc(t) {
        return t < 0.5
            ? (1 - Math.sqrt(1 - 4 * t * t)) / 2
            : (Math.sqrt(1 - Math.pow(-2 * t + 2, 2)) + 1) / 2;
    },
    
    // Elastic
    easeInElastic(t) {
        const c4 = (2 * Math.PI) / 3;
        return t === 0 ? 0 : t === 1 ? 1 : -Math.pow(2, 10 * t - 10) * Math.sin((t * 10 - 10.75) * c4);
    },
    
    easeOutElastic(t) {
        const c4 = (2 * Math.PI) / 3;
        return t === 0 ? 0 : t === 1 ? 1 : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
    },
    
    easeInOutElastic(t) {
        const c5 = (2 * Math.PI) / 4.5;
        return t === 0 ? 0 : t === 1 ? 1 : t < 0.5
            ? -(Math.pow(2, 20 * t - 10) * Math.sin((20 * t - 11.125) * c5)) / 2
            : (Math.pow(2, -20 * t + 10) * Math.sin((20 * t - 11.125) * c5)) / 2 + 1;
    },
    
    // Back
    easeInBack(t) {
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return c3 * t * t * t - c1 * t * t;
    },
    
    easeOutBack(t) {
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    },
    
    easeInOutBack(t) {
        const c1 = 1.70158;
        const c2 = c1 * 1.525;
        return t < 0.5
            ? (Math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
            : (Math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
    },
    
    // Bounce
    easeInBounce(t) {
        return 1 - Easing.easeOutBounce(1 - t);
    },
    
    easeOutBounce(t) {
        const n1 = 7.5625;
        const d1 = 2.75;
        if (t < 1 / d1) {
            return n1 * t * t;
        } else if (t < 2 / d1) {
            return n1 * (t -= 1.5 / d1) * t + 0.75;
        } else if (t < 2.5 / d1) {
            return n1 * (t -= 2.25 / d1) * t + 0.9375;
        } else {
            return n1 * (t -= 2.625 / d1) * t + 0.984375;
        }
    },
    
    easeInOutBounce(t) {
        return t < 0.5
            ? (1 - Easing.easeOutBounce(1 - 2 * t)) / 2
            : (1 + Easing.easeOutBounce(2 * t - 1)) / 2;
    },
    
    // Custom for GRAVSHIFT
    
    // Speed burst - quick start, maintain speed
    speedBurst(t) {
        return 1 - Math.pow(1 - t, 4);
    },
    
    // Gravity pull - accelerate like falling
    gravityPull(t) {
        return t * t * t;
    },
    
    // Warp effect - pause in middle
    warpPause(t) {
        if (t < 0.4) return Easing.easeInQuad(t / 0.4) * 0.4;
        if (t < 0.6) return 0.4;
        return 0.4 + Easing.easeOutQuad((t - 0.6) / 0.4) * 0.6;
    },
    
    // Shockwave - overshoot and settle
    shockwave(t) {
        return 1 - Math.cos(t * Math.PI * 2.5) * Math.pow(1 - t, 2);
    },
    
    // Heartbeat - double pulse
    heartbeat(t) {
        const pulse1 = Math.sin(t * Math.PI * 2);
        const pulse2 = Math.sin(t * Math.PI * 4 - 1) * 0.3;
        return Math.max(0, (pulse1 + pulse2) * (1 - t * 0.3));
    },
    
    // Get easing function by name
    get(name) {
        return this[name] || this.linear;
    },
};

// Export
if (typeof window !== 'undefined') {
    window.Easing = Easing;
}
