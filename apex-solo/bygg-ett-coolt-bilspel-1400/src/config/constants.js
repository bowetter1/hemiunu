/**
 * NEON TRAIL - Game Constants
 * All magic numbers and configuration values
 */

const GAME_CONFIG = {
    // Display
    WIDTH: 800,
    HEIGHT: 600,
    SCALE_MODE: Phaser.Scale.FIT,
    
    // Colors - Synthwave Palette
    COLORS: {
        // Primary neons
        CYAN: 0x00ffff,
        MAGENTA: 0xff00ff,
        YELLOW: 0xffff00,
        ORANGE: 0xff6600,
        
        // Backgrounds
        DARK_PURPLE: 0x1a0a2e,
        DARK_BLUE: 0x16213e,
        BLACK: 0x0a0a0f,
        
        // Road
        ROAD_DARK: 0x1a1a2e,
        ROAD_LIGHT: 0x2a2a4e,
        ROAD_LINE: 0x4a4a6e,
        
        // UI
        WHITE: 0xffffff,
        GRAY: 0x888888,
        
        // Trail colors (player specific)
        TRAIL_PLAYER: 0x00ffff,
        TRAIL_DANGER: 0xff0066,
        
        // Power-ups
        POWERUP_BOOST: 0xff6600,
        POWERUP_GHOST: 0x9966ff,
        POWERUP_SHRINK: 0x00ff66,
        POWERUP_SLOWMO: 0xffff00,
        POWERUP_SHIELD: 0x00ffff,
    },
    
    // Hex string versions for Phaser text
    HEX: {
        CYAN: '#00ffff',
        MAGENTA: '#ff00ff',
        YELLOW: '#ffff00',
        ORANGE: '#ff6600',
        WHITE: '#ffffff',
        GRAY: '#888888',
        DARK: '#0a0a0f',
    }
};

const PLAYER_CONFIG = {
    // Movement
    BASE_SPEED: 300,
    MAX_SPEED: 600,
    ACCELERATION: 15,
    DECELERATION: 10,
    
    // Steering
    TURN_SPEED: 4,
    DRIFT_MULTIPLIER: 1.5,
    DRIFT_THRESHOLD: 0.3,
    
    // Physics
    FRICTION: 0.98,
    BOUNCE: 0.3,
    
    // Dimensions
    WIDTH: 40,
    HEIGHT: 70,
    
    // Trail
    TRAIL_WIDTH: 20,
    TRAIL_FADE_TIME: 5000, // ms before trail segment fades
    TRAIL_SPAWN_RATE: 50,  // ms between trail segments
    
    // Collision
    HITBOX_PADDING: 5,
    INVINCIBILITY_TIME: 1000, // ms after power-up
};

const OBSTACLE_CONFIG = {
    // Types
    TYPES: {
        BARRIER: 'barrier',
        CONE: 'cone',
        OIL: 'oil',
        WALL: 'wall',
        MOVING: 'moving',
    },
    
    // Spawn
    MIN_SPAWN_DISTANCE: 400,
    MAX_SPAWN_DISTANCE: 800,
    SPAWN_VARIETY: 3, // max obstacles per spawn event
    
    // Movement
    MOVING_SPEED_MIN: 50,
    MOVING_SPEED_MAX: 150,
    
    // Sizes
    BARRIER_WIDTH: 80,
    BARRIER_HEIGHT: 30,
    CONE_SIZE: 30,
    OIL_SIZE: 60,
};

const POWERUP_CONFIG = {
    // Types and effects
    TYPES: {
        BOOST: {
            name: 'BOOST',
            color: 0xff6600,
            duration: 3000,
            effect: 'speed_boost',
            multiplier: 1.5,
        },
        GHOST: {
            name: 'GHOST',
            color: 0x9966ff,
            duration: 4000,
            effect: 'phase_through_trail',
        },
        SHRINK: {
            name: 'SHRINK',
            color: 0x00ff66,
            duration: 5000,
            effect: 'smaller_trail',
            multiplier: 0.5,
        },
        SLOWMO: {
            name: 'SLOW-MO',
            color: 0xffff00,
            duration: 3000,
            effect: 'slow_time',
            multiplier: 0.5,
        },
        SHIELD: {
            name: 'SHIELD',
            color: 0x00ffff,
            duration: 5000,
            effect: 'invincibility',
        },
    },
    
    // Spawn
    SPAWN_CHANCE: 0.02, // per frame
    MIN_SPAWN_INTERVAL: 5000,
    SIZE: 40,
    FLOAT_AMPLITUDE: 10,
    FLOAT_SPEED: 2,
};

const ROAD_CONFIG = {
    // Dimensions
    WIDTH: 500,
    LANE_COUNT: 5,
    SEGMENT_HEIGHT: 100,
    
    // Scrolling
    BASE_SCROLL_SPEED: 5,
    MAX_SCROLL_SPEED: 15,
    SPEED_INCREMENT: 0.001,
    
    // Visual
    LINE_WIDTH: 4,
    LINE_DASH: 40,
    LINE_GAP: 30,
    EDGE_WIDTH: 10,
    
    // Curves
    CURVE_FREQUENCY: 0.002,
    CURVE_AMPLITUDE: 100,
    MAX_CURVE: 150,
};

const SCORE_CONFIG = {
    // Points
    DISTANCE_MULTIPLIER: 1,
    DRIFT_BONUS: 10,
    NEAR_MISS_BONUS: 50,
    POWERUP_BONUS: 100,
    
    // Combo
    COMBO_TIMEOUT: 2000, // ms
    COMBO_MULTIPLIER_MAX: 10,
    
    // Highscore
    STORAGE_KEY: 'neontrail_highscore',
    LEADERBOARD_SIZE: 10,
};

const DIFFICULTY_CONFIG = {
    // Scaling
    BASE_DIFFICULTY: 1,
    MAX_DIFFICULTY: 10,
    DIFFICULTY_INCREMENT: 0.001,
    
    // Thresholds (by distance)
    EASY_THRESHOLD: 0,
    MEDIUM_THRESHOLD: 1000,
    HARD_THRESHOLD: 3000,
    INSANE_THRESHOLD: 5000,
    
    // Modifiers per difficulty level
    OBSTACLE_SPAWN_RATE: [0.01, 0.015, 0.02, 0.025, 0.03],
    TRAIL_FADE_SPEED: [1, 0.9, 0.8, 0.7, 0.6],
    ROAD_SPEED_MULTIPLIER: [1, 1.1, 1.2, 1.3, 1.5],
};

const AUDIO_CONFIG = {
    // Volume levels
    MASTER: 0.7,
    MUSIC: 0.5,
    SFX: 0.8,
    
    // Sound keys
    SOUNDS: {
        ENGINE: 'engine_loop',
        DRIFT: 'drift',
        COLLISION: 'collision',
        POWERUP: 'powerup',
        MENU_SELECT: 'menu_select',
        GAME_OVER: 'game_over',
        COUNTDOWN: 'countdown',
        NEAR_MISS: 'near_miss',
    },
    
    // Music keys
    MUSIC: {
        MENU: 'music_menu',
        GAME: 'music_game',
        GAMEOVER: 'music_gameover',
    }
};

const UI_CONFIG = {
    // Fonts
    FONT_FAMILY: 'Orbitron',
    FONT_SECONDARY: 'Rajdhani',
    
    // Sizes
    TITLE_SIZE: 72,
    HEADING_SIZE: 48,
    BODY_SIZE: 24,
    SMALL_SIZE: 16,
    
    // Animation
    TWEEN_DURATION: 300,
    FADE_DURATION: 500,
    
    // HUD
    HUD_PADDING: 20,
    HUD_HEIGHT: 60,
};

// Freeze all config objects to prevent accidental modification
Object.freeze(GAME_CONFIG);
Object.freeze(GAME_CONFIG.COLORS);
Object.freeze(GAME_CONFIG.HEX);
Object.freeze(PLAYER_CONFIG);
Object.freeze(OBSTACLE_CONFIG);
Object.freeze(POWERUP_CONFIG);
Object.freeze(ROAD_CONFIG);
Object.freeze(SCORE_CONFIG);
Object.freeze(DIFFICULTY_CONFIG);
Object.freeze(AUDIO_CONFIG);
Object.freeze(UI_CONFIG);
