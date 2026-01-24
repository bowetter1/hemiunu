/**
 * GRAVSHIFT - Input Manager
 * Handles keyboard, gamepad, and touch controls
 */

class InputManager {
    constructor(scene) {
        this.scene = scene;
        this.keys = {};
        this.gamepad = null;
        this.touch = {
            active: false,
            startX: 0,
            startY: 0,
            currentX: 0,
            currentY: 0,
            deltaX: 0,
            deltaY: 0,
        };
        
        // Input state
        this.state = {
            left: false,
            right: false,
            up: false,
            down: false,
            boost: false,
            brake: false,
            pause: false,
            confirm: false,
            cancel: false,
        };
        
        this.previousState = { ...this.state };
        this.deadzone = 0.2;
        
        this.setupKeyboard();
        this.setupTouch();
        this.setupGamepad();
    }
    
    /**
     * Setup keyboard input
     */
    setupKeyboard() {
        if (!this.scene.input || !this.scene.input.keyboard) return;
        
        // Movement keys
        this.keys.left = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.LEFT);
        this.keys.right = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.RIGHT);
        this.keys.up = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.UP);
        this.keys.down = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.DOWN);
        
        // WASD alternative
        this.keys.a = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.A);
        this.keys.d = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.D);
        this.keys.w = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.W);
        this.keys.s = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.S);
        
        // Action keys
        this.keys.space = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);
        this.keys.shift = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SHIFT);
        this.keys.enter = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ENTER);
        this.keys.esc = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.ESC);
        this.keys.p = this.scene.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.P);
    }
    
    /**
     * Setup touch input
     */
    setupTouch() {
        if (!this.scene.input) return;
        
        this.scene.input.on('pointerdown', (pointer) => {
            this.touch.active = true;
            this.touch.startX = pointer.x;
            this.touch.startY = pointer.y;
            this.touch.currentX = pointer.x;
            this.touch.currentY = pointer.y;
        });
        
        this.scene.input.on('pointermove', (pointer) => {
            if (this.touch.active) {
                this.touch.currentX = pointer.x;
                this.touch.currentY = pointer.y;
                this.touch.deltaX = this.touch.currentX - this.touch.startX;
                this.touch.deltaY = this.touch.currentY - this.touch.startY;
            }
        });
        
        this.scene.input.on('pointerup', () => {
            this.touch.active = false;
            this.touch.deltaX = 0;
            this.touch.deltaY = 0;
        });
    }
    
    /**
     * Setup gamepad input
     */
    setupGamepad() {
        if (!this.scene.input || !this.scene.input.gamepad) return;
        
        this.scene.input.gamepad.on('connected', (pad) => {
            this.gamepad = pad;
            console.log('Gamepad connected:', pad.id);
        });
        
        this.scene.input.gamepad.on('disconnected', (pad) => {
            if (this.gamepad === pad) {
                this.gamepad = null;
            }
        });
        
        // Check for already connected gamepads
        if (this.scene.input.gamepad.total > 0) {
            this.gamepad = this.scene.input.gamepad.getPad(0);
        }
    }
    
    /**
     * Update input state
     */
    update() {
        // Store previous state
        this.previousState = { ...this.state };
        
        // Reset state
        Object.keys(this.state).forEach(key => {
            this.state[key] = false;
        });
        
        // Process keyboard
        this.processKeyboard();
        
        // Process gamepad
        this.processGamepad();
        
        // Process touch
        this.processTouch();
    }
    
    /**
     * Process keyboard input
     */
    processKeyboard() {
        if (!this.keys.left) return;
        
        // Movement
        this.state.left = this.keys.left.isDown || this.keys.a.isDown;
        this.state.right = this.keys.right.isDown || this.keys.d.isDown;
        this.state.up = this.keys.up.isDown || this.keys.w.isDown;
        this.state.down = this.keys.down.isDown || this.keys.s.isDown;
        
        // Actions
        this.state.boost = this.keys.space.isDown || this.keys.shift.isDown;
        this.state.brake = this.keys.down.isDown || this.keys.s.isDown;
        this.state.pause = this.keys.esc.isDown || this.keys.p.isDown;
        this.state.confirm = this.keys.enter.isDown || this.keys.space.isDown;
        this.state.cancel = this.keys.esc.isDown;
    }
    
    /**
     * Process gamepad input
     */
    processGamepad() {
        if (!this.gamepad) return;
        
        // Left stick
        const leftX = this.gamepad.leftStick.x;
        const leftY = this.gamepad.leftStick.y;
        
        if (Math.abs(leftX) > this.deadzone) {
            this.state.left = this.state.left || leftX < -this.deadzone;
            this.state.right = this.state.right || leftX > this.deadzone;
        }
        
        if (Math.abs(leftY) > this.deadzone) {
            this.state.up = this.state.up || leftY < -this.deadzone;
            this.state.down = this.state.down || leftY > this.deadzone;
        }
        
        // D-pad
        this.state.left = this.state.left || this.gamepad.left;
        this.state.right = this.state.right || this.gamepad.right;
        this.state.up = this.state.up || this.gamepad.up;
        this.state.down = this.state.down || this.gamepad.down;
        
        // Buttons (A=0, B=1, X=2, Y=3, etc.)
        this.state.boost = this.state.boost || this.gamepad.A || this.gamepad.R2 > 0.5;
        this.state.brake = this.state.brake || this.gamepad.B || this.gamepad.L2 > 0.5;
        this.state.pause = this.state.pause || this.gamepad.buttons[9]?.pressed; // Start
        this.state.confirm = this.state.confirm || this.gamepad.A;
        this.state.cancel = this.state.cancel || this.gamepad.B;
    }
    
    /**
     * Process touch input
     */
    processTouch() {
        if (!this.touch.active) return;
        
        const screenWidth = this.scene.scale.width;
        const screenHeight = this.scene.scale.height;
        const sensitivity = 50;
        
        // Left/right based on horizontal swipe or touch position
        if (this.touch.currentX < screenWidth * 0.3) {
            this.state.left = true;
        } else if (this.touch.currentX > screenWidth * 0.7) {
            this.state.right = true;
        } else if (Math.abs(this.touch.deltaX) > sensitivity) {
            this.state.left = this.touch.deltaX < -sensitivity;
            this.state.right = this.touch.deltaX > sensitivity;
        }
        
        // Boost on double tap or bottom of screen
        if (this.touch.currentY > screenHeight * 0.8) {
            this.state.boost = true;
        }
    }
    
    /**
     * Check if key was just pressed (not held)
     */
    justPressed(key) {
        return this.state[key] && !this.previousState[key];
    }
    
    /**
     * Check if key was just released
     */
    justReleased(key) {
        return !this.state[key] && this.previousState[key];
    }
    
    /**
     * Get horizontal axis value (-1 to 1)
     */
    getHorizontalAxis() {
        let value = 0;
        
        // Keyboard
        if (this.state.left) value -= 1;
        if (this.state.right) value += 1;
        
        // Gamepad (more precise)
        if (this.gamepad) {
            const stickX = this.gamepad.leftStick.x;
            if (Math.abs(stickX) > this.deadzone) {
                value = stickX;
            }
        }
        
        // Touch (normalized delta)
        if (this.touch.active && Math.abs(this.touch.deltaX) > 10) {
            value = MathUtils.clamp(this.touch.deltaX / 100, -1, 1);
        }
        
        return MathUtils.clamp(value, -1, 1);
    }
    
    /**
     * Get vertical axis value (-1 to 1)
     */
    getVerticalAxis() {
        let value = 0;
        
        if (this.state.up) value -= 1;
        if (this.state.down) value += 1;
        
        if (this.gamepad) {
            const stickY = this.gamepad.leftStick.y;
            if (Math.abs(stickY) > this.deadzone) {
                value = stickY;
            }
        }
        
        return MathUtils.clamp(value, -1, 1);
    }
    
    /**
     * Get boost intensity (0 to 1)
     */
    getBoostIntensity() {
        if (this.gamepad && this.gamepad.R2 !== undefined) {
            return this.gamepad.R2;
        }
        return this.state.boost ? 1 : 0;
    }
    
    /**
     * Get brake intensity (0 to 1)
     */
    getBrakeIntensity() {
        if (this.gamepad && this.gamepad.L2 !== undefined) {
            return this.gamepad.L2;
        }
        return this.state.brake ? 1 : 0;
    }
    
    /**
     * Check if using touch controls
     */
    isTouchActive() {
        return this.touch.active;
    }
    
    /**
     * Check if gamepad connected
     */
    hasGamepad() {
        return this.gamepad !== null;
    }
    
    /**
     * Vibrate gamepad
     */
    vibrate(duration = 100, intensity = 0.5) {
        if (this.gamepad && this.gamepad.vibration) {
            this.gamepad.vibration.playEffect('dual-rumble', {
                duration: duration,
                strongMagnitude: intensity,
                weakMagnitude: intensity * 0.5,
            });
        }
    }
    
    /**
     * Clean up
     */
    destroy() {
        // Phaser handles cleanup automatically
    }
}

// Export
if (typeof window !== 'undefined') {
    window.InputManager = InputManager;
}
