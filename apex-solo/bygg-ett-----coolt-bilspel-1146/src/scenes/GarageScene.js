/**
 * GRAVSHIFT - Garage Scene
 * Vehicle selection, upgrades, and customization
 */

class GarageScene extends Phaser.Scene {
    constructor() {
        super({ key: 'GarageScene' });
    }
    
    init() {
        this.currentTab = 'vehicles';
        this.selectedVehicleIndex = 0;
        this.selectedUpgrade = null;
        this.selectedSkin = null;
    }
    
    create() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Initialize managers
        this.garageManager = new GarageManager(this);
        this.audioManager = new AudioManager(this);
        if (this.registry.get('audioInitialized')) {
            this.audioManager.init();
        }
        
        // Background
        this.createBackground();
        
        // Title
        this.add.text(width / 2, 40, 'GARAGE', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '36px',
            color: '#ff00ff',
        }).setOrigin(0.5);
        
        // Currency display
        this.createCurrencyDisplay(width - 30, 40);
        
        // Tab navigation
        this.createTabs(width / 2, 100);
        
        // Content area
        this.contentContainer = this.add.container(0, 0);
        this.showVehiclesTab();
        
        // Back button
        this.createBackButton(100, height - 40);
        
        // Keyboard
        this.input.keyboard.on('keydown-ESC', () => this.goBack());
        
        // Fade in
        this.cameras.main.fadeIn(300);
    }
    
    createBackground() {
        const width = this.scale.width;
        const height = this.scale.height;
        
        // Dark background
        const bg = this.add.graphics();
        bg.fillGradientStyle(0x1a0a2e, 0x1a0a2e, 0x0a0a1f, 0x0a0a1f, 1);
        bg.fillRect(0, 0, width, height);
        
        // Grid pattern
        bg.lineStyle(1, 0xff00ff, 0.05);
        for (let x = 0; x < width; x += 50) {
            bg.lineBetween(x, 0, x, height);
        }
        for (let y = 0; y < height; y += 50) {
            bg.lineBetween(0, y, width, y);
        }
        
        // Garage floor effect
        bg.fillStyle(0x1a1a2e, 0.5);
        bg.fillRect(0, height / 2, width, height / 2);
    }
    
    createCurrencyDisplay(x, y) {
        const bg = this.add.graphics();
        bg.fillStyle(0x000000, 0.5);
        bg.fillRoundedRect(x - 150, y - 15, 150, 30, 8);
        
        // Coin icon
        this.add.graphics()
            .fillStyle(0xffff00, 1)
            .fillCircle(x - 130, y, 10);
        
        // Amount
        this.currencyText = this.add.text(x - 110, y, this.garageManager.getCurrencyDisplay(), {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '18px',
            color: '#ffff00',
        }).setOrigin(0, 0.5);
    }
    
    updateCurrencyDisplay() {
        this.currencyText.setText(this.garageManager.getCurrencyDisplay());
    }
    
    createTabs(centerX, y) {
        const tabs = [
            { key: 'vehicles', name: 'VEHICLES' },
            { key: 'upgrades', name: 'UPGRADES' },
            { key: 'skins', name: 'SKINS' },
        ];
        
        const tabWidth = 150;
        const totalWidth = tabs.length * tabWidth;
        const startX = centerX - totalWidth / 2 + tabWidth / 2;
        
        this.tabs = [];
        
        tabs.forEach((tab, index) => {
            const x = startX + index * tabWidth;
            const isSelected = tab.key === this.currentTab;
            
            const bg = this.add.graphics();
            this.drawTabBg(bg, x, y, tabWidth, isSelected);
            
            const text = this.add.text(x, y, tab.name, {
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '16px',
                color: isSelected ? '#ff00ff' : '#888888',
            }).setOrigin(0.5);
            
            const hitArea = this.add.rectangle(x, y, tabWidth - 10, 35)
                .setInteractive({ useHandCursor: true })
                .on('pointerdown', () => this.selectTab(tab.key));
            
            this.tabs.push({ key: tab.key, bg, text, x, y, width: tabWidth });
        });
    }
    
    drawTabBg(bg, x, y, width, isSelected) {
        bg.clear();
        bg.fillStyle(isSelected ? 0xff00ff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
        bg.fillRoundedRect(x - width / 2 + 5, y - 17, width - 10, 35, 4);
        bg.lineStyle(2, 0xff00ff, isSelected ? 1 : 0.3);
        bg.strokeRoundedRect(x - width / 2 + 5, y - 17, width - 10, 35, 4);
    }
    
    selectTab(tabKey) {
        this.currentTab = tabKey;
        
        // Update tab visuals
        this.tabs.forEach(tab => {
            const isSelected = tab.key === tabKey;
            this.drawTabBg(tab.bg, tab.x, tab.y, tab.width, isSelected);
            tab.text.setColor(isSelected ? '#ff00ff' : '#888888');
        });
        
        // Clear content
        this.contentContainer.removeAll(true);
        
        // Show appropriate content
        switch (tabKey) {
            case 'vehicles':
                this.showVehiclesTab();
                break;
            case 'upgrades':
                this.showUpgradesTab();
                break;
            case 'skins':
                this.showSkinsTab();
                break;
        }
        
        this.audioManager.playSFX('select');
    }
    
    showVehiclesTab() {
        const width = this.scale.width;
        const height = this.scale.height;
        const vehicles = this.garageManager.getShopVehicles();
        
        const cardWidth = 180;
        const cardHeight = 280;
        const padding = 20;
        const startX = padding + cardWidth / 2;
        const y = 300;
        
        // Vehicle cards
        vehicles.forEach((vehicle, index) => {
            const x = startX + index * (cardWidth + padding);
            if (x < width - cardWidth / 2) {
                this.createVehicleCard(vehicle, x, y, cardWidth, cardHeight, index);
            }
        });
        
        // Vehicle details panel (right side)
        this.createVehicleDetailsPanel(width - 300, 160, 280, height - 200);
    }
    
    createVehicleCard(vehicle, x, y, width, height, index) {
        const isOwned = vehicle.owned;
        const isUnlocked = vehicle.unlocked;
        const isSelected = vehicle.id === this.garageManager.selectedVehicle;
        
        // Card background
        const bg = this.add.graphics();
        bg.fillStyle(isSelected ? 0xff00ff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
        bg.fillRoundedRect(x - width / 2, y - height / 2, width, height, 12);
        bg.lineStyle(3, isOwned ? vehicle.color : 0x333333, isOwned ? 1 : 0.5);
        bg.strokeRoundedRect(x - width / 2, y - height / 2, width, height, 12);
        this.contentContainer.add(bg);
        
        // Vehicle preview
        const previewBg = this.add.graphics();
        previewBg.fillStyle(0x0a0a0f, 1);
        previewBg.fillRoundedRect(x - width / 2 + 10, y - height / 2 + 10, width - 20, 100, 8);
        this.contentContainer.add(previewBg);
        
        // Draw vehicle shape
        const vehicleGraphics = this.add.graphics();
        if (isOwned || isUnlocked) {
            vehicleGraphics.fillStyle(vehicle.color, 1);
            vehicleGraphics.fillTriangle(x, y - height / 2 + 35, x - 25, y - height / 2 + 90, x + 25, y - height / 2 + 90);
            vehicleGraphics.lineStyle(2, ColorUtils.lighten(vehicle.color, 0.3), 1);
            vehicleGraphics.strokeTriangle(x, y - height / 2 + 35, x - 25, y - height / 2 + 90, x + 25, y - height / 2 + 90);
        } else {
            // Locked silhouette
            vehicleGraphics.fillStyle(0x333333, 0.5);
            vehicleGraphics.fillTriangle(x, y - height / 2 + 35, x - 25, y - height / 2 + 90, x + 25, y - height / 2 + 90);
            
            const lockText = this.add.text(x, y - height / 2 + 60, '🔒', {
                fontSize: '24px',
            }).setOrigin(0.5);
            this.contentContainer.add(lockText);
        }
        this.contentContainer.add(vehicleGraphics);
        
        // Name
        const name = this.add.text(x, y - height / 2 + 130, vehicle.name, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '16px',
            color: isOwned ? '#ffffff' : '#888888',
        }).setOrigin(0.5);
        this.contentContainer.add(name);
        
        // Stats preview
        const statsY = y - height / 2 + 160;
        this.createMiniStatBar('SPD', vehicle.stats.maxSpeed / 10, x, statsY, width - 30, vehicle.color);
        this.createMiniStatBar('ACC', vehicle.stats.acceleration / 8, x, statsY + 25, width - 30, vehicle.color);
        this.createMiniStatBar('HDL', vehicle.stats.handling * 20, x, statsY + 50, width - 30, vehicle.color);
        
        // Price or status
        let statusText = '';
        let statusColor = '#ffffff';
        
        if (isOwned) {
            if (isSelected) {
                statusText = 'EQUIPPED';
                statusColor = '#00ff00';
            } else {
                statusText = 'OWNED';
                statusColor = '#00ffff';
            }
        } else if (!isUnlocked) {
            statusText = 'LOCKED';
            statusColor = '#ff0000';
        } else {
            statusText = `${MathUtils.formatNumber(vehicle.price)} GP`;
            statusColor = vehicle.canAfford ? '#ffff00' : '#ff0000';
        }
        
        const status = this.add.text(x, y + height / 2 - 30, statusText, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '14px',
            color: statusColor,
        }).setOrigin(0.5);
        this.contentContainer.add(status);
        
        // Interactive
        const hitArea = this.add.rectangle(x, y, width, height)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => this.onVehicleClick(vehicle, index));
        this.contentContainer.add(hitArea);
    }
    
    createMiniStatBar(label, value, x, y, width, color) {
        const barWidth = width - 40;
        const barHeight = 8;
        
        // Label
        const labelText = this.add.text(x - width / 2 + 5, y, label, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '10px',
            color: '#888888',
        });
        this.contentContainer.add(labelText);
        
        // Bar background
        const bg = this.add.graphics();
        bg.fillStyle(0x333333, 1);
        bg.fillRoundedRect(x - width / 2 + 35, y, barWidth, barHeight, 2);
        this.contentContainer.add(bg);
        
        // Bar fill
        const fill = this.add.graphics();
        fill.fillStyle(color, 0.8);
        fill.fillRoundedRect(x - width / 2 + 35, y, barWidth * Math.min(value / 100, 1), barHeight, 2);
        this.contentContainer.add(fill);
    }
    
    createVehicleDetailsPanel(x, y, width, height) {
        const vehicle = this.garageManager.vehicleShop[this.garageManager.selectedVehicle];
        if (!vehicle) return;
        
        // Panel background
        const bg = this.add.graphics();
        bg.fillStyle(0x0a0a0f, 0.9);
        bg.fillRoundedRect(x, y, width, height, 12);
        bg.lineStyle(2, 0xff00ff, 0.5);
        bg.strokeRoundedRect(x, y, width, height, 12);
        this.contentContainer.add(bg);
        
        // Vehicle name
        const name = this.add.text(x + width / 2, y + 20, vehicle.name, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '24px',
            color: '#ffffff',
        }).setOrigin(0.5);
        this.contentContainer.add(name);
        
        // Description
        const desc = this.add.text(x + 15, y + 50, vehicle.description, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '14px',
            color: '#888888',
            wordWrap: { width: width - 30 },
        });
        this.contentContainer.add(desc);
        
        // Stats
        const stats = this.garageManager.getVehicleStats(vehicle.id);
        const statsY = y + 100;
        
        this.createDetailStatBar('Max Speed', stats.maxSpeed, 1000, x + 15, statsY, width - 30);
        this.createDetailStatBar('Acceleration', stats.acceleration, 800, x + 15, statsY + 40, width - 30);
        this.createDetailStatBar('Handling', stats.handling * 20, 100, x + 15, statsY + 80, width - 30);
        this.createDetailStatBar('Boost Power', stats.boost * 50, 100, x + 15, statsY + 120, width - 30);
        this.createDetailStatBar('Nitro Tank', stats.nitro, 150, x + 15, statsY + 160, width - 30);
    }
    
    createDetailStatBar(label, value, max, x, y, width) {
        const barWidth = width - 10;
        const barHeight = 15;
        
        // Label and value
        const labelText = this.add.text(x, y, `${label}: ${Math.round(value)}`, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#ffffff',
        });
        this.contentContainer.add(labelText);
        
        // Bar background
        const bg = this.add.graphics();
        bg.fillStyle(0x333333, 1);
        bg.fillRoundedRect(x, y + 18, barWidth, barHeight, 4);
        this.contentContainer.add(bg);
        
        // Bar fill
        const percent = Math.min(value / max, 1);
        const color = percent > 0.7 ? 0x00ff00 : (percent > 0.4 ? 0xffff00 : 0xff0000);
        const fill = this.add.graphics();
        fill.fillStyle(color, 0.8);
        fill.fillRoundedRect(x, y + 18, barWidth * percent, barHeight, 4);
        this.contentContainer.add(fill);
    }
    
    onVehicleClick(vehicle, index) {
        if (vehicle.owned) {
            // Select this vehicle
            this.garageManager.selectVehicle(vehicle.id);
            this.selectTab('vehicles'); // Refresh
            this.audioManager.playSFX('select');
        } else if (vehicle.unlocked && vehicle.canAfford) {
            // Purchase
            const result = this.garageManager.purchaseVehicle(vehicle.id);
            if (result.success) {
                this.updateCurrencyDisplay();
                this.selectTab('vehicles'); // Refresh
                this.audioManager.playSFX('powerup');
            }
        } else {
            this.audioManager.playSFX('hit');
        }
    }
    
    showUpgradesTab() {
        const width = this.scale.width;
        const height = this.scale.height;
        const vehicle = this.garageManager.vehicleShop[this.garageManager.selectedVehicle];
        const upgrades = Object.values(this.garageManager.upgradeShop);
        
        // Current vehicle info
        this.add.text(width / 2, 150, `Upgrades for: ${vehicle.name}`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#ffffff',
        }).setOrigin(0.5);
        this.contentContainer.add(this.add.text(width / 2, 150, `Upgrades for: ${vehicle.name}`, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '20px',
            color: '#ffffff',
        }).setOrigin(0.5));
        
        // Upgrade cards
        const cardWidth = 180;
        const cardHeight = 150;
        const padding = 20;
        const startX = (width - (upgrades.length * (cardWidth + padding) - padding)) / 2 + cardWidth / 2;
        const y = 300;
        
        upgrades.forEach((upgrade, index) => {
            const x = startX + index * (cardWidth + padding);
            this.createUpgradeCard(upgrade, vehicle.id, x, y, cardWidth, cardHeight);
        });
    }
    
    createUpgradeCard(upgrade, vehicleId, x, y, width, height) {
        const currentLevel = this.garageManager.getUpgradeLevel(vehicleId, upgrade.id);
        const isMaxed = currentLevel >= upgrade.maxLevel;
        const price = this.garageManager.getUpgradePrice(upgrade.id, currentLevel);
        const canAfford = this.garageManager.canAfford(price);
        
        // Card background
        const bg = this.add.graphics();
        bg.fillStyle(0x1a1a2e, 0.8);
        bg.fillRoundedRect(x - width / 2, y - height / 2, width, height, 12);
        bg.lineStyle(2, isMaxed ? 0x00ff00 : 0xff00ff, 0.5);
        bg.strokeRoundedRect(x - width / 2, y - height / 2, width, height, 12);
        this.contentContainer.add(bg);
        
        // Name
        const name = this.add.text(x, y - height / 2 + 20, upgrade.name, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '14px',
            color: '#ffffff',
        }).setOrigin(0.5);
        this.contentContainer.add(name);
        
        // Level indicator
        const levelY = y - height / 2 + 50;
        for (let i = 0; i < upgrade.maxLevel; i++) {
            const dotX = x - (upgrade.maxLevel - 1) * 10 + i * 20;
            const dotGraphics = this.add.graphics();
            dotGraphics.fillStyle(i < currentLevel ? 0x00ff00 : 0x333333, 1);
            dotGraphics.fillCircle(dotX, levelY, 6);
            this.contentContainer.add(dotGraphics);
        }
        
        // Description
        const desc = this.add.text(x, y + 10, upgrade.description, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '11px',
            color: '#888888',
            wordWrap: { width: width - 20 },
            align: 'center',
        }).setOrigin(0.5);
        this.contentContainer.add(desc);
        
        // Price or maxed
        let statusText = isMaxed ? 'MAXED' : `${MathUtils.formatNumber(price)} GP`;
        let statusColor = isMaxed ? '#00ff00' : (canAfford ? '#ffff00' : '#ff0000');
        
        const status = this.add.text(x, y + height / 2 - 20, statusText, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '14px',
            color: statusColor,
        }).setOrigin(0.5);
        this.contentContainer.add(status);
        
        // Interactive
        if (!isMaxed) {
            const hitArea = this.add.rectangle(x, y, width, height)
                .setInteractive({ useHandCursor: true })
                .on('pointerdown', () => this.onUpgradeClick(upgrade, vehicleId));
            this.contentContainer.add(hitArea);
        }
    }
    
    onUpgradeClick(upgrade, vehicleId) {
        const result = this.garageManager.purchaseUpgrade(vehicleId, upgrade.id);
        if (result.success) {
            this.updateCurrencyDisplay();
            this.selectTab('upgrades'); // Refresh
            this.audioManager.playSFX('powerup');
        } else {
            this.audioManager.playSFX('hit');
        }
    }
    
    showSkinsTab() {
        const width = this.scale.width;
        const height = this.scale.height;
        const skins = this.garageManager.getShopSkins();
        
        const cardWidth = 120;
        const cardHeight = 150;
        const padding = 15;
        const cols = Math.floor((width - 100) / (cardWidth + padding));
        const startX = (width - (cols * (cardWidth + padding) - padding)) / 2 + cardWidth / 2;
        
        skins.forEach((skin, index) => {
            const col = index % cols;
            const row = Math.floor(index / cols);
            const x = startX + col * (cardWidth + padding);
            const y = 220 + row * (cardHeight + padding);
            
            if (y < height - 100) {
                this.createSkinCard(skin, x, y, cardWidth, cardHeight);
            }
        });
    }
    
    createSkinCard(skin, x, y, width, height) {
        const isOwned = skin.owned;
        const isUnlocked = skin.unlocked;
        const isSelected = skin.id === this.garageManager.selectedSkin;
        
        // Card background
        const bg = this.add.graphics();
        bg.fillStyle(isSelected ? 0xff00ff : 0x1a1a2e, isSelected ? 0.3 : 0.8);
        bg.fillRoundedRect(x - width / 2, y - height / 2, width, height, 8);
        this.contentContainer.add(bg);
        
        // Color preview
        const previewBg = this.add.graphics();
        previewBg.fillStyle(0x0a0a0f, 1);
        previewBg.fillRoundedRect(x - width / 2 + 10, y - height / 2 + 10, width - 20, 60, 4);
        this.contentContainer.add(previewBg);
        
        // Draw color samples
        if (skin.colors) {
            const colorGraphics = this.add.graphics();
            const primary = skin.colors.primary === 'rainbow' || skin.colors.primary === 'pulse' 
                ? 0x00ffff : skin.colors.primary;
            colorGraphics.fillStyle(primary, 1);
            colorGraphics.fillCircle(x - 20, y - height / 2 + 40, 15);
            colorGraphics.fillStyle(skin.colors.secondary === 'rainbow' ? 0xff00ff : skin.colors.secondary, 1);
            colorGraphics.fillCircle(x + 20, y - height / 2 + 40, 15);
            this.contentContainer.add(colorGraphics);
        }
        
        // Name
        const name = this.add.text(x, y + 10, skin.name, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '12px',
            color: '#ffffff',
        }).setOrigin(0.5);
        this.contentContainer.add(name);
        
        // Status
        let statusText = '';
        let statusColor = '#ffffff';
        
        if (isOwned) {
            statusText = isSelected ? 'EQUIPPED' : 'OWNED';
            statusColor = isSelected ? '#00ff00' : '#00ffff';
        } else if (!isUnlocked) {
            statusText = 'LOCKED';
            statusColor = '#ff0000';
        } else {
            statusText = `${skin.price} GP`;
            statusColor = skin.canAfford ? '#ffff00' : '#ff0000';
        }
        
        const status = this.add.text(x, y + height / 2 - 15, statusText, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '10px',
            color: statusColor,
        }).setOrigin(0.5);
        this.contentContainer.add(status);
        
        // Interactive
        const hitArea = this.add.rectangle(x, y, width, height)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => this.onSkinClick(skin));
        this.contentContainer.add(hitArea);
    }
    
    onSkinClick(skin) {
        if (skin.owned) {
            this.garageManager.selectSkin(skin.id);
            this.selectTab('skins');
            this.audioManager.playSFX('select');
        } else if (skin.unlocked && skin.canAfford) {
            const result = this.garageManager.purchaseSkin(skin.id);
            if (result.success) {
                this.updateCurrencyDisplay();
                this.selectTab('skins');
                this.audioManager.playSFX('powerup');
            }
        } else {
            this.audioManager.playSFX('hit');
        }
    }
    
    createBackButton(x, y) {
        const bg = this.add.graphics();
        bg.fillStyle(0x1a1a2e, 0.8);
        bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
        bg.lineStyle(2, 0x00ffff, 0.5);
        bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
        
        const text = this.add.text(x, y, '← BACK', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '18px',
            color: '#00ffff',
        }).setOrigin(0.5);
        
        this.add.rectangle(x, y, 160, 40)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                bg.clear();
                bg.fillStyle(0x00ffff, 0.2);
                bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
                bg.lineStyle(2, 0x00ffff, 1);
                bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
                text.setColor('#ffffff');
            })
            .on('pointerout', () => {
                bg.clear();
                bg.fillStyle(0x1a1a2e, 0.8);
                bg.fillRoundedRect(x - 80, y - 20, 160, 40, 8);
                bg.lineStyle(2, 0x00ffff, 0.5);
                bg.strokeRoundedRect(x - 80, y - 20, 160, 40, 8);
                text.setColor('#00ffff');
            })
            .on('pointerdown', () => this.goBack());
    }
    
    goBack() {
        this.audioManager.playSFX('select');
        this.cameras.main.fadeOut(300);
        this.cameras.main.once('camerafadeoutcomplete', () => {
            this.scene.start('MenuScene');
        });
    }
}

// Export
if (typeof window !== 'undefined') {
    window.GarageScene = GarageScene;
}
