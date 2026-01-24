/**
 * GRAVSHIFT - Level Manager
 * Handles level loading, progression, and unlocks
 */

class LevelManager {
    constructor(scene) {
        this.scene = scene;
        this.currentLevel = null;
        this.currentLevelConfig = null;
        this.loadProgress();
    }
    
    loadProgress() {
        try {
            const data = localStorage.getItem(GAME_CONFIG.STORAGE.UNLOCKED_LEVELS);
            this.unlockedLevels = data ? JSON.parse(data) : { 1: true };
            
            const timesData = localStorage.getItem(GAME_CONFIG.STORAGE.BEST_TIMES);
            this.bestTimes = timesData ? JSON.parse(timesData) : {};
            
            const starsData = localStorage.getItem('gravshift_stars');
            this.levelStars = starsData ? JSON.parse(starsData) : {};
        } catch (e) {
            this.unlockedLevels = { 1: true };
            this.bestTimes = {};
            this.levelStars = {};
        }
    }
    
    saveProgress() {
        try {
            localStorage.setItem(GAME_CONFIG.STORAGE.UNLOCKED_LEVELS, JSON.stringify(this.unlockedLevels));
            localStorage.setItem(GAME_CONFIG.STORAGE.BEST_TIMES, JSON.stringify(this.bestTimes));
            localStorage.setItem('gravshift_stars', JSON.stringify(this.levelStars));
        } catch (e) {
            console.warn('Could not save level progress');
        }
    }
    
    /**
     * Check if level is unlocked
     */
    isLevelUnlocked(levelId) {
        if (levelId === 1) return true;
        return this.unlockedLevels[levelId] === true;
    }
    
    /**
     * Unlock a level
     */
    unlockLevel(levelId) {
        this.unlockedLevels[levelId] = true;
        this.saveProgress();
    }
    
    /**
     * Get level configuration
     */
    getLevelConfig(levelId) {
        return LEVELS[levelId] || null;
    }
    
    /**
     * Get all levels for a zone
     */
    getLevelsForZone(zoneName) {
        const zone = ZONES[zoneName];
        if (!zone) return [];
        
        return zone.levels.map(id => ({
            ...this.getLevelConfig(id),
            unlocked: this.isLevelUnlocked(id),
            stars: this.levelStars[id] || 0,
            bestTime: this.bestTimes[id] || null,
        }));
    }
    
    /**
     * Check if zone is unlocked
     */
    isZoneUnlocked(zoneName) {
        const zone = ZONES[zoneName];
        if (!zone || !zone.unlockRequirement) return true;
        
        const req = zone.unlockRequirement;
        const totalStars = this.getTotalStarsForZone(req.zone);
        return totalStars >= req.stars;
    }
    
    /**
     * Get total stars earned in a zone
     */
    getTotalStarsForZone(zoneName) {
        const zone = ZONES[zoneName];
        if (!zone) return 0;
        
        return zone.levels.reduce((total, levelId) => {
            return total + (this.levelStars[levelId] || 0);
        }, 0);
    }
    
    /**
     * Get total stars across all zones
     */
    getTotalStars() {
        return Object.values(this.levelStars).reduce((a, b) => a + b, 0);
    }
    
    /**
     * Load a level
     */
    loadLevel(levelId) {
        const config = this.getLevelConfig(levelId);
        if (!config) {
            console.error('Level not found:', levelId);
            return null;
        }
        
        this.currentLevel = levelId;
        this.currentLevelConfig = config;
        
        return config;
    }
    
    /**
     * Complete current level with stats
     */
    completeLevel(stats) {
        if (!this.currentLevel) return null;
        
        const levelId = this.currentLevel;
        const config = this.currentLevelConfig;
        
        // Calculate stars
        const stars = this.calculateStars(stats, config);
        
        // Update best stars
        if (stars > (this.levelStars[levelId] || 0)) {
            this.levelStars[levelId] = stars;
        }
        
        // Update best time
        if (stats.time && (!this.bestTimes[levelId] || stats.time < this.bestTimes[levelId])) {
            this.bestTimes[levelId] = stats.time;
        }
        
        // Unlock next level
        const nextLevelId = levelId + 1;
        if (LEVELS[nextLevelId] && stars >= 1) {
            this.unlockLevel(nextLevelId);
        }
        
        // Check zone unlocks
        this.checkZoneUnlocks();
        
        this.saveProgress();
        
        return {
            levelId,
            stars,
            newRecord: stats.time && stats.time === this.bestTimes[levelId],
            nextUnlocked: this.isLevelUnlocked(nextLevelId),
        };
    }
    
    /**
     * Calculate stars based on performance
     */
    calculateStars(stats, config) {
        if (!config || !config.stars) return 0;
        
        const { one, two, three } = config.stars;
        
        // Three stars - check all requirements
        if (stats.score >= three.score) {
            if (three.noHits && !stats.noHitRun) return 2;
            if (three.time && stats.time > three.time) return 2;
            if (three.perfectRun && !stats.noHitRun) return 2;
            return 3;
        }
        
        // Two stars
        if (stats.score >= two.score) return 2;
        
        // One star
        if (stats.score >= one.score) return 1;
        
        return 0;
    }
    
    /**
     * Check and apply zone unlocks
     */
    checkZoneUnlocks() {
        Object.entries(ZONES).forEach(([zoneName, zone]) => {
            if (this.isZoneUnlocked(zoneName)) {
                // Unlock first level of zone if zone just unlocked
                const firstLevel = zone.levels[0];
                if (firstLevel && typeof firstLevel === 'number') {
                    this.unlockLevel(firstLevel);
                }
            }
        });
    }
    
    /**
     * Get next available level
     */
    getNextLevel() {
        if (!this.currentLevel) return 1;
        
        const nextId = this.currentLevel + 1;
        if (LEVELS[nextId] && this.isLevelUnlocked(nextId)) {
            return nextId;
        }
        
        return null;
    }
    
    /**
     * Get zone info with unlock status
     */
    getAllZones() {
        return Object.entries(ZONES).map(([name, zone]) => ({
            name: zone.name,
            key: name,
            description: zone.description,
            color: zone.color,
            unlocked: this.isZoneUnlocked(name),
            totalStars: this.getTotalStarsForZone(name),
            maxStars: zone.levels.length * 3,
            levels: this.getLevelsForZone(name),
        }));
    }
    
    /**
     * Check if endless mode is unlocked
     */
    isEndlessUnlocked() {
        return this.isZoneUnlocked('beyond');
    }
    
    /**
     * Reset all progress (for testing)
     */
    resetProgress() {
        this.unlockedLevels = { 1: true };
        this.bestTimes = {};
        this.levelStars = {};
        this.saveProgress();
    }
    
    /**
     * Unlock all levels (cheat/debug)
     */
    unlockAll() {
        Object.keys(LEVELS).forEach(id => {
            this.unlockedLevels[id] = true;
        });
        this.saveProgress();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.LevelManager = LevelManager;
}
