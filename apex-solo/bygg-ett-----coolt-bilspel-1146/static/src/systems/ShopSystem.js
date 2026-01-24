/**
 * ShopSystem.js
 * In-game shop system for purchasing items, vehicles, skins, and consumables
 * Includes special offers, bundles, and seasonal items
 */

class ShopSystem {
    constructor() {
        // Currency
        this.coins = 0;
        this.gems = 0; // Premium currency
        
        // Shop state
        this.dailyDeals = [];
        this.lastDealRefresh = null;
        this.purchaseHistory = [];
        
        // Product catalog
        this.catalog = this.defineCatalog();
        this.bundles = this.defineBundles();
        this.specialOffers = [];
        
        // Callbacks
        this.onPurchase = null;
        this.onCurrencyChange = null;
        
        // Load state
        this.loadState();
        
        // Check and refresh daily deals
        this.checkDailyDeals();
    }
    
    /**
     * Define the product catalog
     */
    defineCatalog() {
        return {
            // Vehicles
            vehicles: {
                'speeder': {
                    id: 'speeder',
                    name: 'Speeder',
                    description: 'Lightning-fast vehicle with reduced handling',
                    category: 'vehicle',
                    price: 5000,
                    currency: 'coins',
                    stats: { speed: 10, handling: 4, boost: 8 },
                    preview: 'speeder_preview',
                    unlockLevel: 5
                },
                'tank': {
                    id: 'tank',
                    name: 'Tank',
                    description: 'Heavy vehicle with extra durability',
                    category: 'vehicle',
                    price: 7500,
                    currency: 'coins',
                    stats: { speed: 5, handling: 6, boost: 5, durability: 10 },
                    preview: 'tank_preview',
                    unlockLevel: 10
                },
                'drifter': {
                    id: 'drifter',
                    name: 'Drifter',
                    description: 'Specialized for gravity drifting',
                    category: 'vehicle',
                    price: 10000,
                    currency: 'coins',
                    stats: { speed: 7, handling: 9, boost: 7 },
                    preview: 'drifter_preview',
                    unlockLevel: 15
                },
                'heavy': {
                    id: 'heavy',
                    name: 'Heavy Lifter',
                    description: 'Maximum stability in gravity shifts',
                    category: 'vehicle',
                    price: 15000,
                    currency: 'coins',
                    stats: { speed: 6, handling: 8, boost: 6, stability: 10 },
                    preview: 'heavy_preview',
                    unlockLevel: 20
                },
                'quantum': {
                    id: 'quantum',
                    name: 'Quantum',
                    description: 'Experimental vehicle with phase abilities',
                    category: 'vehicle',
                    price: 500,
                    currency: 'gems',
                    stats: { speed: 9, handling: 8, boost: 9, special: true },
                    preview: 'quantum_preview',
                    premium: true
                }
            },
            
            // Skins
            skins: {
                'neon_blue': {
                    id: 'neon_blue',
                    name: 'Neon Blue',
                    description: 'Electric blue neon trails',
                    category: 'skin',
                    price: 1500,
                    currency: 'coins',
                    colors: { primary: 0x0088ff, secondary: 0x00ffff, trail: 0x0044ff }
                },
                'fire_red': {
                    id: 'fire_red',
                    name: 'Fire Red',
                    description: 'Blazing red flames',
                    category: 'skin',
                    price: 1500,
                    currency: 'coins',
                    colors: { primary: 0xff4400, secondary: 0xffaa00, trail: 0xff0000 }
                },
                'toxic_green': {
                    id: 'toxic_green',
                    name: 'Toxic Green',
                    description: 'Radioactive glow',
                    category: 'skin',
                    price: 2000,
                    currency: 'coins',
                    colors: { primary: 0x00ff44, secondary: 0x88ff00, trail: 0x00ff00 }
                },
                'purple_haze': {
                    id: 'purple_haze',
                    name: 'Purple Haze',
                    description: 'Mysterious purple aura',
                    category: 'skin',
                    price: 2000,
                    currency: 'coins',
                    colors: { primary: 0x8844ff, secondary: 0xff44ff, trail: 0x6600ff }
                },
                'golden': {
                    id: 'golden',
                    name: 'Golden',
                    description: 'Pure gold luxury finish',
                    category: 'skin',
                    price: 5000,
                    currency: 'coins',
                    colors: { primary: 0xffd700, secondary: 0xffaa00, trail: 0xffee00 }
                },
                'rainbow': {
                    id: 'rainbow',
                    name: 'Rainbow',
                    description: 'Ever-changing rainbow colors',
                    category: 'skin',
                    price: 200,
                    currency: 'gems',
                    colors: { primary: 'rainbow', secondary: 'rainbow', trail: 'rainbow' },
                    animated: true,
                    premium: true
                },
                'holographic': {
                    id: 'holographic',
                    name: 'Holographic',
                    description: 'Holographic shimmer effect',
                    category: 'skin',
                    price: 300,
                    currency: 'gems',
                    colors: { primary: 'holo', secondary: 'holo', trail: 0xffffff },
                    animated: true,
                    premium: true
                },
                'stealth': {
                    id: 'stealth',
                    name: 'Stealth',
                    description: 'Nearly invisible dark finish',
                    category: 'skin',
                    price: 3000,
                    currency: 'coins',
                    colors: { primary: 0x222222, secondary: 0x111111, trail: 0x333333 }
                }
            },
            
            // Upgrades
            upgrades: {
                'speed_boost': {
                    id: 'speed_boost',
                    name: 'Speed Upgrade',
                    description: 'Permanent +10% max speed',
                    category: 'upgrade',
                    price: 3000,
                    currency: 'coins',
                    effect: { stat: 'speed', bonus: 0.1 },
                    maxLevel: 5
                },
                'handling_boost': {
                    id: 'handling_boost',
                    name: 'Handling Upgrade',
                    description: 'Permanent +10% handling',
                    category: 'upgrade',
                    price: 2500,
                    currency: 'coins',
                    effect: { stat: 'handling', bonus: 0.1 },
                    maxLevel: 5
                },
                'boost_capacity': {
                    id: 'boost_capacity',
                    name: 'Boost Tank',
                    description: 'Permanent +20% boost capacity',
                    category: 'upgrade',
                    price: 3500,
                    currency: 'coins',
                    effect: { stat: 'boostCapacity', bonus: 0.2 },
                    maxLevel: 5
                },
                'shield_duration': {
                    id: 'shield_duration',
                    name: 'Shield Enhancer',
                    description: 'Shield lasts 25% longer',
                    category: 'upgrade',
                    price: 4000,
                    currency: 'coins',
                    effect: { stat: 'shieldDuration', bonus: 0.25 },
                    maxLevel: 3
                },
                'magnet_range': {
                    id: 'magnet_range',
                    name: 'Magnet Amplifier',
                    description: 'Magnet range +30%',
                    category: 'upgrade',
                    price: 2000,
                    currency: 'coins',
                    effect: { stat: 'magnetRange', bonus: 0.3 },
                    maxLevel: 3
                }
            },
            
            // Consumables
            consumables: {
                'boost_pack_small': {
                    id: 'boost_pack_small',
                    name: 'Boost Pack (3)',
                    description: 'Start with instant boost x3',
                    category: 'consumable',
                    price: 500,
                    currency: 'coins',
                    quantity: 3,
                    effect: 'instant_boost'
                },
                'boost_pack_large': {
                    id: 'boost_pack_large',
                    name: 'Boost Pack (10)',
                    description: 'Start with instant boost x10',
                    category: 'consumable',
                    price: 1500,
                    currency: 'coins',
                    quantity: 10,
                    effect: 'instant_boost',
                    discount: 0.1
                },
                'shield_pack_small': {
                    id: 'shield_pack_small',
                    name: 'Shield Pack (3)',
                    description: 'Start with shield active x3',
                    category: 'consumable',
                    price: 750,
                    currency: 'coins',
                    quantity: 3,
                    effect: 'start_shield'
                },
                'revive_token': {
                    id: 'revive_token',
                    name: 'Revive Token',
                    description: 'Continue after death once',
                    category: 'consumable',
                    price: 100,
                    currency: 'gems',
                    quantity: 1,
                    effect: 'revive'
                },
                'double_coins': {
                    id: 'double_coins',
                    name: 'Double Coins (1 Hour)',
                    description: 'Earn 2x coins for 1 hour',
                    category: 'consumable',
                    price: 50,
                    currency: 'gems',
                    quantity: 1,
                    effect: 'double_coins',
                    duration: 3600
                },
                'xp_boost': {
                    id: 'xp_boost',
                    name: 'XP Boost (1 Hour)',
                    description: 'Earn 2x XP for 1 hour',
                    category: 'consumable',
                    price: 50,
                    currency: 'gems',
                    quantity: 1,
                    effect: 'double_xp',
                    duration: 3600
                }
            },
            
            // Premium currency
            currency: {
                'gems_100': {
                    id: 'gems_100',
                    name: '100 Gems',
                    description: 'A handful of gems',
                    category: 'currency',
                    price: 0.99,
                    currency: 'real',
                    gems: 100
                },
                'gems_500': {
                    id: 'gems_500',
                    name: '500 Gems',
                    description: 'A bag of gems',
                    category: 'currency',
                    price: 4.99,
                    currency: 'real',
                    gems: 500,
                    bonus: 50
                },
                'gems_1200': {
                    id: 'gems_1200',
                    name: '1200 Gems',
                    description: 'A chest of gems',
                    category: 'currency',
                    price: 9.99,
                    currency: 'real',
                    gems: 1200,
                    bonus: 200
                },
                'gems_5000': {
                    id: 'gems_5000',
                    name: '5000 Gems',
                    description: 'A vault of gems',
                    category: 'currency',
                    price: 39.99,
                    currency: 'real',
                    gems: 5000,
                    bonus: 1000,
                    popular: true
                }
            }
        };
    }
    
    /**
     * Define bundle offers
     */
    defineBundles() {
        return {
            'starter_pack': {
                id: 'starter_pack',
                name: 'Starter Pack',
                description: 'Everything you need to begin!',
                items: [
                    { type: 'vehicle', id: 'speeder' },
                    { type: 'skin', id: 'neon_blue' },
                    { type: 'consumable', id: 'boost_pack_small', quantity: 2 }
                ],
                originalPrice: 8000,
                price: 5000,
                currency: 'coins',
                discount: 0.375,
                limitedTime: false
            },
            'speed_demon': {
                id: 'speed_demon',
                name: 'Speed Demon Bundle',
                description: 'For those who love speed!',
                items: [
                    { type: 'vehicle', id: 'speeder' },
                    { type: 'skin', id: 'fire_red' },
                    { type: 'upgrade', id: 'speed_boost', level: 3 }
                ],
                originalPrice: 15000,
                price: 10000,
                currency: 'coins',
                discount: 0.33,
                limitedTime: false
            },
            'premium_starter': {
                id: 'premium_starter',
                name: 'Premium Starter',
                description: 'The ultimate beginning!',
                items: [
                    { type: 'vehicle', id: 'quantum' },
                    { type: 'skin', id: 'rainbow' },
                    { type: 'gems', amount: 500 },
                    { type: 'coins', amount: 10000 }
                ],
                originalPrice: 1500,
                price: 800,
                currency: 'gems',
                discount: 0.47,
                limitedTime: true,
                expiresIn: 7 * 24 * 60 * 60 * 1000 // 7 days
            }
        };
    }
    
    /**
     * Load shop state from storage
     */
    loadState() {
        try {
            const saved = localStorage.getItem('gravshift_shop');
            if (saved) {
                const data = JSON.parse(saved);
                this.coins = data.coins || 0;
                this.gems = data.gems || 0;
                this.dailyDeals = data.dailyDeals || [];
                this.lastDealRefresh = data.lastDealRefresh;
                this.purchaseHistory = data.purchaseHistory || [];
            }
        } catch (e) {
            console.error('Failed to load shop state:', e);
        }
        
        // Also sync with SaveManager if available
        if (window.SaveManager) {
            const garage = SaveManager.loadData('garage');
            if (garage) {
                this.coins = garage.coins || 0;
            }
        }
    }
    
    /**
     * Save shop state
     */
    saveState() {
        try {
            const data = {
                coins: this.coins,
                gems: this.gems,
                dailyDeals: this.dailyDeals,
                lastDealRefresh: this.lastDealRefresh,
                purchaseHistory: this.purchaseHistory
            };
            localStorage.setItem('gravshift_shop', JSON.stringify(data));
            
            // Sync coins to SaveManager
            if (window.SaveManager) {
                SaveManager.updateData('garage', { coins: this.coins });
            }
        } catch (e) {
            console.error('Failed to save shop state:', e);
        }
    }
    
    /**
     * Check and refresh daily deals
     */
    checkDailyDeals() {
        const now = Date.now();
        const today = new Date().toDateString();
        
        if (this.lastDealRefresh !== today) {
            this.generateDailyDeals();
            this.lastDealRefresh = today;
            this.saveState();
        }
    }
    
    /**
     * Generate daily deals
     */
    generateDailyDeals() {
        this.dailyDeals = [];
        
        // Generate 3 random deals with discounts
        const categories = ['vehicles', 'skins', 'upgrades', 'consumables'];
        const usedItems = new Set();
        
        for (let i = 0; i < 3; i++) {
            const category = categories[Math.floor(Math.random() * categories.length)];
            const items = Object.values(this.catalog[category]);
            
            // Find an item not already used
            let item = null;
            for (const candidate of items) {
                if (!usedItems.has(candidate.id) && !candidate.premium) {
                    item = candidate;
                    usedItems.add(candidate.id);
                    break;
                }
            }
            
            if (item) {
                const discount = 0.2 + Math.random() * 0.3; // 20-50% discount
                this.dailyDeals.push({
                    item: item,
                    discount: discount,
                    originalPrice: item.price,
                    salePrice: Math.floor(item.price * (1 - discount))
                });
            }
        }
    }
    
    /**
     * Get all items in a category
     */
    getCategory(category) {
        return Object.values(this.catalog[category] || {});
    }
    
    /**
     * Get item by ID
     */
    getItem(category, itemId) {
        return this.catalog[category]?.[itemId] || null;
    }
    
    /**
     * Get daily deals
     */
    getDailyDeals() {
        this.checkDailyDeals();
        return [...this.dailyDeals];
    }
    
    /**
     * Get all bundles
     */
    getBundles() {
        return Object.values(this.bundles);
    }
    
    /**
     * Check if player can afford item
     */
    canAfford(item, salePrice = null) {
        const price = salePrice || item.price;
        
        if (item.currency === 'coins') {
            return this.coins >= price;
        } else if (item.currency === 'gems') {
            return this.gems >= price;
        }
        
        return false;
    }
    
    /**
     * Check if player owns item
     */
    ownsItem(category, itemId) {
        // Check with SaveManager
        if (window.SaveManager) {
            const unlocks = SaveManager.loadData('unlocks');
            const garage = SaveManager.loadData('garage');
            
            if (category === 'vehicle' || category === 'vehicles') {
                return garage?.ownedVehicles?.includes(itemId) || 
                       unlocks?.vehicles?.includes(itemId);
            } else if (category === 'skin' || category === 'skins') {
                return garage?.ownedSkins?.includes(itemId) ||
                       unlocks?.skins?.includes(itemId);
            }
        }
        
        // Check purchase history
        return this.purchaseHistory.some(p => 
            p.category === category && p.itemId === itemId
        );
    }
    
    /**
     * Purchase an item
     */
    purchaseItem(category, itemId, salePrice = null) {
        const item = this.getItem(category, itemId);
        if (!item) {
            return { success: false, error: 'Item not found' };
        }
        
        // Check if already owned (for non-consumables)
        if (item.category !== 'consumable' && item.category !== 'currency') {
            if (this.ownsItem(category, itemId)) {
                return { success: false, error: 'Already owned' };
            }
        }
        
        const price = salePrice || item.price;
        
        // Check if can afford
        if (!this.canAfford(item, price)) {
            return { success: false, error: 'Insufficient funds' };
        }
        
        // Deduct currency
        if (item.currency === 'coins') {
            this.coins -= price;
        } else if (item.currency === 'gems') {
            this.gems -= price;
        }
        
        // Grant item
        this.grantItem(item);
        
        // Record purchase
        this.purchaseHistory.push({
            category: category,
            itemId: itemId,
            price: price,
            currency: item.currency,
            timestamp: Date.now()
        });
        
        this.saveState();
        
        // Callback
        if (this.onPurchase) {
            this.onPurchase(item, price);
        }
        
        if (this.onCurrencyChange) {
            this.onCurrencyChange(this.coins, this.gems);
        }
        
        return { success: true, item: item };
    }
    
    /**
     * Grant an item to player
     */
    grantItem(item) {
        if (!window.SaveManager) return;
        
        switch (item.category) {
            case 'vehicle':
                const garage = SaveManager.loadData('garage');
                if (!garage.ownedVehicles.includes(item.id)) {
                    garage.ownedVehicles.push(item.id);
                    SaveManager.saveData('garage', garage);
                }
                break;
                
            case 'skin':
                const garageForSkin = SaveManager.loadData('garage');
                if (!garageForSkin.ownedSkins.includes(item.id)) {
                    garageForSkin.ownedSkins.push(item.id);
                    SaveManager.saveData('garage', garageForSkin);
                }
                break;
                
            case 'upgrade':
                const garageForUpgrade = SaveManager.loadData('garage');
                const vehicle = garageForUpgrade.currentVehicle;
                if (!garageForUpgrade.vehicleUpgrades[vehicle]) {
                    garageForUpgrade.vehicleUpgrades[vehicle] = {};
                }
                const currentLevel = garageForUpgrade.vehicleUpgrades[vehicle][item.id] || 0;
                garageForUpgrade.vehicleUpgrades[vehicle][item.id] = Math.min(
                    currentLevel + 1, 
                    item.maxLevel
                );
                SaveManager.saveData('garage', garageForUpgrade);
                break;
                
            case 'consumable':
                const inventory = SaveManager.loadData('inventory');
                const effectKey = item.effect;
                inventory[effectKey] = (inventory[effectKey] || 0) + item.quantity;
                SaveManager.saveData('inventory', inventory);
                break;
                
            case 'currency':
                if (item.gems) {
                    this.gems += item.gems + (item.bonus || 0);
                }
                break;
        }
    }
    
    /**
     * Purchase a bundle
     */
    purchaseBundle(bundleId) {
        const bundle = this.bundles[bundleId];
        if (!bundle) {
            return { success: false, error: 'Bundle not found' };
        }
        
        // Check if can afford
        if (bundle.currency === 'coins' && this.coins < bundle.price) {
            return { success: false, error: 'Insufficient coins' };
        } else if (bundle.currency === 'gems' && this.gems < bundle.price) {
            return { success: false, error: 'Insufficient gems' };
        }
        
        // Deduct currency
        if (bundle.currency === 'coins') {
            this.coins -= bundle.price;
        } else if (bundle.currency === 'gems') {
            this.gems -= bundle.price;
        }
        
        // Grant all items
        bundle.items.forEach(bundleItem => {
            let item = null;
            
            if (bundleItem.type === 'vehicle') {
                item = this.catalog.vehicles[bundleItem.id];
            } else if (bundleItem.type === 'skin') {
                item = this.catalog.skins[bundleItem.id];
            } else if (bundleItem.type === 'upgrade') {
                item = this.catalog.upgrades[bundleItem.id];
            } else if (bundleItem.type === 'consumable') {
                item = this.catalog.consumables[bundleItem.id];
            } else if (bundleItem.type === 'gems') {
                this.gems += bundleItem.amount;
            } else if (bundleItem.type === 'coins') {
                this.coins += bundleItem.amount;
            }
            
            if (item) {
                this.grantItem(item);
            }
        });
        
        // Record purchase
        this.purchaseHistory.push({
            category: 'bundle',
            itemId: bundleId,
            price: bundle.price,
            currency: bundle.currency,
            timestamp: Date.now()
        });
        
        this.saveState();
        
        if (this.onPurchase) {
            this.onPurchase(bundle, bundle.price);
        }
        
        if (this.onCurrencyChange) {
            this.onCurrencyChange(this.coins, this.gems);
        }
        
        return { success: true, bundle: bundle };
    }
    
    /**
     * Add coins
     */
    addCoins(amount) {
        this.coins += amount;
        this.saveState();
        
        if (this.onCurrencyChange) {
            this.onCurrencyChange(this.coins, this.gems);
        }
    }
    
    /**
     * Add gems
     */
    addGems(amount) {
        this.gems += amount;
        this.saveState();
        
        if (this.onCurrencyChange) {
            this.onCurrencyChange(this.coins, this.gems);
        }
    }
    
    /**
     * Get current currency
     */
    getCurrency() {
        return {
            coins: this.coins,
            gems: this.gems
        };
    }
    
    /**
     * Get purchase history
     */
    getPurchaseHistory() {
        return [...this.purchaseHistory];
    }
    
    /**
     * Get time until daily deal refresh
     */
    getTimeUntilRefresh() {
        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(0, 0, 0, 0);
        
        const ms = tomorrow.getTime() - now.getTime();
        const hours = Math.floor(ms / (1000 * 60 * 60));
        const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
        
        return { hours, minutes, total: ms };
    }
    
    /**
     * Check for limited time offers
     */
    checkLimitedOffers() {
        const now = Date.now();
        const activeOffers = [];
        
        Object.values(this.bundles).forEach(bundle => {
            if (bundle.limitedTime && bundle.expiresIn) {
                // Calculate expiry based on first seen
                const firstSeen = localStorage.getItem(`bundle_seen_${bundle.id}`);
                if (!firstSeen) {
                    localStorage.setItem(`bundle_seen_${bundle.id}`, now.toString());
                }
                
                const seenTime = parseInt(firstSeen || now);
                const expiresAt = seenTime + bundle.expiresIn;
                
                if (now < expiresAt) {
                    activeOffers.push({
                        ...bundle,
                        expiresAt: expiresAt,
                        timeRemaining: expiresAt - now
                    });
                }
            }
        });
        
        this.specialOffers = activeOffers;
        return activeOffers;
    }
    
    /**
     * Get featured items for shop display
     */
    getFeatured() {
        const featured = [];
        
        // Add premium vehicles
        Object.values(this.catalog.vehicles).forEach(v => {
            if (v.premium) featured.push({ ...v, featured: 'premium' });
        });
        
        // Add premium skins
        Object.values(this.catalog.skins).forEach(s => {
            if (s.premium) featured.push({ ...s, featured: 'premium' });
        });
        
        // Add best value gem pack
        const bestValue = this.catalog.currency['gems_5000'];
        if (bestValue) {
            featured.push({ ...bestValue, featured: 'best_value' });
        }
        
        return featured;
    }
}

// Create singleton
if (typeof window !== 'undefined') {
    window.ShopSystem = new ShopSystem();
}
