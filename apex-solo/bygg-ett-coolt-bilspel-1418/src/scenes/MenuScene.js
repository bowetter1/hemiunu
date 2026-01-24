/**
 * Menu Scene - Title screen with play button
 */
import { COLORS, GAME_CONFIG } from '../config/constants.js';

export class MenuScene extends Phaser.Scene {
    constructor() {
        super({ key: 'MenuScene' });
    }
    
    create() {
        // Background
        this.add.rectangle(
            GAME_CONFIG.WIDTH / 2, 
            GAME_CONFIG.HEIGHT / 2, 
            GAME_CONFIG.WIDTH, 
            GAME_CONFIG.HEIGHT, 
            COLORS.GRASS
        );
        
        // Road stripe decoration
        const g = this.add.graphics();
        g.fillStyle(COLORS.ROAD);
        g.fillRect(0, GAME_CONFIG.HEIGHT / 2 - 40, GAME_CONFIG.WIDTH, 80);
        
        // Road markings
        g.fillStyle(COLORS.UI_ACCENT);
        for (let x = 0; x < GAME_CONFIG.WIDTH; x += 50) {
            g.fillRect(x, GAME_CONFIG.HEIGHT / 2 - 3, 30, 6);
        }
        
        // Title
        this.add.text(GAME_CONFIG.WIDTH / 2, 120, 'CARGO', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '72px',
            color: '#' + COLORS.CAR_BODY.toString(16).padStart(6, '0'),
            stroke: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
            strokeThickness: 8,
        }).setOrigin(0.5);
        
        this.add.text(GAME_CONFIG.WIDTH / 2, 190, 'PANIC', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '72px',
            color: '#' + COLORS.DANGER.toString(16).padStart(6, '0'),
            stroke: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
            strokeThickness: 8,
        }).setOrigin(0.5);
        
        // Subtitle
        this.add.text(GAME_CONFIG.WIDTH / 2, 250, 'Your passengers HATE your driving!', {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        // Draw a little taxi
        this.drawTaxiDecoration();
        
        // Play button
        const playBtn = this.add.container(GAME_CONFIG.WIDTH / 2, 420);
        
        const btnBg = this.add.graphics();
        btnBg.fillStyle(COLORS.CAR_BODY);
        btnBg.fillRoundedRect(-100, -30, 200, 60, 12);
        btnBg.lineStyle(4, COLORS.DARK);
        btnBg.strokeRoundedRect(-100, -30, 200, 60, 12);
        
        const btnText = this.add.text(0, 0, 'START SHIFT', {
            fontFamily: 'Arial Black, Arial',
            fontSize: '24px',
            color: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        playBtn.add([btnBg, btnText]);
        playBtn.setSize(200, 60);
        playBtn.setInteractive({ useHandCursor: true });
        
        // Button hover effects
        playBtn.on('pointerover', () => {
            playBtn.setScale(1.05);
        });
        
        playBtn.on('pointerout', () => {
            playBtn.setScale(1);
        });
        
        playBtn.on('pointerdown', () => {
            this.scene.start('GameScene');
        });
        
        // Instructions
        this.add.text(GAME_CONFIG.WIDTH / 2, 520, 'HOW TO PLAY:', {
            fontFamily: 'Arial',
            fontSize: '18px',
            fontStyle: 'bold',
            color: '#' + COLORS.UI_ACCENT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        this.add.text(GAME_CONFIG.WIDTH / 2, 550, '🚗 ARROW KEYS or WASD to drive', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        this.add.text(GAME_CONFIG.WIDTH / 2, 575, '😱 Drifting scares passengers! Keep them calm!', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        // Keyboard shortcut
        this.input.keyboard.on('keydown-SPACE', () => {
            this.scene.start('GameScene');
        });
        this.input.keyboard.on('keydown-ENTER', () => {
            this.scene.start('GameScene');
        });
    }
    
    drawTaxiDecoration() {
        const g = this.add.graphics();
        const x = GAME_CONFIG.WIDTH / 2;
        const y = GAME_CONFIG.HEIGHT / 2;
        
        // Simple taxi icon
        g.fillStyle(COLORS.CAR_BODY);
        g.fillRoundedRect(x - 35, y - 20, 70, 40, 8);
        
        g.fillStyle(COLORS.CAR_ACCENT);
        g.fillRoundedRect(x - 20, y - 14, 40, 28, 4);
        
        g.fillStyle(COLORS.CALM);
        g.fillRect(x + 18, y - 10, 12, 20);
        g.fillRect(x - 30, y - 8, 8, 16);
        
        g.fillStyle(COLORS.DARK);
        g.fillRect(x - 28, y - 24, 14, 6);
        g.fillRect(x - 28, y + 18, 14, 6);
        g.fillRect(x + 14, y - 24, 14, 6);
        g.fillRect(x + 14, y + 18, 14, 6);
        
        g.fillStyle(COLORS.UI_ACCENT);
        g.fillRect(x - 8, y - 8, 16, 16);
        
        // Speed lines
        g.lineStyle(3, COLORS.TEXT, 0.5);
        g.lineBetween(x - 60, y - 10, x - 80, y - 10);
        g.lineBetween(x - 55, y, x - 85, y);
        g.lineBetween(x - 60, y + 10, x - 80, y + 10);
    }
}
