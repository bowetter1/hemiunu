/**
 * NEON TRAIL - Input Manager
 * Handles keyboard, touch, and gamepad input
 */

class InputManager {
    constructor(scene) {
        this.scene = scene;
        
        // Input state
        this.keys = {
            left: false,
            right: false,
            up: false,
            down: false,
            drift: false,
            pause: false,
            confirm: false,
        };
        
        // Previous state (for detecting key presses)
        this.prevKeys = { ...this.keys };
        
        // Touch state
        this.touchActive = false;
        this.touchX = 0;
        this.touchY = 0;
        this.touchStartX = 0;
        this.touchStartY = 0;
        
        // Keyboard cursors
        this.cursors = null;
        this.wasd = null;
        this.spaceKey = null;
        this.escKey = null;
        this.enterKey = null;
        
        // Touch zones (percentage of screen)
        this.touchZones = {
            leftThreshold: 0.4,
            rightThreshold: 0.6,
        };
        
        // Sensitivity
        this.touchSensitivity = 1.5;
        this.deadzone = 0.1;
        
        // Mobile detection
        this.isMobile = this.detectMobile();
    }
    
    /**
     * Initialize input handlers
     */
    create() {
        // Keyboard input
        this.cursors = this.scene.input.keyboard.createCursorKeys();
        this.wasd = this.scene.input.keyboard.addKeys({
            up: Phaser.Input.Keyboard.KeyCodes.W,
            down: Phaser.Input.Keyboard.KeyCodes.S,
            left: Phaser.Input.Keyboard.KeyCodes.A,
            right: Phaser.Input.Keyboard.KeyCodes.D,
        });
        this.spaceKey = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
        this.escKey = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC);
        this.enterKey = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ENTER);
        
        // Touch input
        this.scene.input.on('pointerdown', this.onPointerDown, this);
        this.scene.input.on('pointermove', this.onPointerMove, this);
        this.scene.input.on('pointerup', this.onPointerUp, this);
        
        // Prevent context menu on right click
        this.scene.input.mouse.disableContextMenu();
        
        return this;
    }
    
    /**
     * Update input state
     */
    update() {
        // Store previous state
        this.prevKeys = { ...this.keys };
        
        // Reset keys
        this.keys.left = false;
        this.keys.right = false;
        this.keys.up = false;
        this.keys.down = false;
        this.keys.drift = false;
        this.keys.pause = false;
        this.keys.confirm = false;
        
        // Keyboard input
        if (this.cursors) {
            this.keys.left = this.cursors.left.isDown || this.wasd.left.isDown;
            this.keys.right = this.cursors.right.isDown || this.wasd.right.isDown;
            this.keys.up = this.cursors.up.isDown || this.wasd.up.isDown;
            this.keys.down = this.cursors.down.isDown || this.wasd.down.isDown;
        }
        
        if (this.spaceKey) {
            this.keys.drift = this.spaceKey.isDown;
            this.keys.confirm = this.spaceKey.isDown;
        }
        
        if (this.escKey) {
            this.keys.pause = this.escKey.isDown;
        }
        
        if (this.enterKey) {
            this.keys.confirm = this.keys.confirm || this.enterKey.isDown;
        }
        
        // Touch input
        if (this.touchActive) {
            this.processTouchInput();
        }
    }
    
    /**
     * Process touch input into directional keys
     */
    processTouchInput() {
        const screenWidth = GAME_CONFIG.WIDTH;
        const screenHeight = GAME_CONFIG.HEIGHT;
        
        // Horizontal movement based on touch position
        const normalizedX = this.touchX / screenWidth;
        
        if (normalizedX < this.touchZones.leftThreshold) {
            this.keys.left = true;
        } else if (normalizedX > this.touchZones.rightThreshold) {
            this.keys.right = true;
        }
        
        // Vertical input based on touch Y (optional - for menus)
        const normalizedY = this.touchY / screenHeight;
        
        if (normalizedY < 0.3) {
            this.keys.up = true;
        } else if (normalizedY > 0.7) {
            this.keys.down = true;
        }
        
        // Drift by holding anywhere (after initial movement)
        const dx = this.touchX - this.touchStartX;
        if (Math.abs(dx) > 50) {
            this.keys.drift = true;
        }
    }
    
    /**
     * Touch start handler
     */
    onPointerDown(pointer) {
        this.touchActive = true;
        this.touchX = pointer.x;
        this.touchY = pointer.y;
        this.touchStartX = pointer.x;
        this.touchStartY = pointer.y;
    }
    
    /**
     * Touch move handler
     */
    onPointerMove(pointer) {
        if (pointer.isDown) {
            this.touchX = pointer.x;
            this.touchY = pointer.y;
        }
    }
    
    /**
     * Touch end handler
     */
    onPointerUp(pointer) {
        this.touchActive = false;
        this.keys.confirm = true; // Tap acts as confirm
    }
    
    /**
     * Get horizontal input (-1 to 1)
     */
    getHorizontal() {
        if (this.touchActive) {
            const screenWidth = GAME_CONFIG.WIDTH;
            const normalizedX = (this.touchX / screenWidth) * 2 - 1;
            
            // Apply deadzone
            if (Math.abs(normalizedX) < this.deadzone) {
                return 0;
            }
            
            return Phaser.Math.Clamp(normalizedX * this.touchSensitivity, -1, 1);
        }
        
        let horizontal = 0;
        if (this.keys.left) horizontal -= 1;
        if (this.keys.right) horizontal += 1;
        
        return horizontal;
    }
    
    /**
     * Get vertical input (-1 to 1)
     */
    getVertical() {
        let vertical = 0;
        if (this.keys.up) vertical -= 1;
        if (this.keys.down) vertical += 1;
        
        return vertical;
    }
    
    /**
     * Check if a key was just pressed this frame
     */
    justPressed(key) {
        return this.keys[key] && !this.prevKeys[key];
    }
    
    /**
     * Check if a key was just released this frame
     */
    justReleased(key) {
        return !this.keys[key] && this.prevKeys[key];
    }
    
    /**
     * Check if drift is active
     */
    isDrifting() {
        return this.keys.drift || (this.touchActive && Math.abs(this.touchX - this.touchStartX) > 50);
    }
    
    /**
     * Check if pause was pressed
     */
    isPausePressed() {
        return this.justPressed('pause');
    }
    
    /**
     * Check if confirm was pressed
     */
    isConfirmPressed() {
        return this.justPressed('confirm');
    }
    
    /**
     * Check if any input is active
     */
    isAnyInput() {
        return this.keys.left || this.keys.right || this.keys.up || this.keys.down ||
               this.keys.drift || this.touchActive;
    }
    
    /**
     * Detect mobile device
     */
    detectMobile() {
        return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    }
    
    /**
     * Check if on mobile
     */
    isMobileDevice() {
        return this.isMobile;
    }
    
    /**
     * Cleanup
     */
    destroy() {
        this.scene.input.off('pointerdown', this.onPointerDown, this);
        this.scene.input.off('pointermove', this.onPointerMove, this);
        this.scene.input.off('pointerup', this.onPointerUp, this);
        
        this.cursors = null;
        this.wasd = null;
        this.spaceKey = null;
        this.escKey = null;
        this.enterKey = null;
    }
}
