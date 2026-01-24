/**
 * GRAVSHIFT - Level Definitions
 * Each level defines track layout, obstacles, and unique mechanics
 */

const LEVELS = {
    // ===== ZONE 1: INITIATION =====
    1: {
        id: 1,
        name: 'First Contact',
        zone: 'Initiation',
        description: 'Learn the basics of gravity-defying racing',
        difficulty: 1,
        unlocked: true,
        
        // Track configuration
        track: {
            length: 3000,
            width: 450,
            baseSpeed: 400,
            curves: 'gentle',
            rotations: [
                { position: 500, angle: 15, duration: 300 },
                { position: 1200, angle: -15, duration: 300 },
                { position: 2000, angle: 30, duration: 400 },
            ],
        },
        
        // Visual theme
        theme: {
            skyColor: 0x0a0a1a,
            roadColor: 0x1a1a3a,
            accentColor: 0x00ffff,
            fogDensity: 0.002,
            starDensity: 100,
        },
        
        // Obstacles and collectibles
        spawns: {
            obstacles: {
                types: ['BARRIER'],
                frequency: 0.01,
                maxActive: 3,
            },
            powerups: {
                types: ['BOOST'],
                frequency: 0.005,
            },
            scoreOrbs: {
                frequency: 0.02,
                value: 10,
            },
        },
        
        // Win conditions
        goals: {
            type: 'distance',
            target: 3000,
            timeLimit: null,
            laps: null,
        },
        
        // Stars requirements
        stars: {
            one: { score: 5000 },
            two: { score: 10000 },
            three: { score: 15000, noHits: true },
        },
    },
    
    2: {
        id: 2,
        name: 'Gravity Well',
        zone: 'Initiation',
        description: 'The track starts to twist...',
        difficulty: 2,
        unlocked: false,
        
        track: {
            length: 4000,
            width: 400,
            baseSpeed: 450,
            curves: 'moderate',
            rotations: [
                { position: 400, angle: 30, duration: 400 },
                { position: 1000, angle: -45, duration: 500 },
                { position: 1800, angle: 60, duration: 600 },
                { position: 2600, angle: -30, duration: 400 },
                { position: 3200, angle: 45, duration: 500 },
            ],
        },
        
        theme: {
            skyColor: 0x0a0a2a,
            roadColor: 0x1a1a4a,
            accentColor: 0x00ffff,
            fogDensity: 0.003,
            starDensity: 150,
        },
        
        spawns: {
            obstacles: {
                types: ['BARRIER', 'DEBRIS'],
                frequency: 0.015,
                maxActive: 5,
            },
            powerups: {
                types: ['BOOST', 'SHIELD'],
                frequency: 0.008,
            },
            scoreOrbs: {
                frequency: 0.025,
                value: 15,
            },
        },
        
        goals: {
            type: 'distance',
            target: 4000,
            timeLimit: 60000,
        },
        
        stars: {
            one: { score: 8000 },
            two: { score: 15000 },
            three: { score: 25000, noHits: true },
        },
    },
    
    // ===== ZONE 2: DISTORTION =====
    3: {
        id: 3,
        name: 'Möbius Strip',
        zone: 'Distortion',
        description: 'Where up becomes down and down becomes up',
        difficulty: 3,
        unlocked: false,
        
        track: {
            length: 5000,
            width: 380,
            baseSpeed: 500,
            curves: 'aggressive',
            rotations: [
                { position: 300, angle: 45, duration: 400 },
                { position: 800, angle: 90, duration: 600 },
                { position: 1500, angle: -90, duration: 600 },
                { position: 2200, angle: 180, duration: 800 },
                { position: 3000, angle: -45, duration: 400 },
                { position: 3800, angle: 90, duration: 600 },
            ],
        },
        
        theme: {
            skyColor: 0x1a0a2a,
            roadColor: 0x2a1a4a,
            accentColor: 0xff00ff,
            fogDensity: 0.004,
            starDensity: 200,
            nebula: true,
        },
        
        spawns: {
            obstacles: {
                types: ['BARRIER', 'SPIKE', 'DEBRIS'],
                frequency: 0.02,
                maxActive: 7,
            },
            powerups: {
                types: ['BOOST', 'SHIELD', 'SLOWMO'],
                frequency: 0.01,
            },
            scoreOrbs: {
                frequency: 0.03,
                value: 20,
            },
        },
        
        goals: {
            type: 'distance',
            target: 5000,
            timeLimit: 75000,
        },
        
        stars: {
            one: { score: 12000 },
            two: { score: 25000 },
            three: { score: 40000, time: 60000 },
        },
    },
    
    4: {
        id: 4,
        name: 'Spiral Descent',
        zone: 'Distortion',
        description: 'A continuous corkscrew into the void',
        difficulty: 4,
        unlocked: false,
        
        track: {
            length: 6000,
            width: 350,
            baseSpeed: 550,
            curves: 'extreme',
            spiralMode: true,
            spiralRate: 0.5,
            rotations: [
                { position: 0, angle: 0, continuous: true, rate: 30 },
            ],
        },
        
        theme: {
            skyColor: 0x0a1a2a,
            roadColor: 0x1a2a4a,
            accentColor: 0x00ffff,
            secondaryAccent: 0xff00ff,
            fogDensity: 0.005,
            starDensity: 250,
            spiralStars: true,
        },
        
        spawns: {
            obstacles: {
                types: ['BARRIER', 'SPIKE', 'LASER'],
                frequency: 0.025,
                maxActive: 8,
            },
            powerups: {
                types: ['BOOST', 'SHIELD', 'SLOWMO', 'GHOST'],
                frequency: 0.012,
            },
            scoreOrbs: {
                frequency: 0.035,
                value: 25,
            },
        },
        
        goals: {
            type: 'survival',
            target: 60000,
        },
        
        stars: {
            one: { score: 20000 },
            two: { score: 40000 },
            three: { score: 65000, noHits: true },
        },
    },
    
    // ===== ZONE 3: CHAOS =====
    5: {
        id: 5,
        name: 'Gravity Storm',
        zone: 'Chaos',
        description: 'Gravity fluctuates randomly. Good luck.',
        difficulty: 5,
        unlocked: true, // Made available for testing
        
        track: {
            length: 7000,
            width: 320,
            baseSpeed: 600,
            curves: 'chaotic',
            gravityFlux: true,
            rotations: [
                { position: 200, angle: 60, duration: 300 },
                { position: 600, angle: -120, duration: 500 },
                { position: 1200, angle: 180, duration: 600 },
                { position: 1800, angle: -90, duration: 400 },
                { position: 2500, angle: 270, duration: 700 },
                { position: 3200, angle: -180, duration: 600 },
                { position: 4000, angle: 90, duration: 400 },
                { position: 4800, angle: -270, duration: 700 },
            ],
        },
        
        theme: {
            skyColor: 0x2a0a1a,
            roadColor: 0x3a1a2a,
            accentColor: 0xff00ff,
            secondaryAccent: 0xffff00,
            fogDensity: 0.006,
            starDensity: 300,
            lightning: true,
        },
        
        spawns: {
            obstacles: {
                types: ['BARRIER', 'SPIKE', 'LASER', 'MOVING'],
                frequency: 0.03,
                maxActive: 10,
            },
            powerups: {
                types: ['BOOST', 'SHIELD', 'SLOWMO', 'GHOST', 'MAGNET'],
                frequency: 0.015,
            },
            scoreOrbs: {
                frequency: 0.04,
                value: 30,
            },
        },
        
        goals: {
            type: 'distance',
            target: 7000,
            timeLimit: 90000,
        },
        
        stars: {
            one: { score: 30000 },
            two: { score: 60000 },
            three: { score: 100000 },
        },
    },
    
    6: {
        id: 6,
        name: 'Event Horizon',
        zone: 'Chaos',
        description: 'The final frontier. No one has returned.',
        difficulty: 6,
        unlocked: false,
        
        track: {
            length: 10000,
            width: 300,
            baseSpeed: 700,
            curves: 'nightmare',
            gravityFlux: true,
            blackHole: true,
            rotations: 'dynamic',
        },
        
        theme: {
            skyColor: 0x000008,
            roadColor: 0x0a0a1a,
            accentColor: 0xffffff,
            secondaryAccent: 0xff0040,
            fogDensity: 0.008,
            starDensity: 400,
            blackHoleEffect: true,
            chromatic: true,
        },
        
        spawns: {
            obstacles: {
                types: ['BARRIER', 'SPIKE', 'LASER', 'MOVING'],
                frequency: 0.04,
                maxActive: 15,
                boss: 'VOID_SERPENT',
            },
            powerups: {
                types: ['BOOST', 'SHIELD', 'SLOWMO', 'GHOST', 'MAGNET'],
                frequency: 0.02,
            },
            scoreOrbs: {
                frequency: 0.05,
                value: 50,
            },
        },
        
        goals: {
            type: 'boss',
            target: 'VOID_SERPENT',
            healthPool: 10,
        },
        
        stars: {
            one: { score: 50000 },
            two: { score: 100000 },
            three: { score: 200000, perfectRun: true },
        },
    },
    
    // ===== ENDLESS MODE =====
    endless: {
        id: 'endless',
        name: 'Infinite Loop',
        zone: 'Beyond',
        description: 'How far can you go?',
        difficulty: 'dynamic',
        unlocked: false,
        
        track: {
            length: Infinity,
            width: 400,
            baseSpeed: 400,
            speedIncrease: 10,
            curves: 'procedural',
            rotations: 'procedural',
        },
        
        theme: {
            cycle: true,
            cycleSpeed: 30000,
            themes: ['initiation', 'distortion', 'chaos'],
        },
        
        spawns: {
            dynamic: true,
            difficultyScale: 0.001,
        },
        
        goals: {
            type: 'endless',
            milestones: [1000, 5000, 10000, 25000, 50000, 100000],
        },
    },
};

// Zone metadata
const ZONES = {
    initiation: {
        name: 'Initiation',
        description: 'Learn the basics',
        color: 0x00ffff,
        levels: [1, 2],
    },
    distortion: {
        name: 'Distortion',
        description: 'Reality bends',
        color: 0xff00ff,
        levels: [3, 4],
        // unlockRequirement: { zone: 'initiation', stars: 4 }, // Temporarily disabled for testing
    },
    chaos: {
        name: 'Chaos',
        description: 'All bets are off',
        color: 0xffff00,
        levels: [5, 6],
        // unlockRequirement: { zone: 'distortion', stars: 4 }, // Temporarily disabled for testing
    },
    beyond: {
        name: 'Beyond',
        description: '???',
        color: 0xffffff,
        levels: ['endless'],
        unlockRequirement: { zone: 'chaos', stars: 5 },
    },
};

// Export
if (typeof window !== 'undefined') {
    window.LEVELS = LEVELS;
    window.ZONES = ZONES;
}
