/**
 * GRAVSHIFT - Button Component
 * Reusable UI button with neon styling
 */

class Button {
    constructor(scene, x, y, text, config = {}) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.text = text;
        
        // Configuration
        this.width = config.width || 200;
        this.height = config.height || 50;
        this.color = config.color || GAME_CONFIG.COLORS.UI_PRIMARY;
        this.textColor = config.textColor || '#ffffff';
        this.fontSize = config.fontSize || '20px';
        this.fontFamily = config.fontFamily || 'Orbitron, sans-serif';
        this.disabled = config.disabled || false;
        
        // State
        this.isHovered = false;
        this.isPressed = false;
        this.visible = true;
        
        // Callbacks
        this.onClick = config.onClick || null;
        this.onHover = config.onHover || null;
        
        // Create elements
        this.create();
    }
    
    create() {
        // Background graphics
        this.background = this.scene.add.graphics();
        this.drawBackground();
        
        // Text
        this.textObject = this.scene.add.text(this.x, this.y, this.text, {
            fontFamily: this.fontFamily,
            fontSize: this.fontSize,
            color: this.textColor,
            align: 'center',
        }).setOrigin(0.5);
        
        // Interactive zone
        this.hitArea = this.scene.add.rectangle(
            this.x, this.y, this.width, this.height
        ).setInteractive({ useHandCursor: !this.disabled });
        
        this.hitArea.setAlpha(0.01); // Nearly invisible but interactive
        
        // Events
        this.setupEvents();
    }
    
    setupEvents() {
        this.hitArea.on('pointerover', () => {
            if (!this.disabled) {
                this.isHovered = true;
                this.drawBackground();
                if (this.onHover) this.onHover();
            }
        });
        
        this.hitArea.on('pointerout', () => {
            this.isHovered = false;
            this.isPressed = false;
            this.drawBackground();
        });
        
        this.hitArea.on('pointerdown', () => {
            if (!this.disabled) {
                this.isPressed = true;
                this.drawBackground();
            }
        });
        
        this.hitArea.on('pointerup', () => {
            if (!this.disabled && this.isPressed) {
                this.isPressed = false;
                this.drawBackground();
                if (this.onClick) this.onClick();
            }
        });
    }
    
    drawBackground() {
        this.background.clear();
        
        const x = this.x - this.width / 2;
        const y = this.y - this.height / 2;
        
        if (this.disabled) {
            // Disabled state
            this.background.fillStyle(0x333333, 0.5);
            this.background.fillRoundedRect(x, y, this.width, this.height, 8);
            this.background.lineStyle(2, 0x444444, 0.5);
            this.background.strokeRoundedRect(x, y, this.width, this.height, 8);
            this.textObject.setColor('#666666');
        } else if (this.isPressed) {
            // Pressed state
            this.background.fillStyle(this.color, 0.4);
            this.background.fillRoundedRect(x, y, this.width, this.height, 8);
            this.background.lineStyle(2, this.color, 1);
            this.background.strokeRoundedRect(x, y, this.width, this.height, 8);
            this.textObject.setColor(ColorUtils.hexToCss(this.color));
        } else if (this.isHovered) {
            // Hover state
            this.background.fillStyle(this.color, 0.2);
            this.background.fillRoundedRect(x, y, this.width, this.height, 8);
            this.background.lineStyle(2, this.color, 1);
            this.background.strokeRoundedRect(x, y, this.width, this.height, 8);
            
            // Glow effect
            this.background.lineStyle(4, this.color, 0.3);
            this.background.strokeRoundedRect(x - 2, y - 2, this.width + 4, this.height + 4, 10);
            
            this.textObject.setColor(ColorUtils.hexToCss(this.color));
        } else {
            // Normal state
            this.background.fillStyle(0x1a1a2e, 0.8);
            this.background.fillRoundedRect(x, y, this.width, this.height, 8);
            this.background.lineStyle(2, this.color, 0.5);
            this.background.strokeRoundedRect(x, y, this.width, this.height, 8);
            this.textObject.setColor(this.textColor);
        }
    }
    
    setText(text) {
        this.text = text;
        this.textObject.setText(text);
    }
    
    setDisabled(disabled) {
        this.disabled = disabled;
        this.hitArea.setInteractive({ useHandCursor: !disabled });
        this.drawBackground();
    }
    
    setVisible(visible) {
        this.visible = visible;
        this.background.setVisible(visible);
        this.textObject.setVisible(visible);
        this.hitArea.setVisible(visible);
    }
    
    setPosition(x, y) {
        this.x = x;
        this.y = y;
        this.textObject.setPosition(x, y);
        this.hitArea.setPosition(x, y);
        this.drawBackground();
    }
    
    setDepth(depth) {
        this.background.setDepth(depth);
        this.textObject.setDepth(depth + 1);
        this.hitArea.setDepth(depth + 2);
    }
    
    destroy() {
        this.background.destroy();
        this.textObject.destroy();
        this.hitArea.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Button = Button;
}
