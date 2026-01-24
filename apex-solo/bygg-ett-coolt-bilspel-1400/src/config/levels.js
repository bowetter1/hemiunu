/**
 * NEON TRAIL - Level Configuration
 * Defines level progression, spawning patterns, and difficulty curves
 */

const LEVEL_CONFIG = {
    // Mode types
    MODES: {
        ENDLESS: 'endless',
        CHALLENGE: 'challenge',
        TIME_ATTACK: 'time_attack',
    },
    
    // Current active mode
    currentMode: 'endless',
};

/**
 * Endless Mode Configuration
 * Difficulty increases infinitely based on distance
 */
const ENDLESS_CONFIG = {
    name: 'ENDLESS',
    description: 'Survive as long as you can',
    
    // Starting conditions
    startSpeed: ROAD_CONFIG.BASE_SCROLL_SPEED,
    startDifficulty: 1,
    
    // Progression
    speedIncreaseRate: 0.0005, // per frame
    maxSpeed: ROAD_CONFIG.MAX_SCROLL_SPEED,
    
    // Milestones (distance thresholds)
    milestones: [
        { distance: 500, message: 'WARMING UP', bonus: 100 },
        { distance: 1000, message: 'GETTING STARTED', bonus: 250 },
        { distance: 2500, message: 'NICE MOVES!', bonus: 500 },
        { distance: 5000, message: 'NEON VETERAN', bonus: 1000 },
        { distance: 7500, message: 'TRAIL MASTER', bonus: 2000 },
        { distance: 10000, message: 'LEGENDARY!', bonus: 5000 },
        { distance: 15000, message: 'IMPOSSIBLE!', bonus: 10000 },
        { distance: 20000, message: 'GOD MODE', bonus: 25000 },
    ],
    
    // Difficulty phases
    phases: [
        {
            name: 'Tutorial',
            startDistance: 0,
            obstacleFrequency: 0.005,
            obstacleTypes: ['cone'],
            powerUpFrequency: 0.02,
            trailFadeSpeed: 1.2,
            curviness: 0.3,
        },
        {
            name: 'Easy',
            startDistance: 300,
            obstacleFrequency: 0.01,
            obstacleTypes: ['cone', 'barrier'],
            powerUpFrequency: 0.015,
            trailFadeSpeed: 1.0,
            curviness: 0.5,
        },
        {
            name: 'Medium',
            startDistance: 1000,
            obstacleFrequency: 0.015,
            obstacleTypes: ['cone', 'barrier', 'oil'],
            powerUpFrequency: 0.012,
            trailFadeSpeed: 0.9,
            curviness: 0.7,
        },
        {
            name: 'Hard',
            startDistance: 2500,
            obstacleFrequency: 0.02,
            obstacleTypes: ['cone', 'barrier', 'oil', 'wall'],
            powerUpFrequency: 0.01,
            trailFadeSpeed: 0.8,
            curviness: 0.85,
        },
        {
            name: 'Insane',
            startDistance: 5000,
            obstacleFrequency: 0.025,
            obstacleTypes: ['cone', 'barrier', 'oil', 'wall', 'moving'],
            powerUpFrequency: 0.008,
            trailFadeSpeed: 0.7,
            curviness: 1.0,
        },
        {
            name: 'Nightmare',
            startDistance: 7500,
            obstacleFrequency: 0.03,
            obstacleTypes: ['cone', 'barrier', 'oil', 'wall', 'moving'],
            powerUpFrequency: 0.006,
            trailFadeSpeed: 0.6,
            curviness: 1.0,
        },
        {
            name: 'Impossible',
            startDistance: 10000,
            obstacleFrequency: 0.035,
            obstacleTypes: ['cone', 'barrier', 'oil', 'wall', 'moving'],
            powerUpFrequency: 0.005,
            trailFadeSpeed: 0.5,
            curviness: 1.0,
        },
    ],
    
    /**
     * Get current phase based on distance
     */
    getPhase: function(distance) {
        let currentPhase = this.phases[0];
        for (const phase of this.phases) {
            if (distance >= phase.startDistance) {
                currentPhase = phase;
            }
        }
        return currentPhase;
    },
    
    /**
     * Check for milestone achievement
     */
    checkMilestone: function(distance, lastMilestoneIndex) {
        for (let i = lastMilestoneIndex + 1; i < this.milestones.length; i++) {
            if (distance >= this.milestones[i].distance) {
                return i;
            }
        }
        return lastMilestoneIndex;
    },
};

/**
 * Challenge Mode Configuration
 * Pre-defined levels with specific goals
 */
const CHALLENGE_LEVELS = [
    {
        id: 1,
        name: 'First Drive',
        description: 'Reach 500m without hitting your trail',
        goal: { type: 'distance', value: 500 },
        stars: [
            { requirement: 'complete', stars: 1 },
            { requirement: { type: 'score', value: 1000 }, stars: 2 },
            { requirement: { type: 'no_powerups', value: true }, stars: 3 },
        ],
        settings: {
            obstacleFrequency: 0.008,
            obstacleTypes: ['cone'],
            powerUpFrequency: 0.02,
            trailFadeSpeed: 1.0,
            speedMultiplier: 0.8,
        },
        unlocked: true,
    },
    {
        id: 2,
        name: 'Drift King',
        description: 'Score 5000 points with drift bonuses',
        goal: { type: 'score', value: 5000 },
        stars: [
            { requirement: 'complete', stars: 1 },
            { requirement: { type: 'drift_count', value: 20 }, stars: 2 },
            { requirement: { type: 'time', value: 60 }, stars: 3 },
        ],
        settings: {
            obstacleFrequency: 0.01,
            obstacleTypes: ['cone', 'barrier'],
            powerUpFrequency: 0.015,
            trailFadeSpeed: 0.9,
            speedMultiplier: 1.0,
        },
        unlocked: false,
        unlockRequirement: { level: 1, stars: 1 },
    },
    {
        id: 3,
        name: 'Oil Slick',
        description: 'Navigate through oil spills for 1000m',
        goal: { type: 'distance', value: 1000 },
        stars: [
            { requirement: 'complete', stars: 1 },
            { requirement: { type: 'oil_dodged', value: 10 }, stars: 2 },
            { requirement: { type: 'no_hits', value: true }, stars: 3 },
        ],
        settings: {
            obstacleFrequency: 0.02,
            obstacleTypes: ['oil'],
            powerUpFrequency: 0.01,
            trailFadeSpeed: 0.8,
            speedMultiplier: 1.1,
        },
        unlocked: false,
        unlockRequirement: { level: 2, stars: 2 },
    },
    {
        id: 4,
        name: 'Ghost Runner',
        description: 'Use 5 Ghost power-ups in one run',
        goal: { type: 'powerup_count', powerupType: 'GHOST', value: 5 },
        stars: [
            { requirement: 'complete', stars: 1 },
            { requirement: { type: 'distance', value: 1500 }, stars: 2 },
            { requirement: { type: 'score', value: 10000 }, stars: 3 },
        ],
        settings: {
            obstacleFrequency: 0.015,
            obstacleTypes: ['cone', 'barrier', 'wall'],
            powerUpFrequency: 0.025,
            powerUpTypes: ['GHOST'],
            trailFadeSpeed: 0.7,
            speedMultiplier: 1.0,
        },
        unlocked: false,
        unlockRequirement: { level: 3, stars: 1 },
    },
    {
        id: 5,
        name: 'Gauntlet',
        description: 'Survive 2000m through all obstacles',
        goal: { type: 'distance', value: 2000 },
        stars: [
            { requirement: 'complete', stars: 1 },
            { requirement: { type: 'score', value: 15000 }, stars: 2 },
            { requirement: { type: 'near_misses', value: 20 }, stars: 3 },
        ],
        settings: {
            obstacleFrequency: 0.025,
            obstacleTypes: ['cone', 'barrier', 'oil', 'wall', 'moving'],
            powerUpFrequency: 0.01,
            trailFadeSpeed: 0.6,
            speedMultiplier: 1.2,
        },
        unlocked: false,
        unlockRequirement: { level: 4, stars: 2 },
    },
];

/**
 * Time Attack Mode Configuration
 * Race against the clock
 */
const TIME_ATTACK_CONFIG = {
    name: 'TIME ATTACK',
    description: 'Score as much as possible in 60 seconds',
    
    // Time settings
    duration: 60, // seconds
    warningTime: 10, // when to show warning
    
    // Time bonuses
    bonusTime: {
        powerup: 2,
        milestone: 5,
        nearMiss: 1,
    },
    
    // Difficulty (fixed, no progression)
    settings: {
        obstacleFrequency: 0.02,
        obstacleTypes: ['cone', 'barrier', 'oil'],
        powerUpFrequency: 0.015,
        trailFadeSpeed: 0.8,
        speedMultiplier: 1.2,
    },
};

/**
 * Spawn Patterns
 * Pre-defined obstacle arrangements
 */
const SPAWN_PATTERNS = {
    // Single obstacles
    single_cone: [
        { type: 'cone', lane: 'random' },
    ],
    single_barrier: [
        { type: 'barrier', lane: 'random' },
    ],
    
    // Pairs
    double_cone: [
        { type: 'cone', lane: 1 },
        { type: 'cone', lane: 3 },
    ],
    barrier_gap: [
        { type: 'barrier', lane: 0 },
        { type: 'barrier', lane: 4 },
    ],
    
    // Formations
    cone_zigzag: [
        { type: 'cone', lane: 0, offset: 0 },
        { type: 'cone', lane: 2, offset: 100 },
        { type: 'cone', lane: 4, offset: 200 },
    ],
    wall_section: [
        { type: 'wall', lane: 0 },
        { type: 'wall', lane: 1 },
        { type: 'wall', lane: 2 },
        // Leaves lanes 3-4 open
    ],
    
    // Complex
    gauntlet: [
        { type: 'barrier', lane: 0, offset: 0 },
        { type: 'cone', lane: 2, offset: 50 },
        { type: 'barrier', lane: 4, offset: 0 },
        { type: 'oil', lane: 1, offset: 150 },
        { type: 'oil', lane: 3, offset: 150 },
    ],
    
    // Moving obstacles
    moving_pair: [
        { type: 'moving', lane: 1, direction: 'right' },
        { type: 'moving', lane: 3, direction: 'left' },
    ],
};

/**
 * Get appropriate spawn pattern based on difficulty
 */
function getSpawnPattern(difficulty, obstacleTypes) {
    const patterns = Object.keys(SPAWN_PATTERNS);
    const validPatterns = patterns.filter(key => {
        const pattern = SPAWN_PATTERNS[key];
        return pattern.every(obs => obstacleTypes.includes(obs.type));
    });
    
    if (validPatterns.length === 0) return [SPAWN_PATTERNS.single_cone];
    
    // Weight towards harder patterns as difficulty increases
    const index = Math.min(
        Math.floor(Math.random() * validPatterns.length * (1 + difficulty * 0.1)),
        validPatterns.length - 1
    );
    
    return SPAWN_PATTERNS[validPatterns[index]];
}

// Freeze configurations
Object.freeze(LEVEL_CONFIG);
Object.freeze(ENDLESS_CONFIG);
Object.freeze(CHALLENGE_LEVELS);
Object.freeze(TIME_ATTACK_CONFIG);
Object.freeze(SPAWN_PATTERNS);
