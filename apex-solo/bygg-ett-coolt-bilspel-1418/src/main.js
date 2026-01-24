/**
 * Cargo Panic - Main entry point
 * A taxi game where passengers freak out when you drift!
 */
import { COLORS, GAME_CONFIG } from './config/constants.js';
import { MenuScene } from './scenes/MenuScene.js';
import { GameScene } from './scenes/GameScene.js';
import { GameOverScene } from './scenes/GameOverScene.js';

const config = {
    type: Phaser.AUTO,
    width: GAME_CONFIG.WIDTH,
    height: GAME_CONFIG.HEIGHT,
    parent: 'game-container',
    backgroundColor: COLORS.DARK,
    scene: [MenuScene, GameScene, GameOverScene],
    render: {
        pixelArt: false,
        antialias: true,
    }
};

// Create game instance
const game = new Phaser.Game(config);

console.log('🚕 Cargo Panic loaded! Drive carefully... or not.');
