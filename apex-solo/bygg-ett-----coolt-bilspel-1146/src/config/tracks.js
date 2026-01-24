/**
 * GRAVSHIFT - Track Segment Definitions
 * Defines the building blocks for procedural track generation
 */

const TRACK_SEGMENTS = {
    // ===== STRAIGHT SEGMENTS =====
    STRAIGHT_FLAT: {
        type: 'straight',
        length: 200,
        curve: 0,
        rotation: 0,
        width: 1.0,
        difficulty: 0,
    },
    
    STRAIGHT_NARROW: {
        type: 'straight',
        length: 200,
        curve: 0,
        rotation: 0,
        width: 0.7,
        difficulty: 1,
    },
    
    STRAIGHT_WIDE: {
        type: 'straight',
        length: 200,
        curve: 0,
        rotation: 0,
        width: 1.3,
        difficulty: 0,
    },
    
    // ===== CURVE SEGMENTS =====
    CURVE_GENTLE_LEFT: {
        type: 'curve',
        length: 200,
        curve: -2,
        rotation: 0,
        difficulty: 1,
    },
    
    CURVE_GENTLE_RIGHT: {
        type: 'curve',
        length: 200,
        curve: 2,
        rotation: 0,
        difficulty: 1,
    },
    
    CURVE_SHARP_LEFT: {
        type: 'curve',
        length: 150,
        curve: -5,
        rotation: 0,
        difficulty: 2,
    },
    
    CURVE_SHARP_RIGHT: {
        type: 'curve',
        length: 150,
        curve: 5,
        rotation: 0,
        difficulty: 2,
    },
    
    CURVE_HAIRPIN_LEFT: {
        type: 'curve',
        length: 100,
        curve: -10,
        rotation: 0,
        difficulty: 4,
    },
    
    CURVE_HAIRPIN_RIGHT: {
        type: 'curve',
        length: 100,
        curve: 10,
        rotation: 0,
        difficulty: 4,
    },
    
    // ===== S-CURVE SEGMENTS =====
    S_CURVE_GENTLE: {
        type: 'scurve',
        length: 400,
        pattern: [2, -2],
        rotation: 0,
        difficulty: 2,
    },
    
    S_CURVE_AGGRESSIVE: {
        type: 'scurve',
        length: 300,
        pattern: [5, -5],
        rotation: 0,
        difficulty: 3,
    },
    
    CHICANE: {
        type: 'scurve',
        length: 250,
        pattern: [4, -4, 4, -4],
        rotation: 0,
        difficulty: 4,
    },
    
    // ===== ROTATION SEGMENTS (GRAVITY SHIFT!) =====
    ROLL_15_LEFT: {
        type: 'roll',
        length: 200,
        curve: 0,
        rotation: -15,
        difficulty: 1,
    },
    
    ROLL_15_RIGHT: {
        type: 'roll',
        length: 200,
        curve: 0,
        rotation: 15,
        difficulty: 1,
    },
    
    ROLL_30_LEFT: {
        type: 'roll',
        length: 250,
        curve: 0,
        rotation: -30,
        difficulty: 2,
    },
    
    ROLL_30_RIGHT: {
        type: 'roll',
        length: 250,
        curve: 0,
        rotation: 30,
        difficulty: 2,
    },
    
    ROLL_45_LEFT: {
        type: 'roll',
        length: 300,
        curve: 0,
        rotation: -45,
        difficulty: 3,
    },
    
    ROLL_45_RIGHT: {
        type: 'roll',
        length: 300,
        curve: 0,
        rotation: 45,
        difficulty: 3,
    },
    
    ROLL_90_LEFT: {
        type: 'roll',
        length: 400,
        curve: 0,
        rotation: -90,
        difficulty: 4,
    },
    
    ROLL_90_RIGHT: {
        type: 'roll',
        length: 400,
        curve: 0,
        rotation: 90,
        difficulty: 4,
    },
    
    ROLL_180: {
        type: 'roll',
        length: 600,
        curve: 0,
        rotation: 180,
        difficulty: 5,
    },
    
    BARREL_ROLL: {
        type: 'roll',
        length: 800,
        curve: 0,
        rotation: 360,
        difficulty: 6,
    },
    
    // ===== COMBINED SEGMENTS =====
    CURVE_WITH_ROLL_LEFT: {
        type: 'combined',
        length: 300,
        curve: -3,
        rotation: -30,
        difficulty: 3,
    },
    
    CURVE_WITH_ROLL_RIGHT: {
        type: 'combined',
        length: 300,
        curve: 3,
        rotation: 30,
        difficulty: 3,
    },
    
    CORKSCREW_LEFT: {
        type: 'combined',
        length: 500,
        curve: -2,
        rotation: 180,
        difficulty: 5,
    },
    
    CORKSCREW_RIGHT: {
        type: 'combined',
        length: 500,
        curve: 2,
        rotation: 180,
        difficulty: 5,
    },
    
    DEATH_SPIRAL: {
        type: 'combined',
        length: 1000,
        curve: 3,
        rotation: 720,
        difficulty: 7,
    },
    
    // ===== SPECIAL SEGMENTS =====
    TUNNEL_ENTRY: {
        type: 'special',
        length: 150,
        curve: 0,
        rotation: 0,
        effect: 'tunnel_start',
        difficulty: 0,
    },
    
    TUNNEL_EXIT: {
        type: 'special',
        length: 150,
        curve: 0,
        rotation: 0,
        effect: 'tunnel_end',
        difficulty: 0,
    },
    
    JUMP_RAMP: {
        type: 'special',
        length: 100,
        curve: 0,
        rotation: 0,
        effect: 'jump',
        jumpHeight: 200,
        jumpDistance: 400,
        difficulty: 3,
    },
    
    BOOST_PAD: {
        type: 'special',
        length: 100,
        curve: 0,
        rotation: 0,
        effect: 'boost',
        boostAmount: 1.5,
        difficulty: 0,
    },
    
    GRAVITY_FLIP: {
        type: 'special',
        length: 200,
        curve: 0,
        rotation: 180,
        effect: 'gravity_invert',
        instant: true,
        difficulty: 5,
    },
    
    SLOW_ZONE: {
        type: 'special',
        length: 300,
        curve: 0,
        rotation: 0,
        effect: 'slowdown',
        speedMultiplier: 0.6,
        difficulty: 1,
    },
    
    CHECKPOINT: {
        type: 'special',
        length: 50,
        curve: 0,
        rotation: 0,
        effect: 'checkpoint',
        difficulty: 0,
    },
};

// Segment pools for procedural generation
const SEGMENT_POOLS = {
    easy: [
        'STRAIGHT_FLAT',
        'STRAIGHT_WIDE',
        'CURVE_GENTLE_LEFT',
        'CURVE_GENTLE_RIGHT',
        'ROLL_15_LEFT',
        'ROLL_15_RIGHT',
        'BOOST_PAD',
    ],
    
    medium: [
        'STRAIGHT_FLAT',
        'STRAIGHT_NARROW',
        'CURVE_GENTLE_LEFT',
        'CURVE_GENTLE_RIGHT',
        'CURVE_SHARP_LEFT',
        'CURVE_SHARP_RIGHT',
        'S_CURVE_GENTLE',
        'ROLL_15_LEFT',
        'ROLL_15_RIGHT',
        'ROLL_30_LEFT',
        'ROLL_30_RIGHT',
        'TUNNEL_ENTRY',
        'TUNNEL_EXIT',
    ],
    
    hard: [
        'STRAIGHT_NARROW',
        'CURVE_SHARP_LEFT',
        'CURVE_SHARP_RIGHT',
        'S_CURVE_AGGRESSIVE',
        'CHICANE',
        'ROLL_30_LEFT',
        'ROLL_30_RIGHT',
        'ROLL_45_LEFT',
        'ROLL_45_RIGHT',
        'CURVE_WITH_ROLL_LEFT',
        'CURVE_WITH_ROLL_RIGHT',
        'JUMP_RAMP',
    ],
    
    extreme: [
        'STRAIGHT_NARROW',
        'CURVE_HAIRPIN_LEFT',
        'CURVE_HAIRPIN_RIGHT',
        'CHICANE',
        'ROLL_45_LEFT',
        'ROLL_45_RIGHT',
        'ROLL_90_LEFT',
        'ROLL_90_RIGHT',
        'ROLL_180',
        'CORKSCREW_LEFT',
        'CORKSCREW_RIGHT',
        'GRAVITY_FLIP',
    ],
    
    nightmare: [
        'CURVE_HAIRPIN_LEFT',
        'CURVE_HAIRPIN_RIGHT',
        'ROLL_90_LEFT',
        'ROLL_90_RIGHT',
        'ROLL_180',
        'BARREL_ROLL',
        'CORKSCREW_LEFT',
        'CORKSCREW_RIGHT',
        'DEATH_SPIRAL',
        'GRAVITY_FLIP',
    ],
};

// Track generation rules
const TRACK_RULES = {
    // Minimum straight after sharp turn
    afterSharpTurn: {
        minStraight: 2,
        allowedNext: ['STRAIGHT_FLAT', 'STRAIGHT_WIDE', 'CURVE_GENTLE_LEFT', 'CURVE_GENTLE_RIGHT'],
    },
    
    // After big rotation, give breathing room
    afterBigRotation: {
        minStraight: 3,
        maxCurve: 2,
    },
    
    // Checkpoint spacing
    checkpointFrequency: {
        minSegments: 15,
        maxSegments: 25,
    },
    
    // Difficulty progression
    difficultyRamp: {
        segmentsPerDifficultyIncrease: 20,
        maxDifficulty: 7,
    },
    
    // Power-up and obstacle placement
    spawnRules: {
        minDistanceBetweenObstacles: 3,
        minDistanceBetweenPowerups: 10,
        preferSpawnOnStraights: true,
    },
};

// Export
if (typeof window !== 'undefined') {
    window.TRACK_SEGMENTS = TRACK_SEGMENTS;
    window.SEGMENT_POOLS = SEGMENT_POOLS;
    window.TRACK_RULES = TRACK_RULES;
}
