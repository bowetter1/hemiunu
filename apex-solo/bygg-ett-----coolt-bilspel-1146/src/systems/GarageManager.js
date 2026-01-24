/**
 * GRAVSHIFT - Garage Manager
 * Handles vehicle purchases, upgrades, and customization
 */

class GarageManager {
    constructor(scene) {
        this.scene = scene;
        this.currency = 0;
        this.ownedVehicles = {};
        this.vehicleUpgrades = {};
        this.selectedVehicle = 'BALANCED';
        this.selectedSkin = 'default';
        
        // Vehicle definitions with prices
        this.vehicleShop = this.defineVehicleShop();
        
        // Upgrade definitions
        this.upgradeShop = this.defineUpgradeShop();
        
        // Skin definitions
        this.skinShop = this.defineSkinShop();
        
        // Load saved data
        this.loadProgress();
    }
    
    /**
     * Define vehicles available for purchase
     */
    defineVehicleShop() {
        return {
            BALANCED: {
                id: 'BALANCED',
                name: 'Striker',
                description: 'Well-rounded performance. Perfect for beginners.',
                price: 0, // Starter vehicle
                stats: {
                    maxSpeed: 750,
                    acceleration: 600,
                    handling: 3.5,
                    boost: 1.5,
                    nitro: 100,
                },
                color: 0xff00ff,
                unlockRequirement: null,
            },
            
            SPEEDER: {
                id: 'SPEEDER',
                name: 'Velocity',
                description: 'Built for speed. Hard to control but incredibly fast.',
                price: 5000,
                stats: {
                    maxSpeed: 950,
                    acceleration: 500,
                    handling: 2.5,
                    boost: 1.8,
                    nitro: 80,
                },
                color: 0x00ffff,
                unlockRequirement: {
                    type: 'achievement',
                    id: 'SPEED_DEMON',
                },
            },
            
            TANK: {
                id: 'TANK',
                name: 'Fortress',
                description: 'Slow but incredibly stable. Takes hits like a champ.',
                price: 4000,
                stats: {
                    maxSpeed: 600,
                    acceleration: 700,
                    handling: 4.5,
                    boost: 1.2,
                    nitro: 150,
                },
                color: 0xffff00,
                unlockRequirement: {
                    type: 'level',
                    id: 3,
                },
            },
            
            DRIFTER: {
                id: 'DRIFTER',
                name: 'Phantom',
                description: 'Master of controlled chaos. Drifting is second nature.',
                price: 6000,
                stats: {
                    maxSpeed: 800,
                    acceleration: 550,
                    handling: 2.0,
                    boost: 2.0,
                    nitro: 90,
                },
                color: 0x00ff00,
                unlockRequirement: {
                    type: 'achievement',
                    id: 'DRIFT_KING',
                },
            },
            
            RACER: {
                id: 'RACER',
                name: 'Apex',
                description: 'Competition-grade vehicle. Balanced for high-level play.',
                price: 8000,
                stats: {
                    maxSpeed: 850,
                    acceleration: 650,
                    handling: 3.2,
                    boost: 1.7,
                    nitro: 110,
                },
                color: 0xff8800,
                unlockRequirement: {
                    type: 'stars',
                    count: 12,
                },
            },
            
            LEGENDARY: {
                id: 'LEGENDARY',
                name: 'Omega',
                description: 'The ultimate racing machine. Reserved for legends.',
                price: 15000,
                stats: {
                    maxSpeed: 900,
                    acceleration: 700,
                    handling: 3.8,
                    boost: 1.9,
                    nitro: 120,
                },
                color: 0xffffff,
                unlockRequirement: {
                    type: 'achievement',
                    id: 'ALL_STARS',
                },
            },
        };
    }
    
    /**
     * Define upgrades available for purchase
     */
    defineUpgradeShop() {
        return {
            ENGINE: {
                id: 'ENGINE',
                name: 'Engine Upgrade',
                description: 'Increases max speed and acceleration',
                maxLevel: 5,
                basePrice: 1000,
                priceMultiplier: 1.5,
                perLevelBonus: {
                    maxSpeed: 30,
                    acceleration: 20,
                },
                icon: 'engine',
            },
            
            NITRO: {
                id: 'NITRO',
                name: 'Nitro Tank',
                description: 'Increases nitro capacity and regen rate',
                maxLevel: 5,
                basePrice: 800,
                priceMultiplier: 1.4,
                perLevelBonus: {
                    nitro: 15,
                    nitroRegen: 1,
                },
                icon: 'fuel',
            },
            
            HANDLING: {
                id: 'HANDLING',
                name: 'Steering System',
                description: 'Improves handling and turn response',
                maxLevel: 5,
                basePrice: 900,
                priceMultiplier: 1.4,
                perLevelBonus: {
                    handling: 0.3,
                },
                icon: 'wheel',
            },
            
            BOOST: {
                id: 'BOOST',
                name: 'Boost Enhancer',
                description: 'Increases boost power and duration',
                maxLevel: 5,
                basePrice: 1200,
                priceMultiplier: 1.6,
                perLevelBonus: {
                    boost: 0.08,
                },
                icon: 'lightning',
            },
            
            ARMOR: {
                id: 'ARMOR',
                name: 'Shield Generator',
                description: 'Extends invincibility duration after hits',
                maxLevel: 3,
                basePrice: 1500,
                priceMultiplier: 2.0,
                perLevelBonus: {
                    invincibilityTime: 500,
                },
                icon: 'shield',
            },
            
            MAGNET: {
                id: 'MAGNET',
                name: 'Score Magnet',
                description: 'Increases pickup radius for powerups',
                maxLevel: 3,
                basePrice: 1000,
                priceMultiplier: 1.8,
                perLevelBonus: {
                    pickupRadius: 20,
                },
                icon: 'magnet',
            },
        };
    }
    
    /**
     * Define skins available for purchase
     */
    defineSkinShop() {
        return {
            default: {
                id: 'default',
                name: 'Default',
                description: 'Standard vehicle appearance',
                price: 0,
                colors: null, // Uses vehicle default
            },
            
            neon_blue: {
                id: 'neon_blue',
                name: 'Neon Blue',
                description: 'Electric blue glow',
                price: 500,
                colors: {
                    primary: 0x00ffff,
                    secondary: 0x0088ff,
                    glow: 0x00ffff,
                },
            },
            
            neon_pink: {
                id: 'neon_pink',
                name: 'Neon Pink',
                description: 'Hot pink energy',
                price: 500,
                colors: {
                    primary: 0xff00ff,
                    secondary: 0xff0088,
                    glow: 0xff00ff,
                },
            },
            
            neon_green: {
                id: 'neon_green',
                name: 'Toxic Green',
                description: 'Radioactive green glow',
                price: 500,
                colors: {
                    primary: 0x00ff00,
                    secondary: 0x88ff00,
                    glow: 0x00ff00,
                },
            },
            
            neon_yellow: {
                id: 'neon_yellow',
                name: 'Solar Flare',
                description: 'Brilliant yellow shine',
                price: 500,
                colors: {
                    primary: 0xffff00,
                    secondary: 0xffaa00,
                    glow: 0xffff00,
                },
            },
            
            neon_red: {
                id: 'neon_red',
                name: 'Crimson',
                description: 'Deep red intensity',
                price: 500,
                colors: {
                    primary: 0xff0040,
                    secondary: 0xff0000,
                    glow: 0xff0040,
                },
            },
            
            rainbow: {
                id: 'rainbow',
                name: 'Rainbow',
                description: 'Cycling rainbow colors',
                price: 2000,
                animated: true,
                colors: {
                    primary: 'rainbow',
                    secondary: 'rainbow',
                    glow: 'rainbow',
                },
            },
            
            chrome: {
                id: 'chrome',
                name: 'Chrome',
                description: 'Reflective silver finish',
                price: 3000,
                colors: {
                    primary: 0xcccccc,
                    secondary: 0xffffff,
                    glow: 0x888888,
                },
            },
            
            gold: {
                id: 'gold',
                name: 'Gold Edition',
                description: 'Premium gold finish',
                price: 5000,
                colors: {
                    primary: 0xffd700,
                    secondary: 0xffaa00,
                    glow: 0xffd700,
                },
            },
            
            void: {
                id: 'void',
                name: 'Void Walker',
                description: 'Darkness incarnate',
                price: 4000,
                colors: {
                    primary: 0x111111,
                    secondary: 0x000000,
                    glow: 0x440044,
                },
            },
            
            legendary: {
                id: 'legendary',
                name: 'Legendary',
                description: 'Reserved for true champions',
                price: 10000,
                animated: true,
                colors: {
                    primary: 'pulse',
                    secondary: 0xffffff,
                    glow: 'pulse',
                },
                unlockRequirement: {
                    type: 'achievement',
                    id: 'ALL_STARS',
                },
            },
        };
    }
    
    /**
     * Load saved garage progress
     */
    loadProgress() {
        try {
            const data = localStorage.getItem('gravshift_garage');
            if (data) {
                const saved = JSON.parse(data);
                this.currency = saved.currency || 0;
                this.ownedVehicles = saved.ownedVehicles || { BALANCED: true };
                this.vehicleUpgrades = saved.vehicleUpgrades || {};
                this.selectedVehicle = saved.selectedVehicle || 'BALANCED';
                this.selectedSkin = saved.selectedSkin || 'default';
                this.ownedSkins = saved.ownedSkins || { default: true };
            } else {
                this.ownedVehicles = { BALANCED: true };
                this.vehicleUpgrades = {};
                this.ownedSkins = { default: true };
            }
        } catch (e) {
            console.warn('Could not load garage data');
            this.ownedVehicles = { BALANCED: true };
            this.vehicleUpgrades = {};
            this.ownedSkins = { default: true };
        }
    }
    
    /**
     * Save garage progress
     */
    saveProgress() {
        try {
            const data = {
                currency: this.currency,
                ownedVehicles: this.ownedVehicles,
                vehicleUpgrades: this.vehicleUpgrades,
                selectedVehicle: this.selectedVehicle,
                selectedSkin: this.selectedSkin,
                ownedSkins: this.ownedSkins,
            };
            localStorage.setItem('gravshift_garage', JSON.stringify(data));
        } catch (e) {
            console.warn('Could not save garage data');
        }
    }
    
    /**
     * Add currency (from gameplay)
     */
    addCurrency(amount) {
        this.currency += amount;
        this.saveProgress();
        return this.currency;
    }
    
    /**
     * Spend currency
     */
    spendCurrency(amount) {
        if (this.currency >= amount) {
            this.currency -= amount;
            this.saveProgress();
            return true;
        }
        return false;
    }
    
    /**
     * Check if can afford
     */
    canAfford(amount) {
        return this.currency >= amount;
    }
    
    /**
     * Check if vehicle is unlocked (requirement met)
     */
    isVehicleUnlocked(vehicleId) {
        const vehicle = this.vehicleShop[vehicleId];
        if (!vehicle) return false;
        
        // Already owned
        if (this.ownedVehicles[vehicleId]) return true;
        
        // Check unlock requirement
        if (!vehicle.unlockRequirement) return true;
        
        const req = vehicle.unlockRequirement;
        switch (req.type) {
            case 'achievement':
                // Check if achievement is unlocked
                if (this.scene && this.scene.registry) {
                    const achievementManager = new AchievementManager(this.scene);
                    return achievementManager.isUnlocked(req.id);
                }
                return false;
                
            case 'level':
                // Check if level is completed
                if (this.scene && this.scene.registry) {
                    const levelManager = new LevelManager(this.scene);
                    return levelManager.isLevelUnlocked(req.id + 1);
                }
                return false;
                
            case 'stars':
                // Check total stars
                if (this.scene && this.scene.registry) {
                    const levelManager = new LevelManager(this.scene);
                    return levelManager.getTotalStars() >= req.count;
                }
                return false;
                
            default:
                return true;
        }
    }
    
    /**
     * Purchase a vehicle
     */
    purchaseVehicle(vehicleId) {
        const vehicle = this.vehicleShop[vehicleId];
        if (!vehicle) return { success: false, error: 'Vehicle not found' };
        
        if (this.ownedVehicles[vehicleId]) {
            return { success: false, error: 'Already owned' };
        }
        
        if (!this.isVehicleUnlocked(vehicleId)) {
            return { success: false, error: 'Requirements not met' };
        }
        
        if (!this.canAfford(vehicle.price)) {
            return { success: false, error: 'Insufficient funds' };
        }
        
        this.spendCurrency(vehicle.price);
        this.ownedVehicles[vehicleId] = true;
        this.saveProgress();
        
        return { success: true, vehicle };
    }
    
    /**
     * Select a vehicle
     */
    selectVehicle(vehicleId) {
        if (!this.ownedVehicles[vehicleId]) {
            return { success: false, error: 'Vehicle not owned' };
        }
        
        this.selectedVehicle = vehicleId;
        this.saveProgress();
        
        // Update registry
        if (this.scene && this.scene.registry) {
            this.scene.registry.set('selectedVehicle', vehicleId);
        }
        
        return { success: true };
    }
    
    /**
     * Get upgrade level for vehicle
     */
    getUpgradeLevel(vehicleId, upgradeId) {
        if (!this.vehicleUpgrades[vehicleId]) return 0;
        return this.vehicleUpgrades[vehicleId][upgradeId] || 0;
    }
    
    /**
     * Get upgrade price
     */
    getUpgradePrice(upgradeId, currentLevel) {
        const upgrade = this.upgradeShop[upgradeId];
        if (!upgrade) return Infinity;
        
        return Math.floor(upgrade.basePrice * Math.pow(upgrade.priceMultiplier, currentLevel));
    }
    
    /**
     * Purchase an upgrade
     */
    purchaseUpgrade(vehicleId, upgradeId) {
        const upgrade = this.upgradeShop[upgradeId];
        if (!upgrade) return { success: false, error: 'Upgrade not found' };
        
        if (!this.ownedVehicles[vehicleId]) {
            return { success: false, error: 'Vehicle not owned' };
        }
        
        const currentLevel = this.getUpgradeLevel(vehicleId, upgradeId);
        if (currentLevel >= upgrade.maxLevel) {
            return { success: false, error: 'Max level reached' };
        }
        
        const price = this.getUpgradePrice(upgradeId, currentLevel);
        if (!this.canAfford(price)) {
            return { success: false, error: 'Insufficient funds' };
        }
        
        this.spendCurrency(price);
        
        if (!this.vehicleUpgrades[vehicleId]) {
            this.vehicleUpgrades[vehicleId] = {};
        }
        this.vehicleUpgrades[vehicleId][upgradeId] = currentLevel + 1;
        
        this.saveProgress();
        
        return { success: true, newLevel: currentLevel + 1 };
    }
    
    /**
     * Get vehicle stats with upgrades applied
     */
    getVehicleStats(vehicleId) {
        const vehicle = this.vehicleShop[vehicleId];
        if (!vehicle) return null;
        
        const stats = { ...vehicle.stats };
        
        // Apply upgrades
        if (this.vehicleUpgrades[vehicleId]) {
            Object.entries(this.vehicleUpgrades[vehicleId]).forEach(([upgradeId, level]) => {
                const upgrade = this.upgradeShop[upgradeId];
                if (upgrade && upgrade.perLevelBonus) {
                    Object.entries(upgrade.perLevelBonus).forEach(([stat, bonus]) => {
                        if (stats[stat] !== undefined) {
                            stats[stat] += bonus * level;
                        }
                    });
                }
            });
        }
        
        return stats;
    }
    
    /**
     * Check if skin is unlocked
     */
    isSkinUnlocked(skinId) {
        const skin = this.skinShop[skinId];
        if (!skin) return false;
        
        if (this.ownedSkins[skinId]) return true;
        
        if (!skin.unlockRequirement) return true;
        
        // Similar to vehicle unlock checks
        return false;
    }
    
    /**
     * Purchase a skin
     */
    purchaseSkin(skinId) {
        const skin = this.skinShop[skinId];
        if (!skin) return { success: false, error: 'Skin not found' };
        
        if (this.ownedSkins[skinId]) {
            return { success: false, error: 'Already owned' };
        }
        
        if (!this.isSkinUnlocked(skinId)) {
            return { success: false, error: 'Requirements not met' };
        }
        
        if (!this.canAfford(skin.price)) {
            return { success: false, error: 'Insufficient funds' };
        }
        
        this.spendCurrency(skin.price);
        this.ownedSkins[skinId] = true;
        this.saveProgress();
        
        return { success: true, skin };
    }
    
    /**
     * Select a skin
     */
    selectSkin(skinId) {
        if (!this.ownedSkins[skinId]) {
            return { success: false, error: 'Skin not owned' };
        }
        
        this.selectedSkin = skinId;
        this.saveProgress();
        
        return { success: true };
    }
    
    /**
     * Get selected skin colors
     */
    getSelectedSkinColors() {
        const skin = this.skinShop[this.selectedSkin];
        return skin?.colors || null;
    }
    
    /**
     * Get all owned vehicles
     */
    getOwnedVehicles() {
        return Object.keys(this.ownedVehicles).map(id => ({
            ...this.vehicleShop[id],
            upgrades: this.vehicleUpgrades[id] || {},
            stats: this.getVehicleStats(id),
        }));
    }
    
    /**
     * Get all vehicles for shop display
     */
    getShopVehicles() {
        return Object.values(this.vehicleShop).map(vehicle => ({
            ...vehicle,
            owned: !!this.ownedVehicles[vehicle.id],
            unlocked: this.isVehicleUnlocked(vehicle.id),
            canAfford: this.canAfford(vehicle.price),
        }));
    }
    
    /**
     * Get all skins for shop display
     */
    getShopSkins() {
        return Object.values(this.skinShop).map(skin => ({
            ...skin,
            owned: !!this.ownedSkins[skin.id],
            unlocked: this.isSkinUnlocked(skin.id),
            canAfford: this.canAfford(skin.price),
        }));
    }
    
    /**
     * Get currency display string
     */
    getCurrencyDisplay() {
        return MathUtils.formatNumber(this.currency);
    }
    
    /**
     * Reset all progress
     */
    resetAll() {
        this.currency = 0;
        this.ownedVehicles = { BALANCED: true };
        this.vehicleUpgrades = {};
        this.selectedVehicle = 'BALANCED';
        this.selectedSkin = 'default';
        this.ownedSkins = { default: true };
        this.saveProgress();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.GarageManager = GarageManager;
}
