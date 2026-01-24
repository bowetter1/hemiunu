/**
 * GRAVSHIFT - Achievement Manager
 * Tracks player achievements and unlockables
 */

class AchievementManager {
    constructor(scene) {
        this.scene = scene;
        this.achievements = {};
        this.unlockedAchievements = {};
        this.notifications = [];
        this.notificationQueue = [];
        
        // Track session stats
        this.sessionStats = {
            totalDistance: 0,
            totalScore: 0,
            obstaclesHit: 0,
            powerupsCollected: 0,
            perfectRuns: 0,
            nearMisses: 0,
            driftTime: 0,
            boostTime: 0,
            levelsCompleted: 0,
            starsEarned: 0,
        };
        
        // Load saved data
        this.loadProgress();
        
        // Define all achievements
        this.defineAchievements();
    }
    
    /**
     * Load saved achievement progress
     */
    loadProgress() {
        try {
            const data = localStorage.getItem('gravshift_achievements');
            if (data) {
                const saved = JSON.parse(data);
                this.unlockedAchievements = saved.unlocked || {};
                this.totalStats = saved.stats || this.createEmptyStats();
            } else {
                this.totalStats = this.createEmptyStats();
            }
        } catch (e) {
            console.warn('Could not load achievements');
            this.totalStats = this.createEmptyStats();
        }
    }
    
    /**
     * Create empty stats object
     */
    createEmptyStats() {
        return {
            totalDistance: 0,
            totalScore: 0,
            obstaclesHit: 0,
            obstaclesAvoided: 0,
            powerupsCollected: 0,
            perfectRuns: 0,
            nearMisses: 0,
            driftTime: 0,
            boostTime: 0,
            levelsCompleted: 0,
            starsEarned: 0,
            gamesPlayed: 0,
            deathCount: 0,
            checkpointsPassed: 0,
            maxCombo: 0,
            maxSpeed: 0,
            timePlayed: 0,
            endlessHighscore: 0,
            vehiclesUnlocked: 1,
            secretsFound: 0,
        };
    }
    
    /**
     * Save achievement progress
     */
    saveProgress() {
        try {
            const data = {
                unlocked: this.unlockedAchievements,
                stats: this.totalStats,
            };
            localStorage.setItem('gravshift_achievements', JSON.stringify(data));
        } catch (e) {
            console.warn('Could not save achievements');
        }
    }
    
    /**
     * Define all achievements
     */
    defineAchievements() {
        this.achievements = {
            // === BEGINNER ACHIEVEMENTS ===
            FIRST_RUN: {
                id: 'FIRST_RUN',
                name: 'First Contact',
                description: 'Complete your first level',
                icon: 'rocket',
                category: 'beginner',
                reward: 100,
                condition: (stats) => stats.levelsCompleted >= 1,
            },
            
            SPEED_DEMON: {
                id: 'SPEED_DEMON',
                name: 'Speed Demon',
                description: 'Reach maximum speed for the first time',
                icon: 'lightning',
                category: 'beginner',
                reward: 150,
                condition: (stats) => stats.maxSpeed >= 800,
            },
            
            COLLECTOR: {
                id: 'COLLECTOR',
                name: 'Collector',
                description: 'Collect 10 power-ups',
                icon: 'star',
                category: 'beginner',
                reward: 100,
                condition: (stats) => stats.powerupsCollected >= 10,
            },
            
            SURVIVOR: {
                id: 'SURVIVOR',
                name: 'Survivor',
                description: 'Complete a level without hitting any obstacles',
                icon: 'shield',
                category: 'beginner',
                reward: 200,
                condition: (stats) => stats.perfectRuns >= 1,
            },
            
            CHECKPOINT_CHAMP: {
                id: 'CHECKPOINT_CHAMP',
                name: 'Checkpoint Champion',
                description: 'Pass through 20 checkpoints',
                icon: 'flag',
                category: 'beginner',
                reward: 100,
                condition: (stats) => stats.checkpointsPassed >= 20,
            },
            
            // === INTERMEDIATE ACHIEVEMENTS ===
            MARATHON_RUNNER: {
                id: 'MARATHON_RUNNER',
                name: 'Marathon Runner',
                description: 'Travel a total of 50,000 meters',
                icon: 'road',
                category: 'intermediate',
                reward: 300,
                condition: (stats) => stats.totalDistance >= 50000,
            },
            
            SCORE_HUNTER: {
                id: 'SCORE_HUNTER',
                name: 'Score Hunter',
                description: 'Accumulate 100,000 total points',
                icon: 'trophy',
                category: 'intermediate',
                reward: 300,
                condition: (stats) => stats.totalScore >= 100000,
            },
            
            COMBO_MASTER: {
                id: 'COMBO_MASTER',
                name: 'Combo Master',
                description: 'Reach a combo of 50',
                icon: 'fire',
                category: 'intermediate',
                reward: 400,
                condition: (stats) => stats.maxCombo >= 50,
            },
            
            DRIFT_KING: {
                id: 'DRIFT_KING',
                name: 'Drift King',
                description: 'Drift for a total of 60 seconds',
                icon: 'swirl',
                category: 'intermediate',
                reward: 350,
                condition: (stats) => stats.driftTime >= 60000,
            },
            
            NEAR_MISS_PRO: {
                id: 'NEAR_MISS_PRO',
                name: 'Near Miss Pro',
                description: 'Get 100 near misses',
                icon: 'danger',
                category: 'intermediate',
                reward: 300,
                condition: (stats) => stats.nearMisses >= 100,
            },
            
            LEVEL_DESTROYER: {
                id: 'LEVEL_DESTROYER',
                name: 'Level Destroyer',
                description: 'Complete all 6 main levels',
                icon: 'crown',
                category: 'intermediate',
                reward: 500,
                condition: (stats) => stats.levelsCompleted >= 6,
            },
            
            STAR_COLLECTOR: {
                id: 'STAR_COLLECTOR',
                name: 'Star Collector',
                description: 'Earn 10 stars across all levels',
                icon: 'star',
                category: 'intermediate',
                reward: 400,
                condition: (stats) => stats.starsEarned >= 10,
            },
            
            BOOST_ADDICT: {
                id: 'BOOST_ADDICT',
                name: 'Boost Addict',
                description: 'Spend 5 minutes boosting',
                icon: 'rocket',
                category: 'intermediate',
                reward: 300,
                condition: (stats) => stats.boostTime >= 300000,
            },
            
            // === ADVANCED ACHIEVEMENTS ===
            PERFECTIONIST: {
                id: 'PERFECTIONIST',
                name: 'Perfectionist',
                description: 'Get 3 stars on any level',
                icon: 'star',
                category: 'advanced',
                reward: 600,
                condition: (stats) => stats.starsEarned >= 3 && stats.perfectRuns >= 1,
            },
            
            ULTRA_MARATHON: {
                id: 'ULTRA_MARATHON',
                name: 'Ultra Marathon',
                description: 'Travel 500,000 meters total',
                icon: 'globe',
                category: 'advanced',
                reward: 800,
                condition: (stats) => stats.totalDistance >= 500000,
            },
            
            MILLIONAIRE: {
                id: 'MILLIONAIRE',
                name: 'Millionaire',
                description: 'Accumulate 1,000,000 total points',
                icon: 'diamond',
                category: 'advanced',
                reward: 1000,
                condition: (stats) => stats.totalScore >= 1000000,
            },
            
            COMBO_LEGEND: {
                id: 'COMBO_LEGEND',
                name: 'Combo Legend',
                description: 'Reach a combo of 100',
                icon: 'fire',
                category: 'advanced',
                reward: 800,
                condition: (stats) => stats.maxCombo >= 100,
            },
            
            MASTER_DRIVER: {
                id: 'MASTER_DRIVER',
                name: 'Master Driver',
                description: 'Complete 5 perfect runs',
                icon: 'crown',
                category: 'advanced',
                reward: 1000,
                condition: (stats) => stats.perfectRuns >= 5,
            },
            
            ALL_STARS: {
                id: 'ALL_STARS',
                name: 'All Stars',
                description: 'Earn all 18 stars (3 stars on all levels)',
                icon: 'crown',
                category: 'advanced',
                reward: 2000,
                condition: (stats) => stats.starsEarned >= 18,
            },
            
            // === ENDLESS MODE ACHIEVEMENTS ===
            ENDLESS_BEGINNER: {
                id: 'ENDLESS_BEGINNER',
                name: 'Endless Beginner',
                description: 'Score 10,000 in endless mode',
                icon: 'infinity',
                category: 'endless',
                reward: 300,
                condition: (stats) => stats.endlessHighscore >= 10000,
            },
            
            ENDLESS_VETERAN: {
                id: 'ENDLESS_VETERAN',
                name: 'Endless Veteran',
                description: 'Score 50,000 in endless mode',
                icon: 'infinity',
                category: 'endless',
                reward: 600,
                condition: (stats) => stats.endlessHighscore >= 50000,
            },
            
            ENDLESS_MASTER: {
                id: 'ENDLESS_MASTER',
                name: 'Endless Master',
                description: 'Score 100,000 in endless mode',
                icon: 'infinity',
                category: 'endless',
                reward: 1000,
                condition: (stats) => stats.endlessHighscore >= 100000,
            },
            
            ENDLESS_LEGEND: {
                id: 'ENDLESS_LEGEND',
                name: 'Endless Legend',
                description: 'Score 250,000 in endless mode',
                icon: 'infinity',
                category: 'endless',
                reward: 2000,
                condition: (stats) => stats.endlessHighscore >= 250000,
            },
            
            // === SPECIAL ACHIEVEMENTS ===
            DEDICATED: {
                id: 'DEDICATED',
                name: 'Dedicated',
                description: 'Play for a total of 1 hour',
                icon: 'clock',
                category: 'special',
                reward: 500,
                condition: (stats) => stats.timePlayed >= 3600000,
            },
            
            VETERAN: {
                id: 'VETERAN',
                name: 'Veteran',
                description: 'Play 100 games',
                icon: 'badge',
                category: 'special',
                reward: 400,
                condition: (stats) => stats.gamesPlayed >= 100,
            },
            
            RESILIENT: {
                id: 'RESILIENT',
                name: 'Resilient',
                description: 'Crash 50 times but keep playing',
                icon: 'heart',
                category: 'special',
                reward: 300,
                condition: (stats) => stats.deathCount >= 50,
            },
            
            VEHICLE_COLLECTOR: {
                id: 'VEHICLE_COLLECTOR',
                name: 'Vehicle Collector',
                description: 'Unlock all vehicles',
                icon: 'car',
                category: 'special',
                reward: 1000,
                condition: (stats) => stats.vehiclesUnlocked >= 4,
            },
            
            EXPLORER: {
                id: 'EXPLORER',
                name: 'Explorer',
                description: 'Find all hidden secrets',
                icon: 'compass',
                category: 'special',
                reward: 1500,
                hidden: true,
                condition: (stats) => stats.secretsFound >= 6,
            },
        };
    }
    
    /**
     * Update stats from game session
     */
    updateStats(sessionData) {
        // Update session stats
        Object.keys(sessionData).forEach(key => {
            if (this.sessionStats.hasOwnProperty(key)) {
                this.sessionStats[key] += sessionData[key] || 0;
            }
        });
        
        // Update total stats
        Object.keys(sessionData).forEach(key => {
            if (this.totalStats.hasOwnProperty(key)) {
                if (key === 'maxCombo' || key === 'maxSpeed' || key === 'endlessHighscore') {
                    this.totalStats[key] = Math.max(this.totalStats[key], sessionData[key] || 0);
                } else {
                    this.totalStats[key] += sessionData[key] || 0;
                }
            }
        });
        
        // Check for new achievements
        this.checkAchievements();
        
        // Save progress
        this.saveProgress();
    }
    
    /**
     * Check for newly unlocked achievements
     */
    checkAchievements() {
        const newlyUnlocked = [];
        
        Object.values(this.achievements).forEach(achievement => {
            if (!this.unlockedAchievements[achievement.id]) {
                if (achievement.condition(this.totalStats)) {
                    this.unlockAchievement(achievement);
                    newlyUnlocked.push(achievement);
                }
            }
        });
        
        return newlyUnlocked;
    }
    
    /**
     * Unlock an achievement
     */
    unlockAchievement(achievement) {
        if (this.unlockedAchievements[achievement.id]) return;
        
        this.unlockedAchievements[achievement.id] = {
            unlockedAt: Date.now(),
            reward: achievement.reward,
        };
        
        // Queue notification
        this.queueNotification(achievement);
        
        // Emit event
        if (this.scene && this.scene.events) {
            this.scene.events.emit('achievementUnlocked', achievement);
        }
        
        this.saveProgress();
    }
    
    /**
     * Queue achievement notification
     */
    queueNotification(achievement) {
        this.notificationQueue.push(achievement);
    }
    
    /**
     * Get next notification to display
     */
    getNextNotification() {
        return this.notificationQueue.shift() || null;
    }
    
    /**
     * Check if achievement is unlocked
     */
    isUnlocked(achievementId) {
        return !!this.unlockedAchievements[achievementId];
    }
    
    /**
     * Get achievement progress percentage
     */
    getProgress(achievementId) {
        const achievement = this.achievements[achievementId];
        if (!achievement || !achievement.progressTracker) return null;
        
        return achievement.progressTracker(this.totalStats);
    }
    
    /**
     * Get all achievements grouped by category
     */
    getAchievementsByCategory() {
        const categories = {
            beginner: { name: 'Beginner', achievements: [] },
            intermediate: { name: 'Intermediate', achievements: [] },
            advanced: { name: 'Advanced', achievements: [] },
            endless: { name: 'Endless Mode', achievements: [] },
            special: { name: 'Special', achievements: [] },
        };
        
        Object.values(this.achievements).forEach(achievement => {
            const category = categories[achievement.category];
            if (category) {
                category.achievements.push({
                    ...achievement,
                    unlocked: this.isUnlocked(achievement.id),
                    unlockedAt: this.unlockedAchievements[achievement.id]?.unlockedAt,
                });
            }
        });
        
        return categories;
    }
    
    /**
     * Get total unlocked count
     */
    getUnlockedCount() {
        return Object.keys(this.unlockedAchievements).length;
    }
    
    /**
     * Get total achievement count
     */
    getTotalCount() {
        return Object.keys(this.achievements).length;
    }
    
    /**
     * Get completion percentage
     */
    getCompletionPercentage() {
        return Math.round((this.getUnlockedCount() / this.getTotalCount()) * 100);
    }
    
    /**
     * Get total rewards earned
     */
    getTotalRewardsEarned() {
        return Object.keys(this.unlockedAchievements).reduce((total, id) => {
            return total + (this.achievements[id]?.reward || 0);
        }, 0);
    }
    
    /**
     * Reset session stats (call at start of game)
     */
    resetSessionStats() {
        this.sessionStats = {
            totalDistance: 0,
            totalScore: 0,
            obstaclesHit: 0,
            powerupsCollected: 0,
            perfectRuns: 0,
            nearMisses: 0,
            driftTime: 0,
            boostTime: 0,
            levelsCompleted: 0,
            starsEarned: 0,
        };
    }
    
    /**
     * Get stats for display
     */
    getDisplayStats() {
        return {
            ...this.totalStats,
            achievementsUnlocked: this.getUnlockedCount(),
            totalAchievements: this.getTotalCount(),
            completionPercentage: this.getCompletionPercentage(),
            totalRewards: this.getTotalRewardsEarned(),
        };
    }
    
    /**
     * Reset all progress (for testing)
     */
    resetAll() {
        this.unlockedAchievements = {};
        this.totalStats = this.createEmptyStats();
        this.saveProgress();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.AchievementManager = AchievementManager;
}
