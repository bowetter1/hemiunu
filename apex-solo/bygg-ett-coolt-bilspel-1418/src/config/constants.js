/**
 * Game constants and configuration
 * Colors from Pear36 palette (https://lospec.com/palette-list/pear36)
 */

export const COLORS = {
    // Background colors
    ROAD: 0x323e4f,
    GRASS: 0x3ca370,
    ROAD_LIGHT: 0x43434f,
    
    // Car colors
    CAR_BODY: 0xf2a65e,
    CAR_ACCENT: 0x5e315b,
    
    // Passenger states
    CALM: 0x3d6e70,
    WORRIED: 0xffb570,
    PANIC: 0xe36956,
    
    // UI
    TEXT: 0xffffeb,
    UI_ACCENT: 0xffe478,
    DANGER: 0xff6b97,
    
    // Misc
    WHITE: 0xffffeb,
    DARK: 0x272736,
};

export const GAME_CONFIG = {
    WIDTH: 800,
    HEIGHT: 600,
    
    // Physics
    CAR_MAX_SPEED: 300,
    CAR_ACCELERATION: 200,
    CAR_BRAKE_FORCE: 400,
    CAR_TURN_SPEED: 3,
    CAR_DRIFT_FACTOR: 0.92,  // Lower = more drift
    CAR_GRIP_FACTOR: 0.98,   // Higher = more grip
    
    // Panic system
    PANIC_DRIFT_RATE: 25,     // Panic per second while drifting
    PANIC_SPEED_RATE: 10,     // Panic per second at max speed
    PANIC_CALM_RATE: 15,      // Calm down per second when driving smoothly
    PANIC_MAX: 100,
    
    // Time
    DELIVERY_TIME: 60,        // Seconds per delivery
};

export const PASSENGER_STATES = {
    CALM: 'calm',
    WORRIED: 'worried',
    PANIC: 'panic',
    BAILING: 'bailing',
};
