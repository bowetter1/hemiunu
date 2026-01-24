/**
 * DailyChallengeManager.js
 * Daily challenge system with rotating objectives
 * Features streak bonuses, special rewards, and leaderboards
 */

class DailyChallengeManager {
    constructor() {
        // Challenge state
        this.currentChallenge = null;
        this.challengeProgress = {};
        this.completedToday = false;
        this.streak = 0;
        this.lastCompletedDate = null;
        
        // Challenge definitions
        this.challengeTypes = this.defineChallengeTypes();
        this.modifiers = this.defineModifiers();
        
        // Rewards
        this.baseReward = 1000;
        this.streakMultipliers = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5];
        
        // Load state
        this.loadState();
        
        // Check and generate new challenge if needed
        this.checkAndGenerateChallenge();
    }
    
    /**
     * Define all challenge types
     */
    defineChallengeTypes() {
        return {
            // Distance challenges
            'distance_run': {
                id: 'distance_run',
                name: 'Distance Runner',
                description: 'Travel {target} meters in a single run',
                icon: '📏',
                category: 'distance',
                difficulty: 'normal',
                targetRange: [5000, 15000],
                progressKey: 'distance',
                format: (v) => `${v.toLocaleString()} m`
            },
            'total_distance': {
                id: 'total_distance',
                name: 'Marathon',
                description: 'Travel {target} meters total today',
                icon: '🏃',
                category: 'distance',
                difficulty: 'easy',
                targetRange: [10000, 30000],
                progressKey: 'totalDistance',
                cumulative: true,
                format: (v) => `${v.toLocaleString()} m`
            },
            
            // Score challenges
            'score_single': {
                id: 'score_single',
                name: 'High Scorer',
                description: 'Score {target} points in a single run',
                icon: '⭐',
                category: 'score',
                difficulty: 'normal',
                targetRange: [100000, 300000],
                progressKey: 'score',
                format: (v) => v.toLocaleString()
            },
            'total_score': {
                id: 'total_score',
                name: 'Point Collector',
                description: 'Earn {target} points total today',
                icon: '💰',
                category: 'score',
                difficulty: 'easy',
                targetRange: [200000, 600000],
                progressKey: 'totalScore',
                cumulative: true,
                format: (v) => v.toLocaleString()
            },
            
            // Combo challenges
            'max_combo': {
                id: 'max_combo',
                name: 'Combo Master',
                description: 'Reach a {target}x combo',
                icon: '🔥',
                category: 'combo',
                difficulty: 'hard',
                targetRange: [50, 150],
                progressKey: 'maxCombo',
                format: (v) => `${v}x`
            },
            'combo_chains': {
                id: 'combo_chains',
                name: 'Chain Reactor',
                description: 'Build {target} combos of 20x or higher',
                icon: '⛓️',
                category: 'combo',
                difficulty: 'normal',
                targetRange: [3, 10],
                progressKey: 'comboChains',
                cumulative: true,
                format: (v) => v.toString()
            },
            
            // Collection challenges
            'collect_powerups': {
                id: 'collect_powerups',
                name: 'Power Hunter',
                description: 'Collect {target} power-ups',
                icon: '⚡',
                category: 'collection',
                difficulty: 'easy',
                targetRange: [20, 50],
                progressKey: 'powerupsCollected',
                cumulative: true,
                format: (v) => v.toString()
            },
            'collect_coins': {
                id: 'collect_coins',
                name: 'Coin Magnet',
                description: 'Collect {target} coins',
                icon: '🪙',
                category: 'collection',
                difficulty: 'easy',
                targetRange: [100, 300],
                progressKey: 'coinsCollected',
                cumulative: true,
                format: (v) => v.toString()
            },
            'collect_specific_powerup': {
                id: 'collect_specific_powerup',
                name: '{powerup} Seeker',
                description: 'Collect {target} {powerup} power-ups',
                icon: '🎯',
                category: 'collection',
                difficulty: 'normal',
                targetRange: [5, 15],
                progressKey: 'specificPowerup',
                cumulative: true,
                powerupOptions: ['BOOST', 'SHIELD', 'SLOWMO', 'MAGNET', 'GHOST'],
                format: (v) => v.toString()
            },
            
            // Skill challenges
            'near_misses': {
                id: 'near_misses',
                name: 'Daredevil',
                description: 'Perform {target} near misses',
                icon: '😰',
                category: 'skill',
                difficulty: 'hard',
                targetRange: [20, 50],
                progressKey: 'nearMisses',
                cumulative: true,
                format: (v) => v.toString()
            },
            'drift_time': {
                id: 'drift_time',
                name: 'Drift King',
                description: 'Drift for {target} seconds total',
                icon: '🌀',
                category: 'skill',
                difficulty: 'normal',
                targetRange: [30, 90],
                progressKey: 'driftTime',
                cumulative: true,
                format: (v) => `${v.toFixed(1)}s`
            },
            'perfect_runs': {
                id: 'perfect_runs',
                name: 'Untouchable',
                description: 'Complete {target} runs without taking damage',
                icon: '✨',
                category: 'skill',
                difficulty: 'hard',
                targetRange: [1, 3],
                progressKey: 'perfectRuns',
                cumulative: true,
                format: (v) => v.toString()
            },
            
            // Level challenges
            'complete_level': {
                id: 'complete_level',
                name: 'Level Conqueror',
                description: 'Complete Level {level}',
                icon: '🏆',
                category: 'level',
                difficulty: 'normal',
                targetRange: [1, 1],
                levelRange: [1, 10],
                progressKey: 'levelComplete',
                format: (v) => v ? 'Complete' : 'Incomplete'
            },
            'level_score': {
                id: 'level_score',
                name: 'Level Master',
                description: 'Score {target} on Level {level}',
                icon: '👑',
                category: 'level',
                difficulty: 'hard',
                targetRange: [150000, 400000],
                levelRange: [1, 10],
                progressKey: 'levelScore',
                format: (v) => v.toLocaleString()
            },
            
            // Survival challenges
            'survive_time': {
                id: 'survive_time',
                name: 'Survivor',
                description: 'Survive for {target} seconds in a single run',
                icon: '⏱️',
                category: 'survival',
                difficulty: 'normal',
                targetRange: [60, 180],
                progressKey: 'survivalTime',
                format: (v) => `${v}s`
            },
            'total_runs': {
                id: 'total_runs',
                name: 'Persistent',
                description: 'Complete {target} runs today',
                icon: '🔄',
                category: 'survival',
                difficulty: 'easy',
                targetRange: [5, 15],
                progressKey: 'runsCompleted',
                cumulative: true,
                format: (v) => v.toString()
            },
            
            // Special challenges
            'no_boost': {
                id: 'no_boost',
                name: 'Natural Speed',
                description: 'Travel {target} meters without using boost',
                icon: '🚫',
                category: 'special',
                difficulty: 'hard',
                targetRange: [3000, 8000],
                progressKey: 'noBoostDistance',
                constraint: 'no_boost',
                format: (v) => `${v.toLocaleString()} m`
            },
            'ghost_only': {
                id: 'ghost_only',
                name: 'Phantom',
                description: 'Pass through {target} obstacles using Ghost power-up',
                icon: '👻',
                category: 'special',
                difficulty: 'normal',
                targetRange: [10, 30],
                progressKey: 'ghostPasses',
                cumulative: true,
                format: (v) => v.toString()
            }
        };
    }
    
    /**
     * Define challenge modifiers
     */
    defineModifiers() {
        return {
            'double_speed': {
                id: 'double_speed',
                name: 'Double Speed',
                description: 'Game runs at 2x speed',
                icon: '⚡',
                multiplier: 1.5
            },
            'reduced_visibility': {
                id: 'reduced_visibility',
                name: 'Fog',
                description: 'Reduced visibility ahead',
                icon: '🌫️',
                multiplier: 1.3
            },
            'inverted_controls': {
                id: 'inverted_controls',
                name: 'Inverted',
                description: 'Left and right controls are swapped',
                icon: '🔄',
                multiplier: 1.4
            },
            'no_powerups': {
                id: 'no_powerups',
                name: 'Bare Bones',
                description: 'No power-ups spawn',
                icon: '🚫',
                multiplier: 1.5
            },
            'extra_obstacles': {
                id: 'extra_obstacles',
                name: 'Chaos',
                description: 'More obstacles than usual',
                icon: '💥',
                multiplier: 1.4
            },
            'time_pressure': {
                id: 'time_pressure',
                name: 'Rush Hour',
                description: 'Must be completed within time limit',
                icon: '⏰',
                multiplier: 1.3
            }
        };
    }
    
    /**
     * Load challenge state from storage
     */
    loadState() {
        try {
            const saved = localStorage.getItem('gravshift_daily_challenge');
            if (saved) {
                const data = JSON.parse(saved);
                
                this.currentChallenge = data.currentChallenge;
                this.challengeProgress = data.challengeProgress || {};
                this.completedToday = data.completedToday || false;
                this.streak = data.streak || 0;
                this.lastCompletedDate = data.lastCompletedDate;
            }
        } catch (e) {
            console.error('Failed to load daily challenge state:', e);
        }
    }
    
    /**
     * Save challenge state
     */
    saveState() {
        try {
            const data = {
                currentChallenge: this.currentChallenge,
                challengeProgress: this.challengeProgress,
                completedToday: this.completedToday,
                streak: this.streak,
                lastCompletedDate: this.lastCompletedDate
            };
            localStorage.setItem('gravshift_daily_challenge', JSON.stringify(data));
        } catch (e) {
            console.error('Failed to save daily challenge state:', e);
        }
    }
    
    /**
     * Check if we need a new challenge and generate if so
     */
    checkAndGenerateChallenge() {
        const today = this.getTodayString();
        
        // Check if current challenge is from today
        if (this.currentChallenge && this.currentChallenge.date === today) {
            return; // Challenge is still valid
        }
        
        // Check streak
        const yesterday = this.getYesterdayString();
        if (this.lastCompletedDate !== yesterday && this.lastCompletedDate !== today) {
            // Streak broken
            this.streak = 0;
        }
        
        // Generate new challenge
        this.generateNewChallenge();
    }
    
    /**
     * Generate a new daily challenge
     */
    generateNewChallenge() {
        const today = this.getTodayString();
        
        // Use date as seed for consistent daily challenge
        const seed = this.dateToSeed(today);
        
        // Select challenge type based on seed
        const typeKeys = Object.keys(this.challengeTypes);
        const typeIndex = seed % typeKeys.length;
        const challengeType = this.challengeTypes[typeKeys[typeIndex]];
        
        // Calculate target based on difficulty and seed
        const targetMin = challengeType.targetRange[0];
        const targetMax = challengeType.targetRange[1];
        const targetRange = targetMax - targetMin;
        const target = Math.floor(targetMin + (((seed * 7) % 100) / 100) * targetRange);
        
        // Select modifier (30% chance)
        let modifier = null;
        if ((seed % 10) < 3) {
            const modKeys = Object.keys(this.modifiers);
            const modIndex = (seed * 3) % modKeys.length;
            modifier = this.modifiers[modKeys[modIndex]];
        }
        
        // Select level if needed
        let level = null;
        if (challengeType.levelRange) {
            const levelMin = challengeType.levelRange[0];
            const levelMax = challengeType.levelRange[1];
            level = levelMin + ((seed * 11) % (levelMax - levelMin + 1));
        }
        
        // Select power-up if needed
        let specificPowerup = null;
        if (challengeType.powerupOptions) {
            specificPowerup = challengeType.powerupOptions[(seed * 13) % challengeType.powerupOptions.length];
        }
        
        // Calculate reward
        const difficultyMultiplier = {
            'easy': 0.8,
            'normal': 1.0,
            'hard': 1.5
        }[challengeType.difficulty] || 1.0;
        
        const modifierMultiplier = modifier ? modifier.multiplier : 1.0;
        const streakMultiplier = this.streakMultipliers[Math.min(this.streak, this.streakMultipliers.length - 1)];
        
        const reward = Math.floor(this.baseReward * difficultyMultiplier * modifierMultiplier * streakMultiplier);
        
        // Build challenge object
        this.currentChallenge = {
            date: today,
            type: challengeType,
            target: target,
            modifier: modifier,
            level: level,
            specificPowerup: specificPowerup,
            reward: reward,
            name: this.formatChallengeName(challengeType, level, specificPowerup),
            description: this.formatChallengeDescription(challengeType, target, level, specificPowerup),
            seed: seed
        };
        
        // Reset progress
        this.challengeProgress = {};
        this.completedToday = false;
        
        this.saveState();
    }
    
    /**
     * Format challenge name with variables
     */
    formatChallengeName(type, level, powerup) {
        let name = type.name;
        if (level) name = name.replace('{level}', level);
        if (powerup) name = name.replace('{powerup}', powerup);
        return name;
    }
    
    /**
     * Format challenge description with variables
     */
    formatChallengeDescription(type, target, level, powerup) {
        let desc = type.description;
        desc = desc.replace('{target}', type.format(target));
        if (level) desc = desc.replace('{level}', level);
        if (powerup) desc = desc.replace('{powerup}', powerup);
        return desc;
    }
    
    /**
     * Report progress on current challenge
     */
    reportProgress(data) {
        if (!this.currentChallenge || this.completedToday) return;
        
        const type = this.currentChallenge.type;
        const progressKey = type.progressKey;
        
        // Update progress
        if (type.cumulative) {
            // Add to cumulative progress
            const newValue = data[progressKey] || 0;
            this.challengeProgress[progressKey] = (this.challengeProgress[progressKey] || 0) + newValue;
        } else {
            // Take best value
            const newValue = data[progressKey] || 0;
            this.challengeProgress[progressKey] = Math.max(this.challengeProgress[progressKey] || 0, newValue);
        }
        
        // Check for level-specific challenges
        if (this.currentChallenge.level && data.levelId) {
            if (data.levelId !== `level_${this.currentChallenge.level}`) {
                return; // Wrong level
            }
        }
        
        // Check for powerup-specific challenges
        if (this.currentChallenge.specificPowerup && data.powerupType) {
            if (data.powerupType !== this.currentChallenge.specificPowerup) {
                return; // Wrong powerup
            }
        }
        
        // Check completion
        this.checkCompletion();
        
        this.saveState();
    }
    
    /**
     * Check if challenge is completed
     */
    checkCompletion() {
        if (!this.currentChallenge || this.completedToday) return false;
        
        const type = this.currentChallenge.type;
        const progress = this.challengeProgress[type.progressKey] || 0;
        const target = this.currentChallenge.target;
        
        if (progress >= target) {
            this.completeChallenge();
            return true;
        }
        
        return false;
    }
    
    /**
     * Complete the daily challenge
     */
    completeChallenge() {
        this.completedToday = true;
        this.streak++;
        this.lastCompletedDate = this.getTodayString();
        
        // Award reward
        const reward = this.currentChallenge.reward;
        this.awardReward(reward);
        
        this.saveState();
        
        // Trigger completion event
        if (typeof window !== 'undefined' && window.dispatchEvent) {
            window.dispatchEvent(new CustomEvent('dailyChallengeComplete', {
                detail: {
                    challenge: this.currentChallenge,
                    reward: reward,
                    streak: this.streak
                }
            }));
        }
    }
    
    /**
     * Award reward to player
     */
    awardReward(amount) {
        try {
            const saved = localStorage.getItem('gravshift_player_data');
            if (saved) {
                const data = JSON.parse(saved);
                data.coins = (data.coins || 0) + amount;
                localStorage.setItem('gravshift_player_data', JSON.stringify(data));
            }
        } catch (e) {
            console.error('Failed to award reward:', e);
        }
    }
    
    /**
     * Get current challenge info
     */
    getCurrentChallenge() {
        this.checkAndGenerateChallenge();
        
        if (!this.currentChallenge) return null;
        
        const type = this.currentChallenge.type;
        const progress = this.challengeProgress[type.progressKey] || 0;
        
        return {
            ...this.currentChallenge,
            progress: progress,
            progressFormatted: type.format(progress),
            targetFormatted: type.format(this.currentChallenge.target),
            percentage: Math.min(100, Math.floor((progress / this.currentChallenge.target) * 100)),
            completed: this.completedToday,
            streak: this.streak,
            timeRemaining: this.getTimeUntilReset()
        };
    }
    
    /**
     * Get time until daily reset
     */
    getTimeUntilReset() {
        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);
        
        const msRemaining = tomorrow.getTime() - now.getTime();
        
        const hours = Math.floor(msRemaining / (1000 * 60 * 60));
        const minutes = Math.floor((msRemaining % (1000 * 60 * 60)) / (1000 * 60));
        
        return { hours, minutes, total: msRemaining };
    }
    
    /**
     * Get streak information
     */
    getStreakInfo() {
        const currentMultiplier = this.streakMultipliers[Math.min(this.streak, this.streakMultipliers.length - 1)];
        const nextMultiplier = this.streakMultipliers[Math.min(this.streak + 1, this.streakMultipliers.length - 1)];
        
        return {
            current: this.streak,
            multiplier: currentMultiplier,
            nextMultiplier: nextMultiplier,
            maxStreak: this.streakMultipliers.length - 1,
            atMax: this.streak >= this.streakMultipliers.length - 1
        };
    }
    
    /**
     * Get challenge history
     */
    getHistory() {
        try {
            const saved = localStorage.getItem('gravshift_challenge_history');
            if (saved) {
                return JSON.parse(saved);
            }
        } catch (e) {
            console.error('Failed to load challenge history:', e);
        }
        return [];
    }
    
    /**
     * Save to history when challenge completes
     */
    saveToHistory() {
        if (!this.currentChallenge || !this.completedToday) return;
        
        try {
            const history = this.getHistory();
            
            history.unshift({
                date: this.currentChallenge.date,
                challengeName: this.currentChallenge.name,
                target: this.currentChallenge.target,
                reward: this.currentChallenge.reward,
                streak: this.streak
            });
            
            // Keep last 30 days
            while (history.length > 30) {
                history.pop();
            }
            
            localStorage.setItem('gravshift_challenge_history', JSON.stringify(history));
        } catch (e) {
            console.error('Failed to save challenge history:', e);
        }
    }
    
    /**
     * Get today's date string (YYYY-MM-DD)
     */
    getTodayString() {
        const now = new Date();
        return now.toISOString().split('T')[0];
    }
    
    /**
     * Get yesterday's date string
     */
    getYesterdayString() {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        return yesterday.toISOString().split('T')[0];
    }
    
    /**
     * Convert date string to seed number
     */
    dateToSeed(dateString) {
        let hash = 0;
        for (let i = 0; i < dateString.length; i++) {
            const char = dateString.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return Math.abs(hash);
    }
    
    /**
     * Force refresh challenge (for testing)
     */
    forceRefresh() {
        this.currentChallenge = null;
        this.checkAndGenerateChallenge();
    }
}

// Create singleton instance
if (typeof window !== 'undefined') {
    window.DailyChallengeManager = new DailyChallengeManager();
}
