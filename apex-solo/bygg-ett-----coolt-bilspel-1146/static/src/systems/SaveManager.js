/**
 * SaveManager.js
 * Comprehensive save/load system with cloud sync support
 * Handles game state persistence, profiles, and backup/restore
 */

class SaveManager {
    constructor() {
        // Save configuration
        this.storagePrefix = 'gravshift_';
        this.currentVersion = '1.0.0';
        this.autoSaveInterval = 60000; // 1 minute
        
        // Profile system
        this.currentProfile = null;
        this.profiles = [];
        this.maxProfiles = 5;
        
        // Save state
        this.isDirty = false;
        this.lastSaveTime = 0;
        this.autoSaveEnabled = true;
        this.autoSaveTimer = null;
        
        // Data categories
        this.saveCategories = [
            'settings',
            'progress',
            'stats',
            'achievements',
            'garage',
            'inventory',
            'replays',
            'challenges',
            'unlocks'
        ];
        
        // Cloud sync (mock)
        this.cloudSyncEnabled = false;
        this.lastSyncTime = 0;
        this.pendingSync = false;
        
        // Event callbacks
        this.onSave = null;
        this.onLoad = null;
        this.onError = null;
        
        // Initialize
        this.initialize();
    }
    
    /**
     * Initialize save manager
     */
    initialize() {
        // Load profiles list
        this.loadProfiles();
        
        // Set up auto-save
        this.setupAutoSave();
        
        // Load last used profile
        this.loadLastProfile();
        
        console.log('SaveManager initialized');
    }
    
    /**
     * Setup auto-save timer
     */
    setupAutoSave() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
        }
        
        if (this.autoSaveEnabled) {
            this.autoSaveTimer = setInterval(() => {
                if (this.isDirty) {
                    this.autoSave();
                }
            }, this.autoSaveInterval);
        }
    }
    
    /**
     * Load profiles list
     */
    loadProfiles() {
        try {
            const saved = localStorage.getItem(this.storagePrefix + 'profiles');
            if (saved) {
                this.profiles = JSON.parse(saved);
            } else {
                this.profiles = [];
            }
        } catch (e) {
            console.error('Failed to load profiles:', e);
            this.profiles = [];
        }
    }
    
    /**
     * Save profiles list
     */
    saveProfiles() {
        try {
            localStorage.setItem(this.storagePrefix + 'profiles', JSON.stringify(this.profiles));
        } catch (e) {
            console.error('Failed to save profiles:', e);
        }
    }
    
    /**
     * Load last used profile
     */
    loadLastProfile() {
        try {
            const lastProfileId = localStorage.getItem(this.storagePrefix + 'last_profile');
            if (lastProfileId && this.profiles.find(p => p.id === lastProfileId)) {
                this.loadProfile(lastProfileId);
            } else if (this.profiles.length > 0) {
                this.loadProfile(this.profiles[0].id);
            } else {
                // Create default profile
                this.createProfile('Player');
            }
        } catch (e) {
            console.error('Failed to load last profile:', e);
            if (this.profiles.length === 0) {
                this.createProfile('Player');
            }
        }
    }
    
    /**
     * Create a new profile
     */
    createProfile(name) {
        if (this.profiles.length >= this.maxProfiles) {
            console.warn('Maximum profiles reached');
            return null;
        }
        
        const profile = {
            id: this.generateId(),
            name: name,
            created: Date.now(),
            lastPlayed: Date.now(),
            playTime: 0,
            level: 1,
            coins: 0,
            version: this.currentVersion
        };
        
        this.profiles.push(profile);
        this.saveProfiles();
        
        // Initialize profile data
        this.initializeProfileData(profile.id);
        
        // Switch to new profile
        this.loadProfile(profile.id);
        
        return profile;
    }
    
    /**
     * Initialize empty data for a profile
     */
    initializeProfileData(profileId) {
        const defaultData = {
            settings: this.getDefaultSettings(),
            progress: this.getDefaultProgress(),
            stats: this.getDefaultStats(),
            achievements: [],
            garage: this.getDefaultGarage(),
            inventory: this.getDefaultInventory(),
            replays: [],
            challenges: {},
            unlocks: this.getDefaultUnlocks()
        };
        
        this.saveCategories.forEach(category => {
            const key = this.getStorageKey(profileId, category);
            localStorage.setItem(key, JSON.stringify(defaultData[category]));
        });
    }
    
    /**
     * Get default settings
     */
    getDefaultSettings() {
        return {
            audio: {
                masterVolume: 0.8,
                musicVolume: 0.7,
                sfxVolume: 0.9,
                muted: false
            },
            graphics: {
                quality: 'high',
                particles: true,
                screenShake: true,
                weatherEffects: true,
                vsync: true
            },
            controls: {
                sensitivity: 0.5,
                invertY: false,
                hapticFeedback: true,
                touchControls: 'buttons'
            },
            gameplay: {
                showTutorials: true,
                autoRestart: false,
                showGhost: true,
                hintFrequency: 'normal'
            },
            accessibility: {
                colorBlindMode: 'none',
                highContrast: false,
                reducedMotion: false,
                largeText: false
            }
        };
    }
    
    /**
     * Get default progress
     */
    getDefaultProgress() {
        return {
            currentLevel: 1,
            unlockedLevels: [1],
            levelScores: {},
            levelTimes: {},
            levelStars: {},
            tutorialCompleted: false,
            lastPlayedLevel: 1
        };
    }
    
    /**
     * Get default stats
     */
    getDefaultStats() {
        return {
            totalRaces: 0,
            totalWins: 0,
            totalDeaths: 0,
            totalDistance: 0,
            totalScore: 0,
            totalPlayTime: 0,
            totalCoins: 0,
            totalPowerUps: 0,
            highestCombo: 0,
            longestDrift: 0,
            fastestLap: {},
            nearMisses: 0,
            perfectRuns: 0,
            sessionHistory: [],
            dailyStats: {}
        };
    }
    
    /**
     * Get default garage
     */
    getDefaultGarage() {
        return {
            ownedVehicles: ['racer'],
            currentVehicle: 'racer',
            vehicleUpgrades: {
                racer: { speed: 0, handling: 0, boost: 0, durability: 0 }
            },
            ownedSkins: ['default'],
            currentSkin: 'default',
            coins: 1000
        };
    }
    
    /**
     * Get default inventory
     */
    getDefaultInventory() {
        return {
            boosts: 3,
            shields: 2,
            continues: 1,
            doubleCoins: 0,
            scoreMultipliers: 0,
            revives: 1
        };
    }
    
    /**
     * Get default unlocks
     */
    getDefaultUnlocks() {
        return {
            levels: [1],
            vehicles: ['racer'],
            skins: ['default'],
            achievements: [],
            tracks: ['neon_highway'],
            modes: ['endless']
        };
    }
    
    /**
     * Load a profile
     */
    loadProfile(profileId) {
        const profile = this.profiles.find(p => p.id === profileId);
        if (!profile) {
            console.error(`Profile not found: ${profileId}`);
            return false;
        }
        
        this.currentProfile = profile;
        
        // Update last played
        profile.lastPlayed = Date.now();
        this.saveProfiles();
        
        // Store as last profile
        localStorage.setItem(this.storagePrefix + 'last_profile', profileId);
        
        // Trigger callback
        if (this.onLoad) {
            this.onLoad(profile);
        }
        
        console.log(`Loaded profile: ${profile.name}`);
        return true;
    }
    
    /**
     * Delete a profile
     */
    deleteProfile(profileId) {
        const index = this.profiles.findIndex(p => p.id === profileId);
        if (index === -1) return false;
        
        // Remove from list
        this.profiles.splice(index, 1);
        this.saveProfiles();
        
        // Delete profile data
        this.saveCategories.forEach(category => {
            const key = this.getStorageKey(profileId, category);
            localStorage.removeItem(key);
        });
        
        // Switch profile if current was deleted
        if (this.currentProfile && this.currentProfile.id === profileId) {
            if (this.profiles.length > 0) {
                this.loadProfile(this.profiles[0].id);
            } else {
                this.currentProfile = null;
            }
        }
        
        return true;
    }
    
    /**
     * Rename a profile
     */
    renameProfile(profileId, newName) {
        const profile = this.profiles.find(p => p.id === profileId);
        if (!profile) return false;
        
        profile.name = newName.slice(0, 20); // Max 20 chars
        this.saveProfiles();
        
        return true;
    }
    
    /**
     * Get storage key for category
     */
    getStorageKey(profileId, category) {
        return `${this.storagePrefix}${profileId}_${category}`;
    }
    
    /**
     * Save data to a category
     */
    saveData(category, data) {
        if (!this.currentProfile) {
            console.error('No profile loaded');
            return false;
        }
        
        if (!this.saveCategories.includes(category)) {
            console.error(`Invalid category: ${category}`);
            return false;
        }
        
        try {
            const key = this.getStorageKey(this.currentProfile.id, category);
            localStorage.setItem(key, JSON.stringify(data));
            
            this.isDirty = true;
            this.lastSaveTime = Date.now();
            
            if (this.onSave) {
                this.onSave(category, data);
            }
            
            return true;
        } catch (e) {
            console.error(`Failed to save ${category}:`, e);
            
            if (this.onError) {
                this.onError('save', category, e);
            }
            
            return false;
        }
    }
    
    /**
     * Load data from a category
     */
    loadData(category) {
        if (!this.currentProfile) {
            console.error('No profile loaded');
            return null;
        }
        
        if (!this.saveCategories.includes(category)) {
            console.error(`Invalid category: ${category}`);
            return null;
        }
        
        try {
            const key = this.getStorageKey(this.currentProfile.id, category);
            const saved = localStorage.getItem(key);
            
            if (saved) {
                return JSON.parse(saved);
            }
            
            // Return default if not found
            return this.getDefaultForCategory(category);
        } catch (e) {
            console.error(`Failed to load ${category}:`, e);
            
            if (this.onError) {
                this.onError('load', category, e);
            }
            
            return this.getDefaultForCategory(category);
        }
    }
    
    /**
     * Get default data for category
     */
    getDefaultForCategory(category) {
        switch (category) {
            case 'settings': return this.getDefaultSettings();
            case 'progress': return this.getDefaultProgress();
            case 'stats': return this.getDefaultStats();
            case 'achievements': return [];
            case 'garage': return this.getDefaultGarage();
            case 'inventory': return this.getDefaultInventory();
            case 'replays': return [];
            case 'challenges': return {};
            case 'unlocks': return this.getDefaultUnlocks();
            default: return null;
        }
    }
    
    /**
     * Update specific fields in a category
     */
    updateData(category, updates) {
        const data = this.loadData(category);
        if (data === null) return false;
        
        // Deep merge updates
        const merged = this.deepMerge(data, updates);
        return this.saveData(category, merged);
    }
    
    /**
     * Deep merge two objects
     */
    deepMerge(target, source) {
        const result = { ...target };
        
        for (const key of Object.keys(source)) {
            if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
                result[key] = this.deepMerge(target[key] || {}, source[key]);
            } else {
                result[key] = source[key];
            }
        }
        
        return result;
    }
    
    /**
     * Auto-save all dirty data
     */
    autoSave() {
        if (!this.currentProfile) return;
        
        console.log('Auto-saving...');
        this.isDirty = false;
        
        // Update profile play time
        this.currentProfile.playTime += Date.now() - this.lastSaveTime;
        this.saveProfiles();
        
        // Trigger cloud sync if enabled
        if (this.cloudSyncEnabled) {
            this.syncToCloud();
        }
    }
    
    /**
     * Manual save all data
     */
    saveAll() {
        if (!this.currentProfile) return false;
        
        try {
            this.isDirty = false;
            this.lastSaveTime = Date.now();
            
            // Update profile
            this.currentProfile.lastPlayed = Date.now();
            this.saveProfiles();
            
            console.log('All data saved');
            return true;
        } catch (e) {
            console.error('Failed to save all:', e);
            return false;
        }
    }
    
    /**
     * Export profile data for backup
     */
    exportProfile(profileId = null) {
        const id = profileId || (this.currentProfile ? this.currentProfile.id : null);
        if (!id) return null;
        
        const profile = this.profiles.find(p => p.id === id);
        if (!profile) return null;
        
        const exportData = {
            version: this.currentVersion,
            exportDate: new Date().toISOString(),
            profile: profile,
            data: {}
        };
        
        // Collect all category data
        this.saveCategories.forEach(category => {
            const key = this.getStorageKey(id, category);
            const saved = localStorage.getItem(key);
            if (saved) {
                exportData.data[category] = JSON.parse(saved);
            }
        });
        
        return exportData;
    }
    
    /**
     * Export profile as JSON string
     */
    exportProfileAsString(profileId = null) {
        const data = this.exportProfile(profileId);
        if (!data) return null;
        return JSON.stringify(data, null, 2);
    }
    
    /**
     * Export profile as downloadable file
     */
    downloadProfileBackup(profileId = null) {
        const data = this.exportProfileAsString(profileId);
        if (!data) return false;
        
        const profile = this.profiles.find(p => p.id === (profileId || this.currentProfile?.id));
        const filename = `gravshift_backup_${profile?.name || 'profile'}_${Date.now()}.json`;
        
        const blob = new Blob([data], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        return true;
    }
    
    /**
     * Import profile from backup data
     */
    importProfile(importData, overwrite = false) {
        try {
            // Validate import data
            if (!importData.version || !importData.profile || !importData.data) {
                throw new Error('Invalid import data format');
            }
            
            // Check if profile already exists
            const existingIndex = this.profiles.findIndex(p => p.id === importData.profile.id);
            
            if (existingIndex !== -1 && !overwrite) {
                // Create new ID for imported profile
                importData.profile.id = this.generateId();
                importData.profile.name += ' (Imported)';
            }
            
            // Add or update profile
            if (existingIndex !== -1 && overwrite) {
                this.profiles[existingIndex] = importData.profile;
            } else if (this.profiles.length < this.maxProfiles) {
                this.profiles.push(importData.profile);
            } else {
                throw new Error('Maximum profiles reached');
            }
            
            this.saveProfiles();
            
            // Import category data
            this.saveCategories.forEach(category => {
                if (importData.data[category]) {
                    const key = this.getStorageKey(importData.profile.id, category);
                    localStorage.setItem(key, JSON.stringify(importData.data[category]));
                }
            });
            
            // Switch to imported profile
            this.loadProfile(importData.profile.id);
            
            return true;
        } catch (e) {
            console.error('Import failed:', e);
            
            if (this.onError) {
                this.onError('import', null, e);
            }
            
            return false;
        }
    }
    
    /**
     * Import profile from JSON string
     */
    importProfileFromString(jsonString, overwrite = false) {
        try {
            const data = JSON.parse(jsonString);
            return this.importProfile(data, overwrite);
        } catch (e) {
            console.error('Failed to parse import string:', e);
            return false;
        }
    }
    
    /**
     * Import profile from file
     */
    importProfileFromFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            
            reader.onload = (e) => {
                const result = this.importProfileFromString(e.target.result);
                resolve(result);
            };
            
            reader.onerror = () => {
                reject(new Error('Failed to read file'));
            };
            
            reader.readAsText(file);
        });
    }
    
    /**
     * Reset profile to defaults
     */
    resetProfile(profileId = null, categories = null) {
        const id = profileId || (this.currentProfile ? this.currentProfile.id : null);
        if (!id) return false;
        
        const categoriesToReset = categories || this.saveCategories;
        
        categoriesToReset.forEach(category => {
            const defaultData = this.getDefaultForCategory(category);
            if (defaultData !== null) {
                const key = this.getStorageKey(id, category);
                localStorage.setItem(key, JSON.stringify(defaultData));
            }
        });
        
        return true;
    }
    
    /**
     * Get storage usage info
     */
    getStorageInfo() {
        let totalSize = 0;
        let profileSizes = {};
        
        this.profiles.forEach(profile => {
            let profileSize = 0;
            
            this.saveCategories.forEach(category => {
                const key = this.getStorageKey(profile.id, category);
                const data = localStorage.getItem(key);
                if (data) {
                    profileSize += data.length;
                }
            });
            
            profileSizes[profile.id] = profileSize;
            totalSize += profileSize;
        });
        
        return {
            totalBytes: totalSize,
            totalKB: (totalSize / 1024).toFixed(2),
            totalMB: (totalSize / (1024 * 1024)).toFixed(4),
            profileSizes: profileSizes,
            profileCount: this.profiles.length,
            maxProfiles: this.maxProfiles
        };
    }
    
    /**
     * Cloud sync - save to cloud
     */
    async syncToCloud() {
        if (!this.cloudSyncEnabled || !this.currentProfile) return;
        
        const exportData = this.exportProfile();
        if (!exportData) return;
        
        this.pendingSync = true;
        
        // In production, this would send to a cloud server
        // For now, just simulate
        console.log('Syncing to cloud...');
        
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        this.lastSyncTime = Date.now();
        this.pendingSync = false;
        
        console.log('Cloud sync complete');
    }
    
    /**
     * Cloud sync - load from cloud
     */
    async syncFromCloud() {
        if (!this.cloudSyncEnabled) return null;
        
        // In production, this would fetch from a cloud server
        // For now, return null
        console.log('Fetching from cloud...');
        
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        return null;
    }
    
    /**
     * Enable/disable cloud sync
     */
    setCloudSync(enabled) {
        this.cloudSyncEnabled = enabled;
        
        if (enabled) {
            this.syncToCloud();
        }
    }
    
    /**
     * Generate unique ID
     */
    generateId() {
        return 'profile_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    /**
     * Get current profile
     */
    getCurrentProfile() {
        return this.currentProfile;
    }
    
    /**
     * Get all profiles
     */
    getAllProfiles() {
        return [...this.profiles];
    }
    
    /**
     * Check if profile exists
     */
    profileExists(profileId) {
        return this.profiles.some(p => p.id === profileId);
    }
    
    /**
     * Mark data as dirty (needs save)
     */
    markDirty() {
        this.isDirty = true;
    }
    
    /**
     * Clean up and destroy
     */
    destroy() {
        if (this.autoSaveTimer) {
            clearInterval(this.autoSaveTimer);
        }
        
        // Final save
        if (this.isDirty) {
            this.saveAll();
        }
    }
}

// Create singleton
if (typeof window !== 'undefined') {
    window.SaveManager = new SaveManager();
}
