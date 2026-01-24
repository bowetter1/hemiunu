/**
 * ShopScene.js
 * In-game shop interface
 * Browse and purchase vehicles, skins, upgrades, and consumables
 */

class ShopScene extends Phaser.Scene {
    constructor() {
        super({ key: 'ShopScene' });
        
        // UI state
        this.currentCategory = 'featured';
        this.categories = ['featured', 'vehicles', 'skins', 'upgrades', 'consumables', 'bundles'];
        this.scrollOffset = 0;
        this.maxScroll = 0;
        this.selectedItem = null;
        
        // Data
        this.shopData = null;
    }
    
    /**
     * Initialize scene
     */
    init(data) {
        this.returnScene = data.returnScene || 'MenuScene';
        this.initialCategory = data.category || 'featured';
        this.currentCategory = this.initialCategory;
    }
    
    /**
     * Create scene
     */
    create() {
        const { width, height } = this.cameras.main;
        
        // Load shop data
        this.loadShopData();
        
        // Background
        this.createBackground(width, height);
        
        // Header with currency
        this.createHeader(width);
        
        // Category navigation
        this.createCategoryNav(width);
        
        // Content area
        this.contentContainer = this.add.container(0, 160);
        this.renderCategoryContent();
        
        // Daily deals panel
        this.createDailyDealsPanel(width);
        
        // Item detail panel
        this.createDetailPanel(width, height);
        
        // Back button
        this.createBackButton(width, height);
        
        // Input
        this.setupInput();
        
        // Animation
        this.animateIn();
    }
    
    /**
     * Load shop data
     */
    loadShopData() {
        if (window.ShopSystem) {
            this.shopData = {
                currency: ShopSystem.getCurrency(),
                featured: ShopSystem.getFeatured(),
                vehicles: ShopSystem.getCategory('vehicles'),
                skins: ShopSystem.getCategory('skins'),
                upgrades: ShopSystem.getCategory('upgrades'),
                consumables: ShopSystem.getCategory('consumables'),
                bundles: ShopSystem.getBundles(),
                dailyDeals: ShopSystem.getDailyDeals()
            };
        } else {
            // Mock data
            this.shopData = this.generateMockShopData();
        }
    }
    
    /**
     * Generate mock shop data
     */
    generateMockShopData() {
        return {
            currency: { coins: 5000, gems: 100 },
            featured: [
                { id: 'quantum', name: 'Quantum', price: 500, currency: 'gems', category: 'vehicle', premium: true },
                { id: 'rainbow', name: 'Rainbow Skin', price: 200, currency: 'gems', category: 'skin', premium: true }
            ],
            vehicles: [
                { id: 'speeder', name: 'Speeder', description: 'Fast vehicle', price: 5000, currency: 'coins', stats: { speed: 10, handling: 4 } },
                { id: 'tank', name: 'Tank', description: 'Heavy vehicle', price: 7500, currency: 'coins', stats: { speed: 5, handling: 6 } }
            ],
            skins: [
                { id: 'neon_blue', name: 'Neon Blue', price: 1500, currency: 'coins' },
                { id: 'fire_red', name: 'Fire Red', price: 1500, currency: 'coins' }
            ],
            upgrades: [
                { id: 'speed_boost', name: 'Speed Upgrade', price: 3000, currency: 'coins', maxLevel: 5 }
            ],
            consumables: [
                { id: 'boost_pack', name: 'Boost Pack (3)', price: 500, currency: 'coins', quantity: 3 }
            ],
            bundles: [
                { id: 'starter', name: 'Starter Pack', price: 5000, currency: 'coins', originalPrice: 8000, discount: 0.375 }
            ],
            dailyDeals: [
                { item: { id: 'neon_blue', name: 'Neon Blue', price: 1500 }, discount: 0.3, salePrice: 1050 }
            ]
        };
    }
    
    /**
     * Create background
     */
    createBackground(width, height) {
        const graphics = this.add.graphics();
        
        // Gradient
        for (let y = 0; y < height; y++) {
            const t = y / height;
            const r = Math.floor(12 + t * 8);
            const g = Math.floor(8 + t * 15);
            const b = Math.floor(25 + t * 20);
            graphics.fillStyle(Phaser.Display.Color.GetColor(r, g, b), 1);
            graphics.fillRect(0, y, width, 1);
        }
        
        // Decorative elements
        for (let i = 0; i < 15; i++) {
            const x = Math.random() * width;
            const y = Math.random() * height;
            const size = 2 + Math.random() * 3;
            graphics.fillStyle(0xffaa00, Math.random() * 0.3);
            graphics.fillCircle(x, y, size);
        }
    }
    
    /**
     * Create header with currency display
     */
    createHeader(width) {
        const headerBg = this.add.graphics();
        headerBg.fillStyle(0x0a1020, 0.95);
        headerBg.fillRect(0, 0, width, 70);
        headerBg.lineStyle(2, 0xffaa00, 0.5);
        headerBg.lineBetween(0, 70, width, 70);
        
        // Shop title
        this.add.text(20, 35, 'SHOP', {
            fontFamily: 'Arial Black',
            fontSize: '28px',
            color: '#ffaa00',
            stroke: '#553300',
            strokeThickness: 3
        }).setOrigin(0, 0.5);
        
        // Currency display
        this.currencyContainer = this.add.container(width - 20, 35);
        
        // Coins
        const coinIcon = this.add.graphics();
        coinIcon.fillStyle(0xffaa00, 1);
        coinIcon.fillCircle(-150, 0, 12);
        coinIcon.fillStyle(0xffdd00, 1);
        coinIcon.fillCircle(-152, -2, 8);
        this.currencyContainer.add(coinIcon);
        
        this.coinsText = this.add.text(-130, 0, this.formatNumber(this.shopData.currency.coins), {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: '#ffaa00'
        }).setOrigin(0, 0.5);
        this.currencyContainer.add(this.coinsText);
        
        // Gems
        const gemIcon = this.add.graphics();
        gemIcon.fillStyle(0x00ffff, 1);
        gemIcon.fillTriangle(-50, -10, -60, 5, -40, 5);
        gemIcon.fillStyle(0x88ffff, 1);
        gemIcon.fillTriangle(-50, -8, -56, 3, -50, 3);
        this.currencyContainer.add(gemIcon);
        
        this.gemsText = this.add.text(-30, 0, this.formatNumber(this.shopData.currency.gems), {
            fontFamily: 'Arial Black',
            fontSize: '16px',
            color: '#00ffff'
        }).setOrigin(0, 0.5);
        this.currencyContainer.add(this.gemsText);
    }
    
    /**
     * Create category navigation
     */
    createCategoryNav(width) {
        const navY = 85;
        const navHeight = 60;
        
        // Background
        const navBg = this.add.graphics();
        navBg.fillStyle(0x0a1525, 0.9);
        navBg.fillRect(0, navY, width, navHeight);
        
        // Category buttons
        this.categoryButtons = [];
        const buttonWidth = (width - 20) / this.categories.length;
        
        this.categories.forEach((category, index) => {
            const x = 10 + index * buttonWidth;
            const active = category === this.currentCategory;
            
            const btn = this.add.container(x, navY + 10);
            
            const bg = this.add.graphics();
            this.drawCategoryButton(bg, buttonWidth - 10, 40, active);
            btn.add(bg);
            
            const label = this.getCategoryLabel(category);
            const text = this.add.text((buttonWidth - 10) / 2, 20, label, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: active ? '#ffaa00' : '#667788'
            }).setOrigin(0.5);
            btn.add(text);
            
            const zone = this.add.zone((buttonWidth - 10) / 2, 20, buttonWidth - 10, 40)
                .setInteractive({ useHandCursor: true });
            
            zone.on('pointerdown', () => this.selectCategory(category));
            zone.on('pointerover', () => {
                if (category !== this.currentCategory) text.setColor('#aabbcc');
            });
            zone.on('pointerout', () => {
                if (category !== this.currentCategory) text.setColor('#667788');
            });
            
            btn.add(zone);
            
            this.categoryButtons.push({ container: btn, bg, text, category });
        });
    }
    
    /**
     * Draw category button background
     */
    drawCategoryButton(graphics, width, height, active) {
        graphics.clear();
        
        if (active) {
            graphics.fillStyle(0x2a2520, 1);
            graphics.lineStyle(2, 0xffaa00, 0.8);
        } else {
            graphics.fillStyle(0x1a1520, 0.8);
            graphics.lineStyle(1, 0x334455, 0.5);
        }
        
        graphics.fillRoundedRect(0, 0, width, height, 5);
        graphics.strokeRoundedRect(0, 0, width, height, 5);
    }
    
    /**
     * Get display label for category
     */
    getCategoryLabel(category) {
        const labels = {
            featured: 'FEATURED',
            vehicles: 'VEHICLES',
            skins: 'SKINS',
            upgrades: 'UPGRADES',
            consumables: 'ITEMS',
            bundles: 'BUNDLES'
        };
        return labels[category] || category.toUpperCase();
    }
    
    /**
     * Select a category
     */
    selectCategory(category) {
        if (category === this.currentCategory) return;
        
        this.currentCategory = category;
        this.scrollOffset = 0;
        
        // Update button states
        this.categoryButtons.forEach(btn => {
            const active = btn.category === category;
            const buttonWidth = (this.cameras.main.width - 20) / this.categories.length - 10;
            this.drawCategoryButton(btn.bg, buttonWidth, 40, active);
            btn.text.setColor(active ? '#ffaa00' : '#667788');
        });
        
        this.renderCategoryContent();
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Render content for current category
     */
    renderCategoryContent() {
        this.contentContainer.removeAll(true);
        
        const { width, height } = this.cameras.main;
        let items = [];
        
        switch (this.currentCategory) {
            case 'featured':
                items = this.shopData.featured;
                break;
            case 'vehicles':
                items = this.shopData.vehicles;
                break;
            case 'skins':
                items = this.shopData.skins;
                break;
            case 'upgrades':
                items = this.shopData.upgrades;
                break;
            case 'consumables':
                items = this.shopData.consumables;
                break;
            case 'bundles':
                items = this.shopData.bundles;
                break;
        }
        
        if (this.currentCategory === 'bundles') {
            this.renderBundles(items, width);
        } else {
            this.renderItems(items, width);
        }
        
        // Calculate max scroll
        const itemHeight = this.currentCategory === 'bundles' ? 150 : 100;
        const cols = this.currentCategory === 'bundles' ? 1 : 2;
        const rows = Math.ceil(items.length / cols);
        const contentHeight = rows * (itemHeight + 10) + 100;
        this.maxScroll = Math.max(0, contentHeight - (height - 250));
    }
    
    /**
     * Render item grid
     */
    renderItems(items, width) {
        const cols = 2;
        const itemWidth = (width - 50) / cols;
        const itemHeight = 100;
        
        items.forEach((item, index) => {
            const col = index % cols;
            const row = Math.floor(index / cols);
            const x = 15 + col * (itemWidth + 10);
            const y = row * (itemHeight + 10);
            
            const itemContainer = this.createItemCard(item, x, y, itemWidth, itemHeight);
            this.contentContainer.add(itemContainer);
        });
    }
    
    /**
     * Create an item card
     */
    createItemCard(item, x, y, width, height) {
        const container = this.add.container(x, y);
        
        const owned = window.ShopSystem && ShopSystem.ownsItem(item.category, item.id);
        
        // Background
        const bg = this.add.graphics();
        
        let bgColor = 0x1a1520;
        let borderColor = 0x334455;
        
        if (item.premium) {
            bgColor = 0x2a2030;
            borderColor = 0xff44aa;
        } else if (owned) {
            bgColor = 0x1a2520;
            borderColor = 0x00ff88;
        }
        
        bg.fillStyle(bgColor, 0.9);
        bg.fillRoundedRect(0, 0, width, height, 8);
        bg.lineStyle(2, borderColor, 0.6);
        bg.strokeRoundedRect(0, 0, width, height, 8);
        container.add(bg);
        
        // Item icon placeholder
        const iconBg = this.add.graphics();
        iconBg.fillStyle(0x0a1020, 0.8);
        iconBg.fillRoundedRect(10, 10, 50, 50, 5);
        container.add(iconBg);
        
        if (item.premium) {
            const premiumBadge = this.add.text(35, 35, '★', {
                fontSize: '24px',
                color: '#ff44aa'
            }).setOrigin(0.5);
            container.add(premiumBadge);
        }
        
        // Item name
        const name = this.add.text(70, 15, item.name, {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: owned ? '#00ff88' : '#ffffff'
        });
        container.add(name);
        
        // Price or "Owned"
        if (owned) {
            const ownedText = this.add.text(70, 38, 'OWNED', {
                fontFamily: 'Arial',
                fontSize: '12px',
                color: '#00ff88'
            });
            container.add(ownedText);
        } else {
            const priceColor = item.currency === 'gems' ? '#00ffff' : '#ffaa00';
            const currencyIcon = item.currency === 'gems' ? '💎' : '🪙';
            
            const priceText = this.add.text(70, 38, `${currencyIcon} ${this.formatNumber(item.price)}`, {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: priceColor
            });
            container.add(priceText);
        }
        
        // Stats or description (if available)
        if (item.stats) {
            let statsStr = Object.entries(item.stats)
                .slice(0, 2)
                .map(([k, v]) => `${k}: ${v}`)
                .join(' | ');
            
            const statsText = this.add.text(10, 70, statsStr, {
                fontFamily: 'Arial',
                fontSize: '10px',
                color: '#667788'
            });
            container.add(statsText);
        }
        
        // Interactive
        const zone = this.add.zone(width / 2, height / 2, width, height)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.showItemDetail(item));
        zone.on('pointerover', () => {
            bg.clear();
            bg.fillStyle(bgColor, 1);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, borderColor, 1);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        zone.on('pointerout', () => {
            bg.clear();
            bg.fillStyle(bgColor, 0.9);
            bg.fillRoundedRect(0, 0, width, height, 8);
            bg.lineStyle(2, borderColor, 0.6);
            bg.strokeRoundedRect(0, 0, width, height, 8);
        });
        
        container.add(zone);
        
        return container;
    }
    
    /**
     * Render bundles list
     */
    renderBundles(bundles, width) {
        const bundleHeight = 140;
        
        bundles.forEach((bundle, index) => {
            const y = index * (bundleHeight + 15);
            const bundleContainer = this.createBundleCard(bundle, y, width - 30, bundleHeight);
            this.contentContainer.add(bundleContainer);
        });
    }
    
    /**
     * Create a bundle card
     */
    createBundleCard(bundle, y, width, height) {
        const container = this.add.container(15, y);
        
        // Background with gradient effect
        const bg = this.add.graphics();
        bg.fillStyle(0x2a2030, 0.95);
        bg.fillRoundedRect(0, 0, width, height, 10);
        bg.lineStyle(2, 0xffaa00, 0.8);
        bg.strokeRoundedRect(0, 0, width, height, 10);
        container.add(bg);
        
        // Discount badge
        if (bundle.discount) {
            const discountPct = Math.round(bundle.discount * 100);
            const badge = this.add.graphics();
            badge.fillStyle(0xff4444, 1);
            badge.fillRoundedRect(width - 70, 5, 65, 25, 4);
            container.add(badge);
            
            const discountText = this.add.text(width - 37, 17, `-${discountPct}%`, {
                fontFamily: 'Arial Black',
                fontSize: '14px',
                color: '#ffffff'
            }).setOrigin(0.5);
            container.add(discountText);
        }
        
        // Bundle name
        const name = this.add.text(15, 15, bundle.name, {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: '#ffaa00'
        });
        container.add(name);
        
        // Description
        const desc = this.add.text(15, 40, bundle.description || 'Special bundle offer', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#aabbcc'
        });
        container.add(desc);
        
        // Contents preview
        if (bundle.items) {
            const contentsStr = bundle.items.slice(0, 3).map(i => i.id || i.type).join(', ');
            const contents = this.add.text(15, 60, `Includes: ${contentsStr}`, {
                fontFamily: 'Arial',
                fontSize: '11px',
                color: '#667788'
            });
            container.add(contents);
        }
        
        // Price
        const priceY = height - 35;
        
        if (bundle.originalPrice) {
            const originalPrice = this.add.text(15, priceY, this.formatNumber(bundle.originalPrice), {
                fontFamily: 'Arial',
                fontSize: '14px',
                color: '#666666'
            });
            
            // Strikethrough
            const strikethrough = this.add.graphics();
            strikethrough.lineStyle(2, 0x666666, 0.8);
            strikethrough.lineBetween(15, priceY + 8, 15 + originalPrice.width, priceY + 8);
            container.add(originalPrice);
            container.add(strikethrough);
        }
        
        const priceColor = bundle.currency === 'gems' ? '#00ffff' : '#ffaa00';
        const currencyIcon = bundle.currency === 'gems' ? '💎' : '🪙';
        
        const salePrice = this.add.text(bundle.originalPrice ? 80 : 15, priceY, 
            `${currencyIcon} ${this.formatNumber(bundle.price)}`, {
            fontFamily: 'Arial Black',
            fontSize: '18px',
            color: priceColor
        });
        container.add(salePrice);
        
        // Buy button
        const buyBtn = this.add.text(width - 80, priceY, 'BUY', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#ffffff',
            backgroundColor: '#ff8800',
            padding: { x: 20, y: 8 }
        }).setOrigin(0.5, 0).setInteractive({ useHandCursor: true });
        
        buyBtn.on('pointerdown', () => this.purchaseBundle(bundle));
        buyBtn.on('pointerover', () => buyBtn.setAlpha(0.8));
        buyBtn.on('pointerout', () => buyBtn.setAlpha(1));
        
        container.add(buyBtn);
        
        return container;
    }
    
    /**
     * Create daily deals panel
     */
    createDailyDealsPanel(width) {
        // This could be shown as a floating panel or integrated into featured
        // For now, deals are part of featured category
    }
    
    /**
     * Create item detail panel
     */
    createDetailPanel(width, height) {
        this.detailPanel = this.add.container(width / 2, height / 2);
        this.detailPanel.setVisible(false);
        this.detailPanel.setDepth(100);
        
        // Overlay
        this.detailOverlay = this.add.graphics();
        this.detailOverlay.fillStyle(0x000000, 0.8);
        this.detailOverlay.fillRect(-width / 2, -height / 2, width, height);
        this.detailOverlay.setInteractive(
            new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height),
            Phaser.Geom.Rectangle.Contains
        );
        this.detailOverlay.on('pointerdown', () => this.hideDetail());
        this.detailPanel.add(this.detailOverlay);
    }
    
    /**
     * Show item detail
     */
    showItemDetail(item) {
        this.selectedItem = item;
        
        // Clear previous content
        while (this.detailPanel.length > 1) {
            this.detailPanel.removeAt(1, true);
        }
        
        const { width, height } = this.cameras.main;
        const panelWidth = Math.min(350, width - 40);
        const panelHeight = 320;
        
        const owned = window.ShopSystem && ShopSystem.ownsItem(item.category, item.id);
        const canAfford = window.ShopSystem && ShopSystem.canAfford(item);
        
        // Panel background
        const bg = this.add.graphics();
        bg.fillStyle(0x1a1520, 0.98);
        bg.fillRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, 12);
        
        const borderColor = item.premium ? 0xff44aa : 0xffaa00;
        bg.lineStyle(3, borderColor, 0.9);
        bg.strokeRoundedRect(-panelWidth / 2, -panelHeight / 2, panelWidth, panelHeight, 12);
        this.detailPanel.add(bg);
        
        // Item name
        const name = this.add.text(0, -panelHeight / 2 + 30, item.name, {
            fontFamily: 'Arial Black',
            fontSize: '22px',
            color: item.premium ? '#ff44aa' : '#ffaa00'
        }).setOrigin(0.5);
        this.detailPanel.add(name);
        
        // Item icon placeholder
        const iconBg = this.add.graphics();
        iconBg.fillStyle(0x0a1020, 0.9);
        iconBg.fillRoundedRect(-50, -panelHeight / 2 + 60, 100, 80, 8);
        this.detailPanel.add(iconBg);
        
        // Description
        const desc = this.add.text(0, -panelHeight / 2 + 170, item.description || 'A great item!', {
            fontFamily: 'Arial',
            fontSize: '14px',
            color: '#aabbcc',
            wordWrap: { width: panelWidth - 40 },
            align: 'center'
        }).setOrigin(0.5, 0);
        this.detailPanel.add(desc);
        
        // Stats if available
        if (item.stats) {
            const statsY = -panelHeight / 2 + 210;
            let statsX = -panelWidth / 2 + 30;
            
            Object.entries(item.stats).forEach(([key, value]) => {
                const statText = this.add.text(statsX, statsY, `${key}: ${value}`, {
                    fontFamily: 'Arial',
                    fontSize: '12px',
                    color: '#667788'
                });
                this.detailPanel.add(statText);
                statsX += 80;
            });
        }
        
        // Price or owned
        const priceY = panelHeight / 2 - 80;
        
        if (owned) {
            const ownedText = this.add.text(0, priceY, 'OWNED', {
                fontFamily: 'Arial Black',
                fontSize: '20px',
                color: '#00ff88'
            }).setOrigin(0.5);
            this.detailPanel.add(ownedText);
        } else {
            const priceColor = item.currency === 'gems' ? '#00ffff' : '#ffaa00';
            const currencyIcon = item.currency === 'gems' ? '💎' : '🪙';
            
            const priceText = this.add.text(0, priceY, `${currencyIcon} ${this.formatNumber(item.price)}`, {
                fontFamily: 'Arial Black',
                fontSize: '24px',
                color: priceColor
            }).setOrigin(0.5);
            this.detailPanel.add(priceText);
        }
        
        // Buy button
        if (!owned) {
            const btnColor = canAfford ? '#ff8800' : '#444444';
            const btnText = canAfford ? 'PURCHASE' : 'NOT ENOUGH';
            
            const buyBtn = this.add.text(0, panelHeight / 2 - 40, btnText, {
                fontFamily: 'Arial',
                fontSize: '16px',
                color: '#ffffff',
                backgroundColor: btnColor,
                padding: { x: 40, y: 12 }
            }).setOrigin(0.5);
            
            if (canAfford) {
                buyBtn.setInteractive({ useHandCursor: true });
                buyBtn.on('pointerdown', () => this.purchaseItem(item));
                buyBtn.on('pointerover', () => buyBtn.setAlpha(0.8));
                buyBtn.on('pointerout', () => buyBtn.setAlpha(1));
            }
            
            this.detailPanel.add(buyBtn);
        }
        
        // Close button
        const closeBtn = this.add.text(panelWidth / 2 - 20, -panelHeight / 2 + 20, 'X', {
            fontFamily: 'Arial Black',
            fontSize: '20px',
            color: '#667788'
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        
        closeBtn.on('pointerdown', () => this.hideDetail());
        closeBtn.on('pointerover', () => closeBtn.setColor('#ffffff'));
        closeBtn.on('pointerout', () => closeBtn.setColor('#667788'));
        
        this.detailPanel.add(closeBtn);
        
        // Show panel
        this.detailPanel.setVisible(true);
        this.detailPanel.setAlpha(0);
        this.detailPanel.setScale(0.9);
        
        this.tweens.add({
            targets: this.detailPanel,
            alpha: 1,
            scale: 1,
            duration: 200,
            ease: 'Back.easeOut'
        });
        
        if (window.SoundManager) {
            SoundManager.play('ui_click');
        }
    }
    
    /**
     * Hide detail panel
     */
    hideDetail() {
        this.tweens.add({
            targets: this.detailPanel,
            alpha: 0,
            scale: 0.9,
            duration: 150,
            onComplete: () => {
                this.detailPanel.setVisible(false);
                this.selectedItem = null;
            }
        });
    }
    
    /**
     * Purchase an item
     */
    purchaseItem(item) {
        if (!window.ShopSystem) return;
        
        const result = ShopSystem.purchaseItem(item.category + 's', item.id);
        
        if (result.success) {
            this.showPurchaseSuccess(item);
            this.updateCurrencyDisplay();
            this.hideDetail();
            this.renderCategoryContent();
        } else {
            this.showPurchaseError(result.error);
        }
    }
    
    /**
     * Purchase a bundle
     */
    purchaseBundle(bundle) {
        if (!window.ShopSystem) return;
        
        const result = ShopSystem.purchaseBundle(bundle.id);
        
        if (result.success) {
            this.showPurchaseSuccess(bundle);
            this.updateCurrencyDisplay();
            this.renderCategoryContent();
        } else {
            this.showPurchaseError(result.error);
        }
    }
    
    /**
     * Show purchase success
     */
    showPurchaseSuccess(item) {
        const { width, height } = this.cameras.main;
        
        const popup = this.add.text(width / 2, height / 2, `${item.name} Purchased!`, {
            fontFamily: 'Arial Black',
            fontSize: '24px',
            color: '#00ff88',
            stroke: '#004422',
            strokeThickness: 4
        }).setOrigin(0.5).setDepth(200);
        
        this.tweens.add({
            targets: popup,
            y: height / 2 - 50,
            alpha: 0,
            scale: 1.2,
            duration: 1000,
            ease: 'Power2',
            onComplete: () => popup.destroy()
        });
        
        if (window.SoundManager) {
            SoundManager.play('purchase');
        }
    }
    
    /**
     * Show purchase error
     */
    showPurchaseError(error) {
        const { width, height } = this.cameras.main;
        
        const popup = this.add.text(width / 2, height / 2, error || 'Purchase Failed', {
            fontFamily: 'Arial',
            fontSize: '18px',
            color: '#ff4444',
            stroke: '#440000',
            strokeThickness: 3
        }).setOrigin(0.5).setDepth(200);
        
        this.tweens.add({
            targets: popup,
            alpha: 0,
            duration: 2000,
            onComplete: () => popup.destroy()
        });
        
        if (window.SoundManager) {
            SoundManager.play('error');
        }
    }
    
    /**
     * Update currency display
     */
    updateCurrencyDisplay() {
        if (window.ShopSystem) {
            const currency = ShopSystem.getCurrency();
            this.coinsText.setText(this.formatNumber(currency.coins));
            this.gemsText.setText(this.formatNumber(currency.gems));
            this.shopData.currency = currency;
        }
    }
    
    /**
     * Create back button
     */
    createBackButton(width, height) {
        const container = this.add.container(width - 80, height - 50);
        
        const bg = this.add.graphics();
        bg.fillStyle(0x1a2535, 0.9);
        bg.fillRoundedRect(0, 0, 60, 35, 5);
        bg.lineStyle(2, 0xffaa00, 0.5);
        bg.strokeRoundedRect(0, 0, 60, 35, 5);
        
        const text = this.add.text(30, 17, 'BACK', {
            fontFamily: 'Arial',
            fontSize: '12px',
            color: '#ffaa00'
        }).setOrigin(0.5);
        
        const zone = this.add.zone(30, 17, 60, 35)
            .setInteractive({ useHandCursor: true });
        
        zone.on('pointerdown', () => this.goBack());
        
        container.add([bg, text, zone]);
    }
    
    /**
     * Setup input
     */
    setupInput() {
        this.input.keyboard.on('keydown-ESC', () => {
            if (this.detailPanel.visible) {
                this.hideDetail();
            } else {
                this.goBack();
            }
        });
        
        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            if (!this.detailPanel.visible) {
                this.scrollOffset = Phaser.Math.Clamp(
                    this.scrollOffset + deltaY * 0.5,
                    0,
                    this.maxScroll
                );
                this.contentContainer.y = 160 - this.scrollOffset;
            }
        });
    }
    
    /**
     * Go back
     */
    goBack() {
        if (window.SoundManager) {
            SoundManager.play('ui_back');
        }
        this.scene.start(this.returnScene);
    }
    
    /**
     * Animate scene in
     */
    animateIn() {
        this.cameras.main.setAlpha(0);
        this.tweens.add({
            targets: this.cameras.main,
            alpha: 1,
            duration: 300,
            ease: 'Power2'
        });
    }
    
    /**
     * Format number
     */
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return String(num);
    }
}

// Register scene
if (typeof window !== 'undefined') {
    window.ShopScene = ShopScene;
}
