/**
 * GRAVSHIFT - Settings Panel Component
 * Audio and control settings
 */

class SettingsPanel {
    constructor(scene) {
        this.scene = scene;
        this.container = scene.add.container(0, 0);
        this.container.setDepth(200);
        
        this.sliders = {};
        this.toggles = {};
        
        // Load current settings
        this.loadSettings();
    }
    
    loadSettings() {
        this.settings = {
            masterVolume: this.scene.registry.get('masterVolume') || 0.8,
            musicVolume: this.scene.registry.get('musicVolume') || 0.6,
            sfxVolume: this.scene.registry.get('sfxVolume') || 0.8,
            muted: this.scene.registry.get('muted') || false,
            screenShake: true,
            showFPS: false,
        };
    }
    
    create() {
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        const centerX = width / 2;
        
        // Panel background
        this.background = this.scene.add.graphics();
        this.background.fillStyle(0x0a0a0f, 0.95);
        this.background.fillRoundedRect(centerX - 250, 80, 500, height - 160, 16);
        this.background.lineStyle(2, 0x00ffff, 0.5);
        this.background.strokeRoundedRect(centerX - 250, 80, 500, height - 160, 16);
        this.container.add(this.background);
        
        // Title
        this.title = this.scene.add.text(centerX, 110, 'SETTINGS', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '32px',
            color: '#00ffff',
        }).setOrigin(0.5);
        this.container.add(this.title);
        
        let y = 170;
        
        // === AUDIO SECTION ===
        this.addSectionHeader(centerX, y, 'AUDIO');
        y += 40;
        
        // Master Volume
        this.createSlider(centerX, y, 'Master Volume', 'masterVolume', this.settings.masterVolume);
        y += 60;
        
        // Music Volume
        this.createSlider(centerX, y, 'Music Volume', 'musicVolume', this.settings.musicVolume);
        y += 60;
        
        // SFX Volume
        this.createSlider(centerX, y, 'SFX Volume', 'sfxVolume', this.settings.sfxVolume);
        y += 60;
        
        // Mute Toggle
        this.createToggle(centerX, y, 'Mute All', 'muted', this.settings.muted);
        y += 60;
        
        // === DISPLAY SECTION ===
        this.addSectionHeader(centerX, y, 'DISPLAY');
        y += 40;
        
        // Screen Shake
        this.createToggle(centerX, y, 'Screen Shake', 'screenShake', this.settings.screenShake);
        y += 50;
        
        // Show FPS
        this.createToggle(centerX, y, 'Show FPS', 'showFPS', this.settings.showFPS);
        y += 60;
        
        // === CONTROLS SECTION ===
        this.addSectionHeader(centerX, y, 'CONTROLS');
        y += 40;
        
        // Control hints
        const controlsText = this.scene.add.text(centerX, y, 
            '← → or A D : Steer\nSPACE or SHIFT : Boost\nESC or P : Pause', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '16px',
            color: '#888888',
            align: 'center',
        }).setOrigin(0.5, 0);
        this.container.add(controlsText);
        
        // Back button
        this.backButton = new Button(this.scene, centerX, height - 100, 'SAVE & BACK', {
            width: 180,
            color: 0x00ff00,
            onClick: () => this.saveAndClose(),
        });
        
        // Reset button
        this.resetButton = new Button(this.scene, centerX, height - 150, 'RESET DEFAULTS', {
            width: 180,
            color: 0xff0000,
            onClick: () => this.resetDefaults(),
        });
    }
    
    addSectionHeader(x, y, text) {
        const header = this.scene.add.text(x, y, text, {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: '16px',
            color: '#ff00ff',
        }).setOrigin(0.5);
        this.container.add(header);
        
        // Underline
        const line = this.scene.add.graphics();
        line.lineStyle(1, 0xff00ff, 0.5);
        line.lineBetween(x - 100, y + 15, x + 100, y + 15);
        this.container.add(line);
    }
    
    createSlider(x, y, label, key, value) {
        const sliderWidth = 200;
        const sliderX = x + 50;
        
        // Label
        const labelText = this.scene.add.text(x - 180, y, label, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '18px',
            color: '#ffffff',
        }).setOrigin(0, 0.5);
        this.container.add(labelText);
        
        // Slider background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x333333, 1);
        bg.fillRoundedRect(sliderX - sliderWidth / 2, y - 8, sliderWidth, 16, 8);
        this.container.add(bg);
        
        // Slider fill
        const fill = this.scene.add.graphics();
        this.container.add(fill);
        
        // Slider handle
        const handleX = sliderX - sliderWidth / 2 + sliderWidth * value;
        const handle = this.scene.add.graphics();
        handle.fillStyle(0x00ffff, 1);
        handle.fillCircle(0, 0, 12);
        handle.setPosition(handleX, y);
        this.container.add(handle);
        
        // Value text
        const valueText = this.scene.add.text(sliderX + sliderWidth / 2 + 30, y, 
            Math.round(value * 100) + '%', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '16px',
            color: '#00ffff',
        }).setOrigin(0, 0.5);
        this.container.add(valueText);
        
        // Update fill
        const updateFill = (val) => {
            fill.clear();
            fill.fillStyle(0x00ffff, 0.8);
            fill.fillRoundedRect(
                sliderX - sliderWidth / 2,
                y - 8,
                sliderWidth * val,
                16,
                8
            );
        };
        updateFill(value);
        
        // Interactive hit area
        const hitArea = this.scene.add.rectangle(sliderX, y, sliderWidth + 24, 32)
            .setInteractive({ useHandCursor: true, draggable: true });
        hitArea.setAlpha(0.01);
        this.container.add(hitArea);
        
        // Drag handling
        hitArea.on('drag', (pointer) => {
            const localX = pointer.x - (sliderX - sliderWidth / 2);
            let newValue = MathUtils.clamp(localX / sliderWidth, 0, 1);
            
            handle.setPosition(sliderX - sliderWidth / 2 + sliderWidth * newValue, y);
            valueText.setText(Math.round(newValue * 100) + '%');
            updateFill(newValue);
            
            this.settings[key] = newValue;
            this.scene.registry.set(key, newValue);
        });
        
        hitArea.on('pointerdown', (pointer) => {
            const localX = pointer.x - (sliderX - sliderWidth / 2);
            let newValue = MathUtils.clamp(localX / sliderWidth, 0, 1);
            
            handle.setPosition(sliderX - sliderWidth / 2 + sliderWidth * newValue, y);
            valueText.setText(Math.round(newValue * 100) + '%');
            updateFill(newValue);
            
            this.settings[key] = newValue;
            this.scene.registry.set(key, newValue);
        });
        
        this.sliders[key] = { bg, fill, handle, valueText, updateFill };
    }
    
    createToggle(x, y, label, key, value) {
        // Label
        const labelText = this.scene.add.text(x - 180, y, label, {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: '18px',
            color: '#ffffff',
        }).setOrigin(0, 0.5);
        this.container.add(labelText);
        
        // Toggle background
        const toggleX = x + 100;
        const bg = this.scene.add.graphics();
        this.container.add(bg);
        
        // Toggle indicator
        const indicator = this.scene.add.graphics();
        this.container.add(indicator);
        
        const updateToggle = (val) => {
            bg.clear();
            indicator.clear();
            
            bg.fillStyle(val ? 0x00ff00 : 0x333333, 1);
            bg.fillRoundedRect(toggleX - 25, y - 12, 50, 24, 12);
            
            indicator.fillStyle(0xffffff, 1);
            indicator.fillCircle(val ? toggleX + 13 : toggleX - 13, y, 10);
        };
        updateToggle(value);
        
        // Interactive
        const hitArea = this.scene.add.rectangle(toggleX, y, 60, 30)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.settings[key] = !this.settings[key];
                this.scene.registry.set(key, this.settings[key]);
                updateToggle(this.settings[key]);
            });
        hitArea.setAlpha(0.01);
        this.container.add(hitArea);
        
        this.toggles[key] = { bg, indicator, updateToggle };
    }
    
    resetDefaults() {
        this.settings = {
            masterVolume: 0.8,
            musicVolume: 0.6,
            sfxVolume: 0.8,
            muted: false,
            screenShake: true,
            showFPS: false,
        };
        
        // Update registry
        Object.entries(this.settings).forEach(([key, value]) => {
            this.scene.registry.set(key, value);
        });
        
        // Update UI
        Object.entries(this.sliders).forEach(([key, slider]) => {
            const value = this.settings[key];
            if (slider.updateFill) {
                slider.updateFill(value);
                slider.handle.setPosition(
                    slider.handle.x, // Recalculate based on value
                    slider.handle.y
                );
                slider.valueText.setText(Math.round(value * 100) + '%');
            }
        });
        
        Object.entries(this.toggles).forEach(([key, toggle]) => {
            if (toggle.updateToggle) {
                toggle.updateToggle(this.settings[key]);
            }
        });
    }
    
    saveAndClose() {
        // Save to localStorage
        try {
            localStorage.setItem(GAME_CONFIG.STORAGE.SETTINGS, JSON.stringify(this.settings));
        } catch (e) {
            console.warn('Could not save settings');
        }
        
        if (this.onClose) {
            this.onClose();
        }
    }
    
    setVisible(visible) {
        this.container.setVisible(visible);
        if (this.backButton) this.backButton.setVisible(visible);
        if (this.resetButton) this.resetButton.setVisible(visible);
    }
    
    destroy() {
        this.container.destroy();
        if (this.backButton) this.backButton.destroy();
        if (this.resetButton) this.resetButton.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.SettingsPanel = SettingsPanel;
}
