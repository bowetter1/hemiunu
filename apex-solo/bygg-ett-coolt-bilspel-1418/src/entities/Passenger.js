/**
 * Passenger entity - visual representation of the passenger's emotional state
 */
import { COLORS, PASSENGER_STATES } from '../config/constants.js';

export class Passenger {
    constructor(scene) {
        this.scene = scene;
        this.container = scene.add.container(0, 0);
        this.container.setDepth(100);
        this.container.setVisible(false);
        
        // Passenger body (circle head)
        this.body = scene.add.graphics();
        this.drawBody(COLORS.CALM);
        
        // Face emoji
        this.face = scene.add.text(0, 0, '😊', {
            fontSize: '24px',
        }).setOrigin(0.5);
        
        // Speech bubble for extreme panic
        this.speechBubble = scene.add.container(25, -25);
        const bubbleBg = scene.add.graphics();
        bubbleBg.fillStyle(COLORS.WHITE);
        bubbleBg.fillRoundedRect(-20, -15, 40, 25, 8);
        this.speechText = scene.add.text(0, -3, '!', {
            fontSize: '16px',
            color: '#000',
            fontStyle: 'bold',
        }).setOrigin(0.5);
        this.speechBubble.add([bubbleBg, this.speechText]);
        this.speechBubble.setVisible(false);
        
        this.container.add([this.body, this.face, this.speechBubble]);
        
        // Animation state
        this.bounceOffset = 0;
        this.state = PASSENGER_STATES.CALM;
    }
    
    drawBody(color) {
        this.body.clear();
        this.body.fillStyle(color);
        this.body.fillCircle(0, 3, 16);
    }
    
    setState(state) {
        this.state = state;
        
        switch (state) {
            case PASSENGER_STATES.CALM:
                this.face.setText('😊');
                this.drawBody(COLORS.CALM);
                this.speechBubble.setVisible(false);
                break;
            case PASSENGER_STATES.WORRIED:
                this.face.setText('😰');
                this.drawBody(COLORS.WORRIED);
                this.speechBubble.setVisible(false);
                break;
            case PASSENGER_STATES.PANIC:
                this.face.setText('😱');
                this.drawBody(COLORS.PANIC);
                this.speechBubble.setVisible(true);
                this.speechText.setText(Phaser.Utils.Array.GetRandom(['!!', 'HELP', 'AAA', 'NO!']));
                break;
            case PASSENGER_STATES.BAILING:
                this.face.setText('🏃');
                this.drawBody(COLORS.DANGER);
                this.speechBubble.setVisible(true);
                this.speechText.setText('BYE!');
                break;
        }
    }
    
    setPosition(x, y) {
        this.container.setPosition(x, y + this.bounceOffset);
    }
    
    setVisible(visible) {
        this.container.setVisible(visible);
    }
    
    update(delta, panicLevel) {
        // Bounce animation based on panic
        const bounceSpeed = 0.01 + (panicLevel / 100) * 0.02;
        const bounceAmount = 2 + (panicLevel / 100) * 5;
        
        this.bounceOffset = Math.sin(Date.now() * bounceSpeed) * bounceAmount;
        
        // Shake when panicking
        if (this.state === PASSENGER_STATES.PANIC || this.state === PASSENGER_STATES.BAILING) {
            const shake = (Math.random() - 0.5) * 4;
            this.container.x += shake;
        }
        
        // Rotate face slightly when worried/panicking
        if (panicLevel > 40) {
            this.face.rotation = Math.sin(Date.now() * 0.015) * 0.2;
        } else {
            this.face.rotation = 0;
        }
    }
}
