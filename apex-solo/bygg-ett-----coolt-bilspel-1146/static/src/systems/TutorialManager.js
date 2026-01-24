/**
 * TutorialManager.js
 * Interactive tutorial system for teaching game mechanics
 * Provides step-by-step guidance, hints, and onboarding flow
 */

class TutorialManager {
    constructor() {
        // Tutorial state
        this.isActive = false;
        this.currentStep = 0;
        this.currentTutorial = null;
        this.completedTutorials = new Set();
        
        // Progress tracking
        this.stepProgress = {};
        this.attemptCount = 0;
        this.hintLevel = 0;
        
        // Callbacks
        this.onStepComplete = null;
        this.onTutorialComplete = null;
        this.onHintRequest = null;
        
        // UI references
        this.scene = null;
        this.overlay = null;
        this.dialogBox = null;
        this.highlightBox = null;
        this.arrowIndicator = null;
        
        // Tutorial definitions
        this.tutorials = this.defineTutorials();
        
        // Load progress
        this.loadProgress();
    }
    
    /**
     * Define all tutorials
     */
    defineTutorials() {
        return {
            // Basic controls tutorial
            'basic_controls': {
                id: 'basic_controls',
                name: 'Basic Controls',
                description: 'Learn how to control your vehicle',
                required: true,
                steps: [
                    {
                        id: 'welcome',
                        type: 'dialog',
                        title: 'Welcome to GRAVSHIFT!',
                        message: 'In this game, gravity is your ally and your enemy. The track rotates, and you must adapt!',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'move_left',
                        type: 'action',
                        title: 'Moving Left',
                        message: 'Press the LEFT ARROW key or A to move left.',
                        highlight: 'left_indicator',
                        position: 'bottom',
                        action: 'move_left',
                        required: true,
                        timeout: 10000,
                        hints: [
                            'Use the left arrow key on your keyboard',
                            'Or press the A key',
                            'Tap the left side of the screen on mobile'
                        ]
                    },
                    {
                        id: 'move_right',
                        type: 'action',
                        title: 'Moving Right',
                        message: 'Press the RIGHT ARROW key or D to move right.',
                        highlight: 'right_indicator',
                        position: 'bottom',
                        action: 'move_right',
                        required: true,
                        timeout: 10000,
                        hints: [
                            'Use the right arrow key on your keyboard',
                            'Or press the D key',
                            'Tap the right side of the screen on mobile'
                        ]
                    },
                    {
                        id: 'boost',
                        type: 'action',
                        title: 'Boost',
                        message: 'Hold SPACE or UP ARROW to activate boost. Boost is limited!',
                        highlight: 'boost_meter',
                        position: 'top',
                        action: 'boost',
                        required: true,
                        timeout: 15000,
                        hints: [
                            'Hold down the spacebar',
                            'Or hold the up arrow key',
                            'Watch your boost meter - it depletes!'
                        ]
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Great Job!',
                        message: 'You\'ve mastered the basic controls. Now let\'s learn about gravity!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            },
            
            // Gravity mechanics tutorial
            'gravity_mechanics': {
                id: 'gravity_mechanics',
                name: 'Gravity Mechanics',
                description: 'Understand how gravity affects your vehicle',
                required: true,
                prerequisite: 'basic_controls',
                steps: [
                    {
                        id: 'intro',
                        type: 'dialog',
                        title: 'Gravity Shifting',
                        message: 'The track rotates around you. Gravity always pulls down, but "down" changes!',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'track_rotation',
                        type: 'demonstration',
                        title: 'Watch the Track',
                        message: 'Notice how the track rotates. Your vehicle will slide based on the angle.',
                        highlight: 'track_angle',
                        position: 'right',
                        duration: 5000,
                        demo: 'rotate_track_demo'
                    },
                    {
                        id: 'counter_gravity',
                        type: 'action',
                        title: 'Fight the Pull',
                        message: 'The track is tilting! Move against the gravity to stay centered.',
                        highlight: 'gravity_indicator',
                        position: 'top',
                        action: 'counter_gravity',
                        required: true,
                        timeout: 20000,
                        hints: [
                            'Move in the opposite direction of the tilt',
                            'If the track tilts left, move right',
                            'Use small adjustments to stay on track'
                        ]
                    },
                    {
                        id: 'drift',
                        type: 'action',
                        title: 'Controlled Drift',
                        message: 'Sometimes you want to drift with gravity. Let yourself slide while tilted.',
                        highlight: null,
                        position: 'center',
                        action: 'drift_with_gravity',
                        required: false,
                        timeout: 15000,
                        hints: [
                            'Release the controls momentarily',
                            'Let gravity pull you to one side',
                            'This can help you collect items!'
                        ]
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Gravity Master!',
                        message: 'You understand gravity mechanics. Use them to your advantage!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            },
            
            // Obstacles tutorial
            'obstacles': {
                id: 'obstacles',
                name: 'Obstacles',
                description: 'Learn to avoid and navigate obstacles',
                required: true,
                prerequisite: 'gravity_mechanics',
                steps: [
                    {
                        id: 'intro',
                        type: 'dialog',
                        title: 'Danger Ahead!',
                        message: 'Various obstacles will block your path. Learn to identify and avoid them.',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'barrier_demo',
                        type: 'demonstration',
                        title: 'Barriers',
                        message: 'Red barriers block your path. Go around them!',
                        highlight: 'barrier_obstacle',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_barrier'
                    },
                    {
                        id: 'avoid_barrier',
                        type: 'action',
                        title: 'Dodge!',
                        message: 'A barrier is coming! Move left or right to avoid it.',
                        highlight: null,
                        position: 'top',
                        action: 'avoid_obstacle',
                        required: true,
                        timeout: 10000,
                        hints: [
                            'Watch for the obstacle coming toward you',
                            'Move to either side to avoid it',
                            'Don\'t wait until the last moment!'
                        ]
                    },
                    {
                        id: 'spike_demo',
                        type: 'demonstration',
                        title: 'Spikes',
                        message: 'Orange spikes are smaller but just as deadly!',
                        highlight: 'spike_obstacle',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_spike'
                    },
                    {
                        id: 'debris_demo',
                        type: 'demonstration',
                        title: 'Debris',
                        message: 'Gray debris rotates and moves unpredictably.',
                        highlight: 'debris_obstacle',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_debris'
                    },
                    {
                        id: 'laser_demo',
                        type: 'demonstration',
                        title: 'Lasers',
                        message: 'Blue lasers toggle on and off. Time your movement!',
                        highlight: 'laser_obstacle',
                        position: 'bottom',
                        duration: 5000,
                        demo: 'show_laser'
                    },
                    {
                        id: 'practice',
                        type: 'challenge',
                        title: 'Obstacle Course',
                        message: 'Avoid 5 obstacles in a row to complete this lesson.',
                        position: 'top',
                        goal: { type: 'avoid_consecutive', count: 5 },
                        timeout: 60000,
                        hints: [
                            'Focus on one obstacle at a time',
                            'Anticipate where you need to be',
                            'Use gravity to help you move faster'
                        ]
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Obstacle Navigator!',
                        message: 'You can now handle obstacles like a pro!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            },
            
            // Power-ups tutorial
            'powerups': {
                id: 'powerups',
                name: 'Power-Ups',
                description: 'Collect and use power-ups effectively',
                required: true,
                prerequisite: 'obstacles',
                steps: [
                    {
                        id: 'intro',
                        type: 'dialog',
                        title: 'Power-Ups!',
                        message: 'Collect power-ups to gain special abilities. They can save your life!',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'boost_powerup',
                        type: 'demonstration',
                        title: 'Boost Power-Up',
                        message: 'Cyan orbs refill your boost meter and give instant speed!',
                        highlight: 'boost_powerup',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_boost_powerup'
                    },
                    {
                        id: 'collect_boost',
                        type: 'action',
                        title: 'Collect Boost',
                        message: 'Grab the boost power-up!',
                        highlight: null,
                        position: 'top',
                        action: 'collect_powerup_boost',
                        required: true,
                        timeout: 15000,
                        hints: [
                            'Move toward the cyan orb',
                            'Drive directly into it',
                            'Watch your boost meter refill!'
                        ]
                    },
                    {
                        id: 'shield_powerup',
                        type: 'demonstration',
                        title: 'Shield Power-Up',
                        message: 'Green orbs give you a protective shield that absorbs one hit!',
                        highlight: 'shield_powerup',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_shield_powerup'
                    },
                    {
                        id: 'slowmo_powerup',
                        type: 'demonstration',
                        title: 'Slow-Mo Power-Up',
                        message: 'Yellow orbs slow down time, giving you more reaction time!',
                        highlight: 'slowmo_powerup',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_slowmo_powerup'
                    },
                    {
                        id: 'magnet_powerup',
                        type: 'demonstration',
                        title: 'Magnet Power-Up',
                        message: 'Purple orbs attract nearby coins and power-ups to you!',
                        highlight: 'magnet_powerup',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_magnet_powerup'
                    },
                    {
                        id: 'ghost_powerup',
                        type: 'demonstration',
                        title: 'Ghost Power-Up',
                        message: 'White orbs make you intangible - pass through obstacles!',
                        highlight: 'ghost_powerup',
                        position: 'bottom',
                        duration: 4000,
                        demo: 'show_ghost_powerup'
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Power-Up Pro!',
                        message: 'You know all the power-ups. Collect them strategically!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            },
            
            // Scoring tutorial
            'scoring': {
                id: 'scoring',
                name: 'Scoring System',
                description: 'Maximize your score with combos',
                required: false,
                prerequisite: 'powerups',
                steps: [
                    {
                        id: 'intro',
                        type: 'dialog',
                        title: 'Score Big!',
                        message: 'Learn how to maximize your score with combos and multipliers.',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'base_score',
                        type: 'info',
                        title: 'Base Score',
                        message: 'You earn points for: Distance traveled, Time survived, Coins collected',
                        highlight: 'score_display',
                        position: 'top',
                        duration: 5000
                    },
                    {
                        id: 'combo_system',
                        type: 'info',
                        title: 'Combo System',
                        message: 'Chain actions together to build your combo multiplier. Higher combo = more points!',
                        highlight: 'combo_display',
                        position: 'top',
                        duration: 5000
                    },
                    {
                        id: 'near_miss',
                        type: 'demonstration',
                        title: 'Near Miss',
                        message: 'Pass close to obstacles without hitting them for bonus points!',
                        highlight: null,
                        position: 'center',
                        duration: 4000,
                        demo: 'near_miss_demo'
                    },
                    {
                        id: 'do_near_miss',
                        type: 'action',
                        title: 'Try Near Miss',
                        message: 'Pass very close to an obstacle without hitting it.',
                        highlight: null,
                        position: 'top',
                        action: 'near_miss',
                        required: false,
                        timeout: 30000,
                        hints: [
                            'Get as close as possible without colliding',
                            'The closer you are, the more points',
                            'This is risky but rewarding!'
                        ]
                    },
                    {
                        id: 'drift_bonus',
                        type: 'info',
                        title: 'Drift Bonus',
                        message: 'Drifting with gravity builds a special drift combo for extra points.',
                        highlight: 'drift_meter',
                        position: 'right',
                        duration: 5000
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Score Master!',
                        message: 'Now you know how to get high scores. Good luck on the leaderboards!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            },
            
            // Advanced techniques
            'advanced': {
                id: 'advanced',
                name: 'Advanced Techniques',
                description: 'Master pro-level techniques',
                required: false,
                prerequisite: 'scoring',
                steps: [
                    {
                        id: 'intro',
                        type: 'dialog',
                        title: 'Pro Techniques',
                        message: 'Ready for advanced maneuvers? These techniques separate the best from the rest.',
                        position: 'center',
                        duration: 0,
                        action: null
                    },
                    {
                        id: 'gravity_slingshot',
                        type: 'demonstration',
                        title: 'Gravity Slingshot',
                        message: 'Use gravity rotation to gain extra speed. Let it pull you, then boost!',
                        highlight: null,
                        position: 'center',
                        duration: 5000,
                        demo: 'slingshot_demo'
                    },
                    {
                        id: 'obstacle_threading',
                        type: 'info',
                        title: 'Obstacle Threading',
                        message: 'Some obstacles have small gaps. Thread through them for massive bonus!',
                        highlight: null,
                        position: 'center',
                        duration: 5000
                    },
                    {
                        id: 'boost_management',
                        type: 'info',
                        title: 'Boost Management',
                        message: 'Save boost for emergencies. Short bursts are more efficient than holding.',
                        highlight: 'boost_meter',
                        position: 'top',
                        duration: 5000
                    },
                    {
                        id: 'powerup_timing',
                        type: 'info',
                        title: 'Power-Up Timing',
                        message: 'Don\'t grab shield right away if you don\'t need it. Wait for danger!',
                        highlight: null,
                        position: 'center',
                        duration: 5000
                    },
                    {
                        id: 'pattern_recognition',
                        type: 'info',
                        title: 'Pattern Recognition',
                        message: 'Obstacles spawn in patterns. Learn them to anticipate and react faster.',
                        highlight: null,
                        position: 'center',
                        duration: 5000
                    },
                    {
                        id: 'complete',
                        type: 'dialog',
                        title: 'Advanced Pilot!',
                        message: 'You have the knowledge of a pro. Now go set some records!',
                        position: 'center',
                        duration: 3000,
                        action: null
                    }
                ]
            }
        };
    }
    
    /**
     * Load tutorial progress from storage
     */
    loadProgress() {
        try {
            const saved = localStorage.getItem('gravshift_tutorial_progress');
            if (saved) {
                const data = JSON.parse(saved);
                this.completedTutorials = new Set(data.completed || []);
                this.stepProgress = data.stepProgress || {};
            }
        } catch (e) {
            console.error('Failed to load tutorial progress:', e);
        }
    }
    
    /**
     * Save tutorial progress
     */
    saveProgress() {
        try {
            const data = {
                completed: Array.from(this.completedTutorials),
                stepProgress: this.stepProgress
            };
            localStorage.setItem('gravshift_tutorial_progress', JSON.stringify(data));
        } catch (e) {
            console.error('Failed to save tutorial progress:', e);
        }
    }
    
    /**
     * Check if a tutorial is available
     */
    isTutorialAvailable(tutorialId) {
        const tutorial = this.tutorials[tutorialId];
        if (!tutorial) return false;
        
        // Check prerequisite
        if (tutorial.prerequisite && !this.completedTutorials.has(tutorial.prerequisite)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * Check if a tutorial is completed
     */
    isTutorialCompleted(tutorialId) {
        return this.completedTutorials.has(tutorialId);
    }
    
    /**
     * Get next required tutorial
     */
    getNextRequiredTutorial() {
        for (const tutorialId of Object.keys(this.tutorials)) {
            const tutorial = this.tutorials[tutorialId];
            if (tutorial.required && !this.isTutorialCompleted(tutorialId) && this.isTutorialAvailable(tutorialId)) {
                return tutorialId;
            }
        }
        return null;
    }
    
    /**
     * Start a tutorial
     */
    startTutorial(tutorialId, scene) {
        const tutorial = this.tutorials[tutorialId];
        if (!tutorial) {
            console.error(`Tutorial not found: ${tutorialId}`);
            return false;
        }
        
        if (!this.isTutorialAvailable(tutorialId)) {
            console.warn(`Tutorial not available: ${tutorialId}`);
            return false;
        }
        
        this.scene = scene;
        this.currentTutorial = tutorial;
        this.currentStep = 0;
        this.isActive = true;
        this.hintLevel = 0;
        this.attemptCount = 0;
        
        // Create UI elements
        this.createUIElements();
        
        // Start first step
        this.executeStep(tutorial.steps[0]);
        
        return true;
    }
    
    /**
     * Create tutorial UI elements
     */
    createUIElements() {
        if (!this.scene) return;
        
        const { width, height } = this.scene.cameras.main;
        
        // Semi-transparent overlay
        this.overlay = this.scene.add.graphics();
        this.overlay.setDepth(900);
        
        // Dialog box container
        this.dialogBox = this.scene.add.container(width / 2, height - 100);
        this.dialogBox.setDepth(910);
        
        // Highlight box
        this.highlightBox = this.scene.add.graphics();
        this.highlightBox.setDepth(895);
        
        // Arrow indicator
        this.arrowIndicator = this.scene.add.graphics();
        this.arrowIndicator.setDepth(905);
    }
    
    /**
     * Execute a tutorial step
     */
    executeStep(step) {
        if (!step) {
            this.completeTutorial();
            return;
        }
        
        // Clear previous UI
        this.clearStepUI();
        
        // Set up overlay
        this.setupOverlay(step);
        
        // Set up highlight
        if (step.highlight) {
            this.setupHighlight(step.highlight);
        }
        
        // Show dialog
        this.showDialog(step);
        
        // Set up action listener if needed
        if (step.type === 'action' || step.type === 'challenge') {
            this.setupActionListener(step);
        }
        
        // Auto-advance for timed steps
        if (step.duration > 0) {
            this.scene.time.delayedCall(step.duration, () => {
                this.advanceStep();
            });
        }
    }
    
    /**
     * Clear step-specific UI
     */
    clearStepUI() {
        this.overlay.clear();
        this.highlightBox.clear();
        this.arrowIndicator.clear();
        this.dialogBox.removeAll(true);
    }
    
    /**
     * Set up the overlay
     */
    setupOverlay(step) {
        const { width, height } = this.scene.cameras.main;
        
        // Dark overlay with cutout for highlight
        this.overlay.fillStyle(0x000000, 0.7);
        this.overlay.fillRect(0, 0, width, height);
    }
    
    /**
     * Set up highlight around an element
     */
    setupHighlight(highlightId) {
        // In real implementation, this would find the element by ID
        // For now, show a sample highlight
        const { width, height } = this.scene.cameras.main;
        
        // Sample highlight positions
        const highlights = {
            'left_indicator': { x: 50, y: height - 150, w: 80, h: 60 },
            'right_indicator': { x: width - 130, y: height - 150, w: 80, h: 60 },
            'boost_meter': { x: 20, y: 100, w: 150, h: 30 },
            'score_display': { x: width - 170, y: 20, w: 150, h: 40 },
            'combo_display': { x: width - 170, y: 65, w: 150, h: 30 },
            'gravity_indicator': { x: width / 2 - 50, y: 80, w: 100, h: 100 }
        };
        
        const pos = highlights[highlightId];
        if (pos) {
            // Clear the overlay area
            this.overlay.fillStyle(0x000000, 0);
            this.overlay.fillRect(pos.x - 5, pos.y - 5, pos.w + 10, pos.h + 10);
            
            // Draw highlight border
            this.highlightBox.lineStyle(3, 0x00ffff, 1);
            this.highlightBox.strokeRoundedRect(pos.x - 5, pos.y - 5, pos.w + 10, pos.h + 10, 8);
            
            // Animated glow
            this.scene.tweens.add({
                targets: { alpha: 1 },
                alpha: 0.5,
                duration: 500,
                yoyo: true,
                repeat: -1,
                onUpdate: (tween) => {
                    if (this.highlightBox) {
                        this.highlightBox.clear();
                        this.highlightBox.lineStyle(3, 0x00ffff, tween.getValue());
                        this.highlightBox.strokeRoundedRect(pos.x - 5, pos.y - 5, pos.w + 10, pos.h + 10, 8);
                    }
                }
            });
        }
    }
    
    /**
     * Show dialog box
     */
    showDialog(step) {
        const { width, height } = this.scene.cameras.main;
        
        // Position dialog based on step.position
        let dialogY = height - 100;
        if (step.position === 'top') {
            dialogY = 100;
        } else if (step.position === 'center') {
            dialogY = height / 2;
        }
        
        this.dialogBox.y = dialogY;
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x0a1525, 0.95);
        bg.fillRoundedRect(-200, -60, 400, 120, 10);
        bg.lineStyle(2, 0x00ffff, 0.8);
        bg.strokeRoundedRect(-200, -60, 400, 120, 10);
        this.dialogBox.add(bg);
        
        // Title
        const title = this.scene.add.text(0, -40, step.title, {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: '#00ffff'
        }).setOrigin(0.5);
        this.dialogBox.add(title);
        
        // Message
        const message = this.scene.add.text(0, 0, step.message, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffffff',
            wordWrap: { width: 360 },
            align: 'center'
        }).setOrigin(0.5);
        this.dialogBox.add(message);
        
        // Continue button for dialog steps
        if (step.type === 'dialog' && step.duration === 0) {
            const continueBtn = this.scene.add.text(0, 40, 'CONTINUE', {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#00ffff',
                backgroundColor: '#1a3050',
                padding: { x: 20, y: 8 }
            }).setOrigin(0.5).setInteractive({ useHandCursor: true });
            
            continueBtn.on('pointerdown', () => this.advanceStep());
            continueBtn.on('pointerover', () => continueBtn.setColor('#ffffff'));
            continueBtn.on('pointerout', () => continueBtn.setColor('#00ffff'));
            
            this.dialogBox.add(continueBtn);
        }
        
        // Hint button for action steps
        if ((step.type === 'action' || step.type === 'challenge') && step.hints) {
            const hintBtn = this.scene.add.text(-80, 40, 'HINT', {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#ffaa00',
                backgroundColor: '#1a2535',
                padding: { x: 12, y: 6 }
            }).setOrigin(0.5).setInteractive({ useHandCursor: true });
            
            hintBtn.on('pointerdown', () => this.showHint(step));
            this.dialogBox.add(hintBtn);
            
            // Skip button
            const skipBtn = this.scene.add.text(80, 40, 'SKIP', {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#667788',
                backgroundColor: '#1a2535',
                padding: { x: 12, y: 6 }
            }).setOrigin(0.5).setInteractive({ useHandCursor: true });
            
            skipBtn.on('pointerdown', () => this.skipStep());
            this.dialogBox.add(skipBtn);
        }
        
        // Animate in
        this.dialogBox.setAlpha(0);
        this.dialogBox.setScale(0.8);
        this.scene.tweens.add({
            targets: this.dialogBox,
            alpha: 1,
            scale: 1,
            duration: 300,
            ease: 'Back.easeOut'
        });
    }
    
    /**
     * Set up action listener for interactive steps
     */
    setupActionListener(step) {
        this.currentAction = step.action;
        this.actionStartTime = Date.now();
        
        // Set timeout if specified
        if (step.timeout) {
            this.actionTimeout = this.scene.time.delayedCall(step.timeout, () => {
                if (!step.required) {
                    this.advanceStep();
                } else {
                    this.showHint(step);
                }
            });
        }
    }
    
    /**
     * Report an action from the game
     */
    reportAction(actionType, data = {}) {
        if (!this.isActive || !this.currentAction) return;
        
        if (actionType === this.currentAction) {
            this.completeAction();
        }
    }
    
    /**
     * Complete current action step
     */
    completeAction() {
        if (this.actionTimeout) {
            this.actionTimeout.remove();
        }
        
        // Show success feedback
        this.showSuccessFeedback();
        
        // Advance after delay
        this.scene.time.delayedCall(1000, () => {
            this.advanceStep();
        });
    }
    
    /**
     * Show success feedback
     */
    showSuccessFeedback() {
        const { width, height } = this.scene.cameras.main;
        
        const success = this.scene.add.text(width / 2, height / 2 - 50, 'NICE!', {
            fontFamily: 'Arial Black',
            fontSize: '32px',
            color: '#00ff88',
            stroke: '#004422',
            strokeThickness: 4
        }).setOrigin(0.5).setDepth(920);
        
        this.scene.tweens.add({
            targets: success,
            y: height / 2 - 100,
            alpha: 0,
            scale: 1.5,
            duration: 800,
            ease: 'Power2',
            onComplete: () => success.destroy()
        });
        
        if (window.SoundManager) {
            SoundManager.play('success');
        }
    }
    
    /**
     * Show a hint for the current step
     */
    showHint(step) {
        if (!step.hints || this.hintLevel >= step.hints.length) return;
        
        const hint = step.hints[this.hintLevel];
        this.hintLevel++;
        
        // Show hint overlay
        const { width, height } = this.scene.cameras.main;
        
        const hintBg = this.scene.add.graphics();
        hintBg.fillStyle(0x332200, 0.95);
        hintBg.fillRoundedRect(width / 2 - 150, height / 2 - 40, 300, 80, 8);
        hintBg.lineStyle(2, 0xffaa00, 0.8);
        hintBg.strokeRoundedRect(width / 2 - 150, height / 2 - 40, 300, 80, 8);
        hintBg.setDepth(925);
        
        const hintText = this.scene.add.text(width / 2, height / 2, hint, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffaa00',
            wordWrap: { width: 280 },
            align: 'center'
        }).setOrigin(0.5).setDepth(926);
        
        // Auto-hide after delay
        this.scene.time.delayedCall(3000, () => {
            hintBg.destroy();
            hintText.destroy();
        });
        
        if (this.onHintRequest) {
            this.onHintRequest(step, this.hintLevel);
        }
    }
    
    /**
     * Skip current step
     */
    skipStep() {
        const step = this.currentTutorial.steps[this.currentStep];
        
        if (step.required) {
            // Can't skip required steps, show message
            this.showMessage('This step is required!', 0xff4444);
            return;
        }
        
        if (this.actionTimeout) {
            this.actionTimeout.remove();
        }
        
        this.advanceStep();
    }
    
    /**
     * Advance to next step
     */
    advanceStep() {
        this.currentStep++;
        this.hintLevel = 0;
        this.attemptCount = 0;
        this.currentAction = null;
        
        if (this.currentStep >= this.currentTutorial.steps.length) {
            this.completeTutorial();
        } else {
            this.executeStep(this.currentTutorial.steps[this.currentStep]);
        }
        
        if (this.onStepComplete) {
            this.onStepComplete(this.currentTutorial.id, this.currentStep - 1);
        }
    }
    
    /**
     * Complete the current tutorial
     */
    completeTutorial() {
        this.completedTutorials.add(this.currentTutorial.id);
        this.saveProgress();
        
        // Show completion message
        this.showCompletionScreen();
        
        if (this.onTutorialComplete) {
            this.onTutorialComplete(this.currentTutorial.id);
        }
    }
    
    /**
     * Show tutorial completion screen
     */
    showCompletionScreen() {
        const { width, height } = this.scene.cameras.main;
        
        // Clear UI
        this.clearStepUI();
        
        // Full overlay
        this.overlay.fillStyle(0x000000, 0.9);
        this.overlay.fillRect(0, 0, width, height);
        
        // Completion panel
        const panel = this.scene.add.container(width / 2, height / 2);
        panel.setDepth(930);
        
        const panelBg = this.scene.add.graphics();
        panelBg.fillStyle(0x0a1525, 0.98);
        panelBg.fillRoundedRect(-200, -120, 400, 240, 15);
        panelBg.lineStyle(3, 0x00ff88, 0.9);
        panelBg.strokeRoundedRect(-200, -120, 400, 240, 15);
        panel.add(panelBg);
        
        const checkmark = this.scene.add.text(0, -70, '✓', {
            fontSize: '48px',
            color: '#00ff88'
        }).setOrigin(0.5);
        panel.add(checkmark);
        
        const title = this.scene.add.text(0, -20, 'TUTORIAL COMPLETE!', {
            fontFamily: 'Arial Black',
            fontSize: '24px',
            color: '#00ff88'
        }).setOrigin(0.5);
        panel.add(title);
        
        const tutorialName = this.scene.add.text(0, 20, this.currentTutorial.name, {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#ffffff'
        }).setOrigin(0.5);
        panel.add(tutorialName);
        
        // Continue button
        const continueBtn = this.scene.add.text(0, 80, 'CONTINUE', {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#00ffff',
            backgroundColor: '#1a3050',
            padding: { x: 30, y: 12 }
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        continueBtn.on('pointerdown', () => {
            this.endTutorial();
            panel.destroy();
        });
        
        panel.add(continueBtn);
        
        // Animate
        panel.setAlpha(0);
        panel.setScale(0.5);
        this.scene.tweens.add({
            targets: panel,
            alpha: 1,
            scale: 1,
            duration: 500,
            ease: 'Back.easeOut'
        });
        
        if (window.SoundManager) {
            SoundManager.play('achievement');
        }
    }
    
    /**
     * End the tutorial
     */
    endTutorial() {
        this.isActive = false;
        this.currentTutorial = null;
        this.currentStep = 0;
        
        // Clean up UI
        if (this.overlay) this.overlay.destroy();
        if (this.dialogBox) this.dialogBox.destroy();
        if (this.highlightBox) this.highlightBox.destroy();
        if (this.arrowIndicator) this.arrowIndicator.destroy();
        
        this.overlay = null;
        this.dialogBox = null;
        this.highlightBox = null;
        this.arrowIndicator = null;
    }
    
    /**
     * Show a message
     */
    showMessage(text, color = 0xffffff) {
        if (!this.scene) return;
        
        const { width, height } = this.scene.cameras.main;
        
        const message = this.scene.add.text(width / 2, height / 2, text, {
            fontFamily: 'Arial',
            fontSize: '16px',
            color: '#' + color.toString(16).padStart(6, '0')
        }).setOrigin(0.5).setDepth(950);
        
        this.scene.time.delayedCall(2000, () => {
            message.destroy();
        });
    }
    
    /**
     * Get tutorial progress info
     */
    getProgress() {
        const totalTutorials = Object.keys(this.tutorials).length;
        const completedCount = this.completedTutorials.size;
        const requiredTutorials = Object.values(this.tutorials).filter(t => t.required).length;
        const completedRequired = Object.values(this.tutorials)
            .filter(t => t.required && this.completedTutorials.has(t.id)).length;
        
        return {
            total: totalTutorials,
            completed: completedCount,
            percentage: Math.round((completedCount / totalTutorials) * 100),
            requiredTotal: requiredTutorials,
            requiredCompleted: completedRequired,
            allRequiredComplete: completedRequired >= requiredTutorials
        };
    }
    
    /**
     * Reset all tutorial progress
     */
    resetProgress() {
        this.completedTutorials.clear();
        this.stepProgress = {};
        this.saveProgress();
    }
    
    /**
     * Check if should show tutorial prompt
     */
    shouldShowTutorialPrompt() {
        const nextRequired = this.getNextRequiredTutorial();
        return nextRequired !== null;
    }
}

// Create singleton instance
if (typeof window !== 'undefined') {
    window.TutorialManager = new TutorialManager();
}
