/**
 * GRAVSHIFT - Main Game Entry Point
 * Racing where gravity is just a suggestion
 * 
 * A complete pseudo-3D racing game with:
 * - 6 unique levels + endless mode
 * - Dynamic track rotation (gravity manipulation)
 * - Power-ups and obstacles
 * - Combo system and scoring
 * - Procedural audio
 * - Full game flow (menu, gameplay, pause, game over, victory)
 */

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
    initGame();
});

/**
 * Initialize the Phaser game
 */
function initGame() {
    console.log('Initializing GRAVSHIFT game...');

    // Phaser configuration
    const config = {
        type: Phaser.AUTO,
        parent: 'game-container',
        width: GAME_CONFIG.WIDTH,
        height: GAME_CONFIG.HEIGHT,
        backgroundColor: GAME_CONFIG.COLORS.BACKGROUND,
        
        // Scaling
        scale: {
            mode: Phaser.Scale.FIT,
            autoCenter: Phaser.Scale.CENTER_BOTH,
            min: {
                width: 640,
                height: 360,
            },
            max: {
                width: 1920,
                height: 1080,
            },
        },
        
        // Physics (not using Arcade for this pseudo-3D game, but available if needed)
        physics: {
            default: 'arcade',
            arcade: {
                gravity: { y: 0 },
                debug: false,
            },
        },
        
        // Input
        input: {
            keyboard: true,
            mouse: true,
            touch: true,
            gamepad: true,
        },
        
        // Audio
        audio: {
            disableWebAudio: false,
        },
        
        // Rendering
        render: {
            pixelArt: false,
            antialias: true,
            roundPixels: false,
        },
        
        // All game scenes
        scene: [
            BootScene,
            PreloadScene,
            MenuScene,
            TutorialScene,
            LevelSelectScene,
            GameScene,
            PauseScene,
            GameOverScene,
            VictoryScene,
            SettingsScene,
            CreditsScene,
        ],
    };
    
    // Create Phaser game instance
    console.log('Creating Phaser game instance...');
    const game = new Phaser.Game(config);
    console.log('Phaser game created successfully');

    // Store game reference globally for debugging
    window.game = game;
    
    // Handle window resize
    window.addEventListener('resize', () => {
        game.scale.refresh();
    });
    
    // Handle fullscreen toggle with F key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'f' || e.key === 'F') {
            if (document.fullscreenElement) {
                document.exitFullscreen();
            } else {
                document.documentElement.requestFullscreen();
            }
        }
    });
    
    // Prevent context menu on right click
    document.addEventListener('contextmenu', (e) => {
        e.preventDefault();
    });
    
    // Log game info
    console.log('%c GRAVSHIFT ', 'background: #00ffff; color: #0a0a0f; font-size: 24px; font-weight: bold;');
    console.log('%c Gravity Is Just A Suggestion ', 'background: #0a0a0f; color: #00ffff; font-size: 12px;');
    console.log('');
    console.log('Controls:');
    console.log('  ← → or A D : Steer');
    console.log('  SPACE/SHIFT : Boost');
    console.log('  ESC/P       : Pause');
    console.log('  F           : Fullscreen');
    console.log('');
    
    return game;
}

/**
 * Debug utilities (available in console)
 */
window.GRAVSHIFT = {
    // Unlock all levels
    unlockAll: () => {
        const levelManager = new LevelManager(null);
        levelManager.unlockAll();
        console.log('All levels unlocked!');
    },
    
    // Reset progress
    resetProgress: () => {
        localStorage.removeItem(GAME_CONFIG.STORAGE.HIGHSCORE);
        localStorage.removeItem(GAME_CONFIG.STORAGE.SETTINGS);
        localStorage.removeItem(GAME_CONFIG.STORAGE.UNLOCKED_LEVELS);
        localStorage.removeItem(GAME_CONFIG.STORAGE.BEST_TIMES);
        localStorage.removeItem('gravshift_stars');
        console.log('Progress reset!');
    },
    
    // Show game stats
    stats: () => {
        const levelManager = new LevelManager(null);
        console.log('Total Stars:', levelManager.getTotalStars());
        console.log('Unlocked Levels:', Object.keys(levelManager.unlockedLevels).length);
        console.log('Best Times:', levelManager.bestTimes);
    },
    
    // Jump to specific level
    goToLevel: (levelId) => {
        if (window.game && window.game.scene) {
            window.game.scene.start('GameScene', { levelId });
        }
    },

    // Go to level select
    goToLevelSelect: () => {
        if (window.game && window.game.scene) {
            window.game.scene.start('LevelSelectScene');
        }
    },
    
    // Toggle debug mode
    debug: false,
    toggleDebug: () => {
        window.GRAVSHIFT.debug = !window.GRAVSHIFT.debug;
        console.log('Debug mode:', window.GRAVSHIFT.debug ? 'ON' : 'OFF');
    },
};

// Export init function
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { initGame };
}
