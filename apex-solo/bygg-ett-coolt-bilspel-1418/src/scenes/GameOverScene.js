/**
 * Game Over Scene - Shows results and allows restart
 */
import { COLORS, GAME_CONFIG } from '../config/constants.js';

export class GameOverScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GameOverScene' });
    }
    
    init(data) {
        this.finalScore = data.score || 0;
        this.deliveries = data.deliveries || 0;
        this.reason = data.reason || 'passenger_bailed';
    }
    
    create() {
        // Background
        this.add.rectangle(
            GAME_CONFIG.WIDTH / 2, 
            GAME_CONFIG.HEIGHT / 2, 
            GAME_CONFIG.WIDTH, 
            GAME_CONFIG.HEIGHT, 
            COLORS.DARK
        );
        
        // Different messages based on reason
        let titleText = 'SHIFT OVER';
        let titleColor = COLORS.UI_ACCENT;
        let messageText = '';
        
        if (this.reason === 'passenger_bailed') {
            titleText = 'PASSENGER BAILED!';
            titleColor = COLORS.DANGER;
            messageText = 'Your driving was too terrifying!';
        } else if (this.reason === 'time_up') {
            titleText = 'TIME\'S UP!';
            titleColor = COLORS.WORRIED;
            messageText = 'The shift is over.';
        } else if (this.reason === 'completed') {
            titleText = 'SHIFT COMPLETE!';
            titleColor = COLORS.CALM;
            messageText = 'Great work, driver!';
        }
        
        // Title
        this.add.text(GAME_CONFIG.WIDTH / 2, 100, titleText, {
            fontFamily: 'Arial Black, Arial',
            fontSize: '48px',
            color: '#' + titleColor.toString(16).padStart(6, '0'),
            stroke: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
            strokeThickness: 6,
        }).setOrigin(0.5);
        
        // Message
        this.add.text(GAME_CONFIG.WIDTH / 2, 160, messageText, {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        // Stats box
        const statsBox = this.add.graphics();
        statsBox.fillStyle(COLORS.ROAD, 0.8);
        statsBox.fillRoundedRect(GAME_CONFIG.WIDTH / 2 - 150, 200, 300, 150, 12);
        
        // Stats
        this.add.text(GAME_CONFIG.WIDTH / 2, 230, 'FINAL SCORE', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#' + COLORS.UI_ACCENT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        this.add.text(GAME_CONFIG.WIDTH / 2, 270, `${this.finalScore}`, {
            fontFamily: 'Arial Black, Arial',
            fontSize: '48px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        this.add.text(GAME_CONFIG.WIDTH / 2, 320, `Deliveries: ${this.deliveries}`, {
            fontFamily: 'Arial',
            fontSize: '18px',
            color: '#' + COLORS.TEXT.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        // Buttons
        this.createButton(GAME_CONFIG.WIDTH / 2, 420, 'TRY AGAIN', () => {
            this.scene.start('GameScene');
        });
        
        this.createButton(GAME_CONFIG.WIDTH / 2, 500, 'MAIN MENU', () => {
            this.scene.start('MenuScene');
        }, COLORS.ROAD_LIGHT);
        
        // Keyboard shortcuts
        this.input.keyboard.on('keydown-SPACE', () => {
            this.scene.start('GameScene');
        });
        this.input.keyboard.on('keydown-ENTER', () => {
            this.scene.start('GameScene');
        });
        this.input.keyboard.on('keydown-ESC', () => {
            this.scene.start('MenuScene');
        });
    }
    
    createButton(x, y, text, callback, bgColor = COLORS.CAR_BODY) {
        const btn = this.add.container(x, y);
        
        const bg = this.add.graphics();
        bg.fillStyle(bgColor);
        bg.fillRoundedRect(-100, -25, 200, 50, 10);
        bg.lineStyle(3, COLORS.DARK);
        bg.strokeRoundedRect(-100, -25, 200, 50, 10);
        
        const label = this.add.text(0, 0, text, {
            fontFamily: 'Arial Black, Arial',
            fontSize: '20px',
            color: '#' + COLORS.DARK.toString(16).padStart(6, '0'),
        }).setOrigin(0.5);
        
        btn.add([bg, label]);
        btn.setSize(200, 50);
        btn.setInteractive({ useHandCursor: true });
        
        btn.on('pointerover', () => btn.setScale(1.05));
        btn.on('pointerout', () => btn.setScale(1));
        btn.on('pointerdown', callback);
        
        return btn;
    }
}
