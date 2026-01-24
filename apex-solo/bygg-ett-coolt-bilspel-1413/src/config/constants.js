/**
 * Neon Drift - Game Constants
 * Color palette based on SLSO8 by Luis Miguel Maldonado
 */

const COLORS = {
    // Background & environment
    BACKGROUND: 0x0d2b45,      // Deep night blue
    ROAD: 0x203c56,            // Dark blue-gray
    ROAD_EDGE: 0x544e68,       // Muted purple
    
    // Car & trails
    CAR: 0xffaa5e,             // Bright orange
    TRAIL_PRIMARY: 0xd08159,   // Hot orange
    TRAIL_GLOW: 0xffd4a3,      // Warm peach
    TRAIL_FADE: 0x8d697a,      // Dusty rose
    
    // UI
    UI_TEXT: 0xffecd6,         // Cream white
    UI_ACCENT: 0xffaa5e,       // Bright orange
    UI_DARK: 0x0d2b45,         // Deep blue
    
    // Obstacles
    OBSTACLE: 0x544e68,        // Muted purple
    DANGER: 0x8d697a,          // Dusty rose
};

const GAME = {
    WIDTH: 800,
    HEIGHT: 600,
    
    // Car physics
    CAR_ACCELERATION: 200,
    CAR_MAX_SPEED: 350,
    CAR_FRICTION: 0.98,
    CAR_TURN_SPEED: 3.5,
    CAR_DRIFT_FACTOR: 0.92,    // How much the car slides (lower = more drift)
    CAR_GRIP: 0.15,            // How quickly car aligns to velocity
    
    // Trail settings
    TRAIL_SPAWN_RATE: 30,      // ms between trail points
    TRAIL_LIFETIME: 8000,      // How long trails persist (ms)
    TRAIL_MIN_SPEED: 80,       // Minimum speed to leave trail
    TRAIL_DRIFT_THRESHOLD: 0.3, // How much drift angle to count as drifting
    
    // Scoring
    SCORE_PER_TRAIL: 1,        // Points per trail segment
    SCORE_DRIFT_BONUS: 5,      // Bonus for drifting
    SCORE_NEAR_MISS: 50,       // Points for near-miss
    NEAR_MISS_DISTANCE: 60,    // Pixels for near-miss detection
    
    // Obstacles
    OBSTACLE_SPAWN_RATE: 2000, // ms between obstacles
    OBSTACLE_SPEED: 150,       // How fast obstacles move down
    OBSTACLE_SIZE: 40,
    
    // Road
    ROAD_WIDTH: 500,
    ROAD_SCROLL_SPEED: 200,
};
