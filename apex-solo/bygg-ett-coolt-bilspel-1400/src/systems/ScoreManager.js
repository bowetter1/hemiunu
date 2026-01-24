/**
 * NEON TRAIL - Score Manager
 * Handles scoring, combos, highscores, and achievements
 */

class ScoreManager {
    constructor(scene) {
        this.scene = scene;
        
        // Current run stats
        this.score = 0;
        this.distance = 0;
        this.combo = 0;
        this.maxCombo = 0;
        this.multiplier = 1;
        
        // Combo timer
        this.comboTimer = null;
        this.comboTimeout = SCORE_CONFIG.COMBO_TIMEOUT;
        
        // Session stats
        this.drifts = 0;
        this.nearMisses = 0;
        this.powerUpsCollected = 0;
        this.obstaclesAvoided = 0;
        
        // Milestone tracking
        this.lastMilestoneIndex = -1;
        
        // Highscore
        this.highscore = this.loadHighscore();
        this.isNewHighscore = false;
        
        // Callbacks
        this.onScoreChange = null;
        this.onComboChange = null;
        this.onMilestone = null;
        this.onHighscore = null;
    }
    
    /**
     * Reset for new game
     */
    reset() {
        this.score = 0;
        this.distance = 0;
        this.combo = 0;
        this.maxCombo = 0;
        this.multiplier = 1;
        this.drifts = 0;
        this.nearMisses = 0;
        this.powerUpsCollected = 0;
        this.obstaclesAvoided = 0;
        this.lastMilestoneIndex = -1;
        this.isNewHighscore = false;
        
        if (this.comboTimer) {
            this.comboTimer.remove();
            this.comboTimer = null;
        }
    }
    
    /**
     * Update distance traveled
     */
    addDistance(delta) {
        this.distance += delta;
        
        // Distance-based score
        const distanceScore = Math.floor(delta * SCORE_CONFIG.DISTANCE_MULTIPLIER * this.multiplier);
        this.score += distanceScore;
        
        // Check milestones
        this.checkMilestones();
        
        // Notify
        if (this.onScoreChange) {
            this.onScoreChange(this.score, this.distance);
        }
        
        // Check highscore
        this.checkHighscore();
    }
    
    /**
     * Add drift bonus
     */
    addDriftBonus(driftDuration) {
        const bonus = Math.floor(SCORE_CONFIG.DRIFT_BONUS * driftDuration * this.multiplier);
        this.score += bonus;
        this.drifts++;
        
        // Combo
        this.incrementCombo();
        
        // Show floating text
        this.showFloatingScore(bonus, 'DRIFT!', GAME_CONFIG.COLORS.CYAN);
        
        if (this.onScoreChange) {
            this.onScoreChange(this.score, this.distance);
        }
        
        return bonus;
    }
    
    /**
     * Add near miss bonus
     */
    addNearMissBonus() {
        const bonus = Math.floor(SCORE_CONFIG.NEAR_MISS_BONUS * this.multiplier);
        this.score += bonus;
        this.nearMisses++;
        
        // Combo
        this.incrementCombo();
        
        // Show floating text
        this.showFloatingScore(bonus, 'NEAR MISS!', GAME_CONFIG.COLORS.MAGENTA);
        
        if (this.onScoreChange) {
            this.onScoreChange(this.score, this.distance);
        }
        
        return bonus;
    }
    
    /**
     * Add power-up bonus
     */
    addPowerUpBonus(powerUpType) {
        const bonus = Math.floor(SCORE_CONFIG.POWERUP_BONUS * this.multiplier);
        this.score += bonus;
        this.powerUpsCollected++;
        
        // Show floating text
        const color = POWERUP_CONFIG.TYPES[powerUpType]?.color || GAME_CONFIG.COLORS.YELLOW;
        this.showFloatingScore(bonus, powerUpType, color);
        
        if (this.onScoreChange) {
            this.onScoreChange(this.score, this.distance);
        }
        
        return bonus;
    }
    
    /**
     * Add milestone bonus
     */
    addMilestoneBonus(milestone) {
        this.score += milestone.bonus;
        
        // Big celebration text
        this.showMilestoneText(milestone.message, milestone.bonus);
        
        if (this.onMilestone) {
            this.onMilestone(milestone);
        }
        
        if (this.onScoreChange) {
            this.onScoreChange(this.score, this.distance);
        }
        
        return milestone.bonus;
    }
    
    /**
     * Increment combo
     */
    incrementCombo() {
        this.combo++;
        if (this.combo > this.maxCombo) {
            this.maxCombo = this.combo;
        }
        
        // Update multiplier (capped)
        this.multiplier = Math.min(
            1 + (this.combo * 0.1),
            SCORE_CONFIG.COMBO_MULTIPLIER_MAX
        );
        
        // Reset combo timer
        if (this.comboTimer) {
            this.comboTimer.remove();
        }
        
        this.comboTimer = this.scene.time.addEvent({
            delay: this.comboTimeout,
            callback: this.resetCombo,
            callbackScope: this,
        });
        
        if (this.onComboChange) {
            this.onComboChange(this.combo, this.multiplier);
        }
    }
    
    /**
     * Reset combo
     */
    resetCombo() {
        this.combo = 0;
        this.multiplier = 1;
        
        if (this.onComboChange) {
            this.onComboChange(this.combo, this.multiplier);
        }
    }
    
    /**
     * Check for milestone achievements
     */
    checkMilestones() {
        const newIndex = ENDLESS_CONFIG.checkMilestone(this.distance, this.lastMilestoneIndex);
        
        if (newIndex > this.lastMilestoneIndex) {
            const milestone = ENDLESS_CONFIG.milestones[newIndex];
            this.lastMilestoneIndex = newIndex;
            this.addMilestoneBonus(milestone);
        }
    }
    
    /**
     * Check if current score beats highscore
     */
    checkHighscore() {
        if (!this.isNewHighscore && this.score > this.highscore) {
            this.isNewHighscore = true;
            
            if (this.onHighscore) {
                this.onHighscore(this.score);
            }
        }
    }
    
    /**
     * Save highscore to localStorage
     */
    saveHighscore() {
        if (this.score > this.highscore) {
            this.highscore = this.score;
            
            try {
                const data = {
                    score: this.score,
                    distance: Math.floor(this.distance),
                    maxCombo: this.maxCombo,
                    date: new Date().toISOString(),
                };
                localStorage.setItem(SCORE_CONFIG.STORAGE_KEY, JSON.stringify(data));
            } catch (e) {
                console.warn('Could not save highscore:', e);
            }
        }
        
        return this.highscore;
    }
    
    /**
     * Load highscore from localStorage
     */
    loadHighscore() {
        try {
            const data = localStorage.getItem(SCORE_CONFIG.STORAGE_KEY);
            if (data) {
                const parsed = JSON.parse(data);
                return parsed.score || 0;
            }
        } catch (e) {
            console.warn('Could not load highscore:', e);
        }
        return 0;
    }
    
    /**
     * Get full highscore data
     */
    getHighscoreData() {
        try {
            const data = localStorage.getItem(SCORE_CONFIG.STORAGE_KEY);
            if (data) {
                return JSON.parse(data);
            }
        } catch (e) {
            console.warn('Could not load highscore data:', e);
        }
        return null;
    }
    
    /**
     * Show floating score text
     */
    showFloatingScore(amount, label, color) {
        if (!this.scene || !this.scene.add) return;
        
        const x = GAME_CONFIG.WIDTH / 2;
        const y = GAME_CONFIG.HEIGHT / 2 - 50;
        
        // Create text
        const text = this.scene.add.text(x, y, `${label}\n+${amount}`, {
            fontFamily: UI_CONFIG.FONT_FAMILY,
            fontSize: '24px',
            color: '#' + color.toString(16).padStart(6, '0'),
            align: 'center',
            stroke: '#000000',
            strokeThickness: 4,
        }).setOrigin(0.5).setDepth(1000);
        
        // Animate
        this.scene.tweens.add({
            targets: text,
            y: y - 100,
            alpha: 0,
            scale: 1.5,
            duration: 1000,
            ease: 'Power2',
            onComplete: () => text.destroy(),
        });
    }
    
    /**
     * Show milestone celebration
     */
    showMilestoneText(message, bonus) {
        if (!this.scene || !this.scene.add) return;
        
        const x = GAME_CONFIG.WIDTH / 2;
        const y = GAME_CONFIG.HEIGHT / 2;
        
        // Create big text
        const text = this.scene.add.text(x, y, message, {
            fontFamily: UI_CONFIG.FONT_FAMILY,
            fontSize: '48px',
            color: GAME_CONFIG.HEX.YELLOW,
            align: 'center',
            stroke: '#000000',
            strokeThickness: 6,
        }).setOrigin(0.5).setDepth(1001).setAlpha(0).setScale(0.5);
        
        // Bonus text
        const bonusText = this.scene.add.text(x, y + 60, `+${bonus}`, {
            fontFamily: UI_CONFIG.FONT_FAMILY,
            fontSize: '32px',
            color: GAME_CONFIG.HEX.CYAN,
            align: 'center',
            stroke: '#000000',
            strokeThickness: 4,
        }).setOrigin(0.5).setDepth(1001).setAlpha(0);
        
        // Animate in
        this.scene.tweens.add({
            targets: text,
            alpha: 1,
            scale: 1,
            duration: 300,
            ease: 'Back.easeOut',
        });
        
        this.scene.tweens.add({
            targets: bonusText,
            alpha: 1,
            duration: 300,
            delay: 200,
        });
        
        // Animate out
        this.scene.tweens.add({
            targets: [text, bonusText],
            alpha: 0,
            y: '-=50',
            duration: 500,
            delay: 1500,
            onComplete: () => {
                text.destroy();
                bonusText.destroy();
            },
        });
        
        // Screen flash
        if (this.scene.cameras && this.scene.cameras.main) {
            this.scene.cameras.main.flash(200, 255, 255, 0, 0.3);
        }
    }
    
    /**
     * Get final stats for game over
     */
    getFinalStats() {
        return {
            score: this.score,
            distance: Math.floor(this.distance),
            maxCombo: this.maxCombo,
            drifts: this.drifts,
            nearMisses: this.nearMisses,
            powerUpsCollected: this.powerUpsCollected,
            isNewHighscore: this.isNewHighscore,
            highscore: this.highscore,
        };
    }
    
    /**
     * Cleanup
     */
    destroy() {
        if (this.comboTimer) {
            this.comboTimer.remove();
            this.comboTimer = null;
        }
        this.onScoreChange = null;
        this.onComboChange = null;
        this.onMilestone = null;
        this.onHighscore = null;
    }
}
