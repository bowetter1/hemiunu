/**
 * GRAVSHIFT - Game Constants
 * All magic numbers and configuration values
 */

const GAME_CONFIG = {
    // Display
    WIDTH: 1280,
    HEIGHT: 720,
    
    // Physics
    GRAVITY_STRENGTH: 800,
    MAX_VELOCITY: 1200,
    FRICTION: 0.98,
    
    // Player defaults
    PLAYER: {
        ACCELERATION: 600,
        BRAKE_FORCE: 400,
        TURN_SPEED: 3.5,
        DRIFT_FACTOR: 0.95,
        MAX_SPEED: 800,
        BOOST_MULTIPLIER: 1.5,
        BOOST_DURATION: 2000,
        BOOST_COOLDOWN: 5000,
        NITRO_MAX: 100,
        NITRO_REGEN: 5,
        NITRO_DRAIN: 25,
    },
    
    // Track
    TRACK: {
        SEGMENT_LENGTH: 200,
        ROAD_WIDTH: 400,
        LANE_COUNT: 3,
        RENDER_DISTANCE: 100,
        FOV: 100,
        CAMERA_HEIGHT: 1000,
        CAMERA_DEPTH: 0.84,
    },
    
    // Scoring
    SCORE: {
        DISTANCE_MULTIPLIER: 10,
        DRIFT_BONUS: 50,
        NEAR_MISS_BONUS: 100,
        CHECKPOINT_BONUS: 500,
        PERFECT_LAP_BONUS: 2000,
        COMBO_MULTIPLIER_MAX: 10,
        COMBO_DECAY_TIME: 2000,
    },
    
    // Difficulty scaling
    DIFFICULTY: {
        OBSTACLE_SPAWN_BASE: 0.02,
        OBSTACLE_SPAWN_INCREASE: 0.005,
        SPEED_INCREASE_PER_LEVEL: 50,
        ROTATION_INCREASE_PER_LEVEL: 0.2,
    },
    
    // Visual
    COLORS: {
        BACKGROUND: 0x0a0a0f,
        ROAD: 0x1a1a2e,
        ROAD_LIGHT: 0x2a2a4e,
        LANE_MARKER: 0x00ffff,
        EDGE_GLOW: 0xff00ff,
        PLAYER: 0x00ffff,
        PLAYER_TRAIL: 0x00ffff,
        OBSTACLE: 0xff0040,
        POWERUP: 0x00ff00,
        CHECKPOINT: 0xffff00,
        UI_PRIMARY: 0x00ffff,
        UI_SECONDARY: 0xff00ff,
        UI_ACCENT: 0xffff00,
        UI_DANGER: 0xff0040,
        UI_SUCCESS: 0x00ff00,
    },
    
    // Audio
    AUDIO: {
        MASTER_VOLUME: 0.8,
        MUSIC_VOLUME: 0.6,
        SFX_VOLUME: 0.8,
    },
    
    // Storage keys
    STORAGE: {
        HIGHSCORE: 'gravshift_highscore',
        SETTINGS: 'gravshift_settings',
        UNLOCKED_LEVELS: 'gravshift_unlocked',
        BEST_TIMES: 'gravshift_times',
        GHOST_DATA: 'gravshift_ghost',
    },
};

// Vehicle types with different stats
const VEHICLES = {
    SPEEDER: {
        name: 'Speeder',
        maxSpeed: 900,
        acceleration: 500,
        handling: 2.5,
        boost: 1.8,
        color: 0x00ffff,
        description: 'Fast but tricky to control',
    },
    BALANCED: {
        name: 'Striker',
        maxSpeed: 750,
        acceleration: 600,
        handling: 3.5,
        boost: 1.5,
        color: 0xff00ff,
        description: 'Well-rounded performance',
    },
    TANK: {
        name: 'Fortress',
        maxSpeed: 600,
        acceleration: 700,
        handling: 4.5,
        boost: 1.2,
        color: 0xffff00,
        description: 'Slow but stable',
    },
    DRIFTER: {
        name: 'Ghost',
        maxSpeed: 800,
        acceleration: 550,
        handling: 2.0,
        boost: 2.0,
        color: 0x00ff00,
        description: 'Master of controlled chaos',
    },
};

// Power-up types
const POWERUPS = {
    BOOST: {
        name: 'Nitro Boost',
        duration: 3000,
        color: 0x00ffff,
        effect: 'speed',
        multiplier: 1.5,
    },
    SHIELD: {
        name: 'Gravity Shield',
        duration: 5000,
        color: 0xffff00,
        effect: 'invincibility',
    },
    SLOWMO: {
        name: 'Time Warp',
        duration: 4000,
        color: 0xff00ff,
        effect: 'slowmo',
        multiplier: 0.5,
    },
    MAGNET: {
        name: 'Score Magnet',
        duration: 6000,
        color: 0x00ff00,
        effect: 'magnet',
        radius: 200,
    },
    GHOST: {
        name: 'Phase Shift',
        duration: 3000,
        color: 0xffffff,
        effect: 'ghost',
    },
};

// Obstacle types
const OBSTACLES = {
    BARRIER: {
        name: 'Barrier',
        width: 100,
        height: 50,
        damage: 1,
        color: 0xff0040,
        breakable: false,
    },
    SPIKE: {
        name: 'Gravity Spike',
        width: 40,
        height: 60,
        damage: 2,
        color: 0xff4400,
        breakable: false,
    },
    DEBRIS: {
        name: 'Space Debris',
        width: 60,
        height: 40,
        damage: 1,
        color: 0x888888,
        breakable: true,
    },
    LASER: {
        name: 'Laser Grid',
        width: 200,
        height: 10,
        damage: 3,
        color: 0xff0000,
        breakable: false,
        animated: true,
    },
    MOVING: {
        name: 'Patrol Drone',
        width: 50,
        height: 50,
        damage: 2,
        color: 0xff8800,
        breakable: false,
        moves: true,
    },
};

// Export for non-module usage
if (typeof window !== 'undefined') {
    window.GAME_CONFIG = GAME_CONFIG;
    window.VEHICLES = VEHICLES;
    window.POWERUPS = POWERUPS;
    window.OBSTACLES = OBSTACLES;
}
