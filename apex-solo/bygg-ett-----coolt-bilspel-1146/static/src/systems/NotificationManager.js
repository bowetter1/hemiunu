/**
 * NotificationManager.js
 * In-game notification system for achievements, rewards, and messages
 * Part of GRAVSHIFT - A gravity-defying racing game
 */

class NotificationManager {
    constructor(scene) {
        this.scene = scene;
        
        // Notification queue
        this.queue = [];
        this.activeNotifications = [];
        this.maxVisible = 5;
        
        // Configuration
        this.config = {
            position: 'top-right', // top-left, top-right, bottom-left, bottom-right, top-center, bottom-center
            spacing: 10,
            animationDuration: 300,
            defaultDuration: 4000,
            maxWidth: 350,
            minWidth: 200
        };
        
        // Container
        this.container = null;
        
        // Notification types with styling
        this.types = {
            info: {
                icon: 'ℹ️',
                color: 0x3388ff,
                bgColor: 0x1a2a4a,
                sound: 'info'
            },
            success: {
                icon: '✅',
                color: 0x00ff88,
                bgColor: 0x1a3a2a,
                sound: 'success'
            },
            warning: {
                icon: '⚠️',
                color: 0xffaa00,
                bgColor: 0x3a2a1a,
                sound: 'warning'
            },
            error: {
                icon: '❌',
                color: 0xff4444,
                bgColor: 0x3a1a1a,
                sound: 'error'
            },
            achievement: {
                icon: '🏆',
                color: 0xffd700,
                bgColor: 0x3a3a1a,
                sound: 'achievement'
            },
            levelUp: {
                icon: '⭐',
                color: 0x9966ff,
                bgColor: 0x2a1a3a,
                sound: 'levelUp'
            },
            reward: {
                icon: '🎁',
                color: 0xff66ff,
                bgColor: 0x3a1a3a,
                sound: 'reward'
            },
            challenge: {
                icon: '🎯',
                color: 0x00ffaa,
                bgColor: 0x1a3a3a,
                sound: 'challenge'
            },
            social: {
                icon: '👥',
                color: 0x66aaff,
                bgColor: 0x1a2a3a,
                sound: 'social'
            },
            system: {
                icon: '⚙️',
                color: 0xaaaaaa,
                bgColor: 0x2a2a2a,
                sound: 'system'
            }
        };
        
        // Sound effects
        this.sounds = {};
        
        // Priority levels
        this.priorities = {
            low: 0,
            normal: 1,
            high: 2,
            critical: 3
        };
        
        // History
        this.history = [];
        this.maxHistory = 100;
        
        // Settings
        this.settings = {
            enabled: true,
            soundEnabled: true,
            achievementsEnabled: true,
            socialEnabled: true,
            systemEnabled: true,
            groupSimilar: true,
            pauseOnHover: true
        };
        
        // Initialize
        this.init();
    }
    
    /**
     * Initialize the notification manager
     */
    init() {
        // Create container
        this.createContainer();
        
        // Load settings
        this.loadSettings();
        
        // Generate sound effects
        this.generateSounds();
        
        // Start update loop
        if (this.scene && this.scene.events) {
            this.scene.events.on('update', this.update, this);
            this.scene.events.once('shutdown', this.destroy, this);
        }
    }
    
    /**
     * Create notification container
     */
    createContainer() {
        if (!this.scene) return;
        
        this.container = this.scene.add.container(0, 0);
        this.container.setDepth(10000);
        
        this.updateContainerPosition();
    }
    
    /**
     * Update container position based on settings
     */
    updateContainerPosition() {
        if (!this.scene || !this.container) return;
        
        const width = this.scene.cameras.main.width;
        const height = this.scene.cameras.main.height;
        const padding = 20;
        
        switch (this.config.position) {
            case 'top-left':
                this.container.setPosition(padding, padding);
                break;
            case 'top-right':
                this.container.setPosition(width - padding, padding);
                break;
            case 'bottom-left':
                this.container.setPosition(padding, height - padding);
                break;
            case 'bottom-right':
                this.container.setPosition(width - padding, height - padding);
                break;
            case 'top-center':
                this.container.setPosition(width / 2, padding);
                break;
            case 'bottom-center':
                this.container.setPosition(width / 2, height - padding);
                break;
        }
    }
    
    /**
     * Show a notification
     */
    show(options) {
        if (!this.settings.enabled) return null;
        
        // Normalize options
        const notification = this.normalizeOptions(options);
        
        // Check if should be shown based on settings
        if (!this.shouldShow(notification)) return null;
        
        // Check for grouping
        if (this.settings.groupSimilar) {
            const existing = this.findSimilar(notification);
            if (existing) {
                this.incrementGroup(existing);
                return existing.id;
            }
        }
        
        // Add to queue
        this.queue.push(notification);
        
        // Sort queue by priority
        this.queue.sort((a, b) => b.priority - a.priority);
        
        // Process queue
        this.processQueue();
        
        // Add to history
        this.addToHistory(notification);
        
        return notification.id;
    }
    
    /**
     * Normalize notification options
     */
    normalizeOptions(options) {
        if (typeof options === 'string') {
            options = { message: options };
        }
        
        const type = this.types[options.type] || this.types.info;
        
        return {
            id: 'notif_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9),
            type: options.type || 'info',
            title: options.title || null,
            message: options.message || '',
            icon: options.icon || type.icon,
            color: options.color || type.color,
            bgColor: options.bgColor || type.bgColor,
            duration: options.duration || this.config.defaultDuration,
            priority: this.priorities[options.priority] || this.priorities.normal,
            sound: options.sound !== false,
            dismissible: options.dismissible !== false,
            action: options.action || null,
            actionLabel: options.actionLabel || 'View',
            data: options.data || null,
            groupKey: options.groupKey || null,
            groupCount: 1,
            timestamp: Date.now()
        };
    }
    
    /**
     * Check if notification should be shown
     */
    shouldShow(notification) {
        switch (notification.type) {
            case 'achievement':
                return this.settings.achievementsEnabled;
            case 'social':
                return this.settings.socialEnabled;
            case 'system':
                return this.settings.systemEnabled;
            default:
                return true;
        }
    }
    
    /**
     * Find similar notification for grouping
     */
    findSimilar(notification) {
        if (!notification.groupKey) return null;
        
        return this.activeNotifications.find(n => 
            n.groupKey === notification.groupKey && 
            Date.now() - n.timestamp < 5000
        );
    }
    
    /**
     * Increment group count
     */
    incrementGroup(notification) {
        notification.groupCount++;
        this.updateNotificationDisplay(notification);
    }
    
    /**
     * Process notification queue
     */
    processQueue() {
        while (this.queue.length > 0 && this.activeNotifications.length < this.maxVisible) {
            const notification = this.queue.shift();
            this.displayNotification(notification);
        }
    }
    
    /**
     * Display a notification
     */
    displayNotification(notification) {
        if (!this.scene || !this.container) return;
        
        // Create notification container
        const notifContainer = this.scene.add.container(0, 0);
        notification.container = notifContainer;
        
        // Calculate dimensions
        const width = this.calculateWidth(notification);
        const height = this.calculateHeight(notification);
        notification.width = width;
        notification.height = height;
        
        // Create background
        const bg = this.scene.add.graphics();
        bg.fillStyle(notification.bgColor, 0.95);
        bg.fillRoundedRect(0, 0, width, height, 10);
        bg.lineStyle(2, notification.color, 0.8);
        bg.strokeRoundedRect(0, 0, width, height, 10);
        notifContainer.add(bg);
        notification.bg = bg;
        
        // Accent bar
        const accentBar = this.scene.add.graphics();
        accentBar.fillStyle(notification.color, 1);
        accentBar.fillRoundedRect(0, 0, 4, height, { tl: 10, bl: 10, tr: 0, br: 0 });
        notifContainer.add(accentBar);
        
        // Icon
        const icon = this.scene.add.text(20, height / 2, notification.icon, {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        notifContainer.add(icon);
        
        // Title
        let textY = notification.title ? 15 : height / 2;
        if (notification.title) {
            const title = this.scene.add.text(50, textY, notification.title, {
                fontSize: '14px',
                fontFamily: 'Arial Black',
                color: '#ffffff',
                wordWrap: { width: width - 80 }
            }).setOrigin(0, 0.5);
            notifContainer.add(title);
            textY += 20;
        }
        
        // Message
        const message = this.scene.add.text(50, textY, notification.message, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#cccccc',
            wordWrap: { width: width - 80 }
        }).setOrigin(0, notification.title ? 0 : 0.5);
        notifContainer.add(message);
        
        // Group count badge
        if (notification.groupCount > 1) {
            this.addGroupBadge(notifContainer, notification);
        }
        
        // Action button
        if (notification.action) {
            this.addActionButton(notifContainer, notification);
        }
        
        // Dismiss button
        if (notification.dismissible) {
            this.addDismissButton(notifContainer, notification);
        }
        
        // Progress bar
        const progressBar = this.scene.add.graphics();
        progressBar.fillStyle(notification.color, 0.5);
        progressBar.fillRect(4, height - 3, width - 8, 3);
        notifContainer.add(progressBar);
        notification.progressBar = progressBar;
        notification.progress = 1;
        
        // Position notification
        this.positionNotification(notifContainer, notification);
        
        // Add to active list
        this.activeNotifications.push(notification);
        
        // Add to container
        this.container.add(notifContainer);
        
        // Animate in
        this.animateIn(notifContainer, notification);
        
        // Play sound
        if (notification.sound && this.settings.soundEnabled) {
            this.playSound(notification.type);
        }
        
        // Make interactive
        this.makeInteractive(notifContainer, notification);
        
        // Set dismiss timer
        if (notification.duration > 0) {
            notification.timer = this.scene.time.delayedCall(
                notification.duration,
                () => this.dismiss(notification.id)
            );
        }
    }
    
    /**
     * Calculate notification width
     */
    calculateWidth(notification) {
        // Estimate based on content
        const titleLength = notification.title ? notification.title.length * 8 : 0;
        const messageLength = notification.message.length * 6;
        const contentWidth = Math.max(titleLength, messageLength) + 80;
        
        return Math.max(this.config.minWidth, Math.min(this.config.maxWidth, contentWidth));
    }
    
    /**
     * Calculate notification height
     */
    calculateHeight(notification) {
        let height = 60;
        if (notification.title) height += 10;
        if (notification.action) height += 20;
        if (notification.message.length > 40) height += 15;
        return height;
    }
    
    /**
     * Position notification based on config
     */
    positionNotification(container, notification) {
        const index = this.activeNotifications.length;
        let y = 0;
        
        // Calculate Y based on existing notifications
        for (const notif of this.activeNotifications) {
            y += notif.height + this.config.spacing;
        }
        
        // Adjust based on position
        const pos = this.config.position;
        const isBottom = pos.includes('bottom');
        const isRight = pos.includes('right');
        const isCenter = pos.includes('center');
        
        let x = 0;
        if (isRight) {
            x = -notification.width;
        } else if (isCenter) {
            x = -notification.width / 2;
        }
        
        if (isBottom) {
            y = -y - notification.height;
        }
        
        container.setPosition(x, y);
        notification.targetX = x;
        notification.targetY = y;
    }
    
    /**
     * Animate notification in
     */
    animateIn(container, notification) {
        const pos = this.config.position;
        const isRight = pos.includes('right');
        const isLeft = pos.includes('left');
        
        // Start position
        let startX = notification.targetX;
        if (isRight) {
            startX = 100;
        } else if (isLeft) {
            startX = -notification.width - 100;
        }
        
        container.setPosition(startX, notification.targetY);
        container.setAlpha(0);
        
        // Animate to target position
        this.scene.tweens.add({
            targets: container,
            x: notification.targetX,
            alpha: 1,
            duration: this.config.animationDuration,
            ease: 'Back.easeOut'
        });
    }
    
    /**
     * Animate notification out
     */
    animateOut(notification, callback) {
        if (!notification.container) {
            if (callback) callback();
            return;
        }
        
        const pos = this.config.position;
        const isRight = pos.includes('right');
        
        let targetX = isRight ? 100 : -notification.width - 100;
        
        this.scene.tweens.add({
            targets: notification.container,
            x: targetX,
            alpha: 0,
            duration: this.config.animationDuration,
            ease: 'Back.easeIn',
            onComplete: callback
        });
    }
    
    /**
     * Add group count badge
     */
    addGroupBadge(container, notification) {
        const badgeX = notification.width - 20;
        const badgeY = 15;
        
        const badge = this.scene.add.graphics();
        badge.fillStyle(notification.color, 1);
        badge.fillCircle(badgeX, badgeY, 12);
        container.add(badge);
        notification.badge = badge;
        
        const count = this.scene.add.text(badgeX, badgeY, notification.groupCount.toString(), {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#000000'
        }).setOrigin(0.5, 0.5);
        container.add(count);
        notification.badgeText = count;
    }
    
    /**
     * Add action button
     */
    addActionButton(container, notification) {
        const buttonY = notification.height - 25;
        const buttonWidth = 60;
        const buttonX = notification.width - buttonWidth - 15;
        
        const button = this.scene.add.graphics();
        button.fillStyle(notification.color, 0.3);
        button.fillRoundedRect(buttonX, buttonY, buttonWidth, 20, 10);
        container.add(button);
        
        const text = this.scene.add.text(buttonX + buttonWidth / 2, buttonY + 10, notification.actionLabel, {
            fontSize: '10px',
            fontFamily: 'Arial Black',
            color: '#' + notification.color.toString(16)
        }).setOrigin(0.5, 0.5);
        container.add(text);
        
        // Make button interactive
        const zone = this.scene.add.zone(buttonX + buttonWidth / 2, buttonY + 10, buttonWidth, 20)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                button.clear();
                button.fillStyle(notification.color, 0.6);
                button.fillRoundedRect(buttonX, buttonY, buttonWidth, 20, 10);
            })
            .on('pointerout', () => {
                button.clear();
                button.fillStyle(notification.color, 0.3);
                button.fillRoundedRect(buttonX, buttonY, buttonWidth, 20, 10);
            })
            .on('pointerdown', () => {
                if (notification.action) {
                    notification.action(notification.data);
                }
                this.dismiss(notification.id);
            });
        container.add(zone);
    }
    
    /**
     * Add dismiss button
     */
    addDismissButton(container, notification) {
        const x = notification.width - 15;
        const y = 10;
        
        const closeBtn = this.scene.add.text(x, y, '×', {
            fontSize: '18px',
            fontFamily: 'Arial',
            color: '#888888'
        }).setOrigin(0.5, 0.5)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => closeBtn.setColor('#ffffff'))
            .on('pointerout', () => closeBtn.setColor('#888888'))
            .on('pointerdown', () => this.dismiss(notification.id));
        container.add(closeBtn);
    }
    
    /**
     * Make notification interactive
     */
    makeInteractive(container, notification) {
        // Create hit zone
        const zone = this.scene.add.zone(
            notification.width / 2, 
            notification.height / 2, 
            notification.width, 
            notification.height
        ).setInteractive();
        container.add(zone);
        
        // Pause on hover
        if (this.settings.pauseOnHover) {
            zone.on('pointerover', () => {
                notification.paused = true;
                if (notification.timer) {
                    notification.timer.paused = true;
                }
            });
            
            zone.on('pointerout', () => {
                notification.paused = false;
                if (notification.timer) {
                    notification.timer.paused = false;
                }
            });
        }
        
        // Click to dismiss (if no action)
        if (!notification.action) {
            zone.on('pointerdown', () => {
                this.dismiss(notification.id);
            });
        }
    }
    
    /**
     * Update notification display (for grouping)
     */
    updateNotificationDisplay(notification) {
        if (notification.badgeText) {
            notification.badgeText.setText(notification.groupCount.toString());
        }
        
        // Pulse effect
        if (notification.container) {
            this.scene.tweens.add({
                targets: notification.container,
                scaleX: 1.05,
                scaleY: 1.05,
                duration: 100,
                yoyo: true
            });
        }
    }
    
    /**
     * Dismiss a notification
     */
    dismiss(id) {
        const index = this.activeNotifications.findIndex(n => n.id === id);
        if (index === -1) return;
        
        const notification = this.activeNotifications[index];
        
        // Cancel timer
        if (notification.timer) {
            notification.timer.remove();
        }
        
        // Animate out
        this.animateOut(notification, () => {
            // Remove from active list
            this.activeNotifications.splice(index, 1);
            
            // Destroy container
            if (notification.container) {
                notification.container.destroy();
            }
            
            // Reposition remaining notifications
            this.repositionNotifications();
            
            // Process queue
            this.processQueue();
        });
    }
    
    /**
     * Dismiss all notifications
     */
    dismissAll() {
        const ids = this.activeNotifications.map(n => n.id);
        ids.forEach(id => this.dismiss(id));
        this.queue = [];
    }
    
    /**
     * Reposition all active notifications
     */
    repositionNotifications() {
        let y = 0;
        const pos = this.config.position;
        const isBottom = pos.includes('bottom');
        const isRight = pos.includes('right');
        const isCenter = pos.includes('center');
        
        this.activeNotifications.forEach((notification, index) => {
            let x = 0;
            if (isRight) {
                x = -notification.width;
            } else if (isCenter) {
                x = -notification.width / 2;
            }
            
            let targetY = y;
            if (isBottom) {
                targetY = -y - notification.height;
            }
            
            notification.targetX = x;
            notification.targetY = targetY;
            
            if (notification.container) {
                this.scene.tweens.add({
                    targets: notification.container,
                    x: x,
                    y: targetY,
                    duration: 200,
                    ease: 'Sine.easeOut'
                });
            }
            
            y += notification.height + this.config.spacing;
        });
    }
    
    /**
     * Generate sound effects
     */
    generateSounds() {
        // Sounds are generated on demand when played
    }
    
    /**
     * Play notification sound
     */
    playSound(type) {
        if (!this.scene || !this.scene.sound || !this.scene.sound.context) return;
        
        const ctx = this.scene.sound.context;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        
        osc.connect(gain);
        gain.connect(ctx.destination);
        
        const soundConfig = this.getSoundConfig(type);
        
        osc.type = soundConfig.type;
        osc.frequency.setValueAtTime(soundConfig.startFreq, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(soundConfig.endFreq, ctx.currentTime + soundConfig.duration);
        
        gain.gain.setValueAtTime(soundConfig.volume, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + soundConfig.duration);
        
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + soundConfig.duration);
    }
    
    /**
     * Get sound configuration for type
     */
    getSoundConfig(type) {
        const configs = {
            info: { type: 'sine', startFreq: 600, endFreq: 800, duration: 0.15, volume: 0.1 },
            success: { type: 'sine', startFreq: 500, endFreq: 1000, duration: 0.2, volume: 0.12 },
            warning: { type: 'triangle', startFreq: 400, endFreq: 600, duration: 0.2, volume: 0.1 },
            error: { type: 'square', startFreq: 200, endFreq: 150, duration: 0.3, volume: 0.08 },
            achievement: { type: 'sine', startFreq: 400, endFreq: 1200, duration: 0.4, volume: 0.15 },
            levelUp: { type: 'sine', startFreq: 300, endFreq: 1500, duration: 0.5, volume: 0.12 },
            reward: { type: 'sine', startFreq: 500, endFreq: 900, duration: 0.25, volume: 0.1 },
            challenge: { type: 'triangle', startFreq: 600, endFreq: 900, duration: 0.2, volume: 0.1 },
            social: { type: 'sine', startFreq: 800, endFreq: 1000, duration: 0.15, volume: 0.08 },
            system: { type: 'sine', startFreq: 500, endFreq: 600, duration: 0.1, volume: 0.06 }
        };
        
        return configs[type] || configs.info;
    }
    
    /**
     * Add to history
     */
    addToHistory(notification) {
        this.history.unshift({
            id: notification.id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            timestamp: notification.timestamp
        });
        
        if (this.history.length > this.maxHistory) {
            this.history.pop();
        }
    }
    
    /**
     * Get notification history
     */
    getHistory() {
        return [...this.history];
    }
    
    /**
     * Clear history
     */
    clearHistory() {
        this.history = [];
    }
    
    /**
     * Load settings from storage
     */
    loadSettings() {
        try {
            const saved = localStorage.getItem('gravshift_notification_settings');
            if (saved) {
                this.settings = { ...this.settings, ...JSON.parse(saved) };
            }
        } catch (e) {
            console.warn('Failed to load notification settings:', e);
        }
    }
    
    /**
     * Save settings to storage
     */
    saveSettings() {
        try {
            localStorage.setItem('gravshift_notification_settings', JSON.stringify(this.settings));
        } catch (e) {
            console.warn('Failed to save notification settings:', e);
        }
    }
    
    /**
     * Update settings
     */
    updateSettings(newSettings) {
        this.settings = { ...this.settings, ...newSettings };
        this.saveSettings();
    }
    
    /**
     * Set position
     */
    setPosition(position) {
        this.config.position = position;
        this.updateContainerPosition();
        this.repositionNotifications();
    }
    
    /**
     * Update loop
     */
    update(time, delta) {
        // Update progress bars
        this.activeNotifications.forEach(notification => {
            if (!notification.paused && notification.duration > 0 && notification.progressBar) {
                notification.progress -= delta / notification.duration;
                if (notification.progress < 0) notification.progress = 0;
                
                const width = notification.width - 8;
                notification.progressBar.clear();
                notification.progressBar.fillStyle(notification.color, 0.5);
                notification.progressBar.fillRect(4, notification.height - 3, width * notification.progress, 3);
            }
        });
    }
    
    /**
     * Destroy manager
     */
    destroy() {
        this.dismissAll();
        
        if (this.container) {
            this.container.destroy();
        }
        
        if (this.scene && this.scene.events) {
            this.scene.events.off('update', this.update, this);
        }
    }
    
    // Convenience methods
    
    /**
     * Show info notification
     */
    info(message, options = {}) {
        return this.show({ ...options, type: 'info', message });
    }
    
    /**
     * Show success notification
     */
    success(message, options = {}) {
        return this.show({ ...options, type: 'success', message });
    }
    
    /**
     * Show warning notification
     */
    warning(message, options = {}) {
        return this.show({ ...options, type: 'warning', message });
    }
    
    /**
     * Show error notification
     */
    error(message, options = {}) {
        return this.show({ ...options, type: 'error', message });
    }
    
    /**
     * Show achievement notification
     */
    achievement(title, message, options = {}) {
        return this.show({ ...options, type: 'achievement', title, message, priority: 'high' });
    }
    
    /**
     * Show level up notification
     */
    levelUp(level, options = {}) {
        return this.show({
            ...options,
            type: 'levelUp',
            title: 'LEVEL UP!',
            message: `You reached level ${level}!`,
            priority: 'high'
        });
    }
    
    /**
     * Show reward notification
     */
    reward(rewardType, amount, options = {}) {
        const icons = {
            coins: '🪙',
            gems: '💎',
            xp: '⭐',
            item: '🎁'
        };
        
        return this.show({
            ...options,
            type: 'reward',
            title: 'Reward Received!',
            message: `+${amount} ${rewardType}`,
            icon: icons[rewardType] || '🎁'
        });
    }
    
    /**
     * Show challenge notification
     */
    challenge(message, options = {}) {
        return this.show({ ...options, type: 'challenge', message });
    }
    
    /**
     * Show social notification
     */
    social(message, options = {}) {
        return this.show({ ...options, type: 'social', message });
    }
    
    /**
     * Show system notification
     */
    system(message, options = {}) {
        return this.show({ ...options, type: 'system', message });
    }
}

// Achievement notification helper class
class AchievementNotifier {
    constructor(notificationManager) {
        this.manager = notificationManager;
        
        // Achievement definitions
        this.achievements = new Map();
        
        // Tracked stats
        this.stats = {};
        
        // Load progress
        this.loadProgress();
    }
    
    /**
     * Register an achievement
     */
    register(id, config) {
        this.achievements.set(id, {
            id,
            name: config.name,
            description: config.description,
            icon: config.icon || '🏆',
            condition: config.condition,
            reward: config.reward || null,
            secret: config.secret || false,
            unlocked: false
        });
    }
    
    /**
     * Update stat and check achievements
     */
    updateStat(stat, value) {
        this.stats[stat] = value;
        this.checkAchievements(stat);
    }
    
    /**
     * Increment stat
     */
    incrementStat(stat, amount = 1) {
        this.stats[stat] = (this.stats[stat] || 0) + amount;
        this.checkAchievements(stat);
    }
    
    /**
     * Check achievements related to a stat
     */
    checkAchievements(stat) {
        this.achievements.forEach((achievement, id) => {
            if (!achievement.unlocked && achievement.condition(this.stats)) {
                this.unlock(id);
            }
        });
    }
    
    /**
     * Unlock an achievement
     */
    unlock(id) {
        const achievement = this.achievements.get(id);
        if (!achievement || achievement.unlocked) return;
        
        achievement.unlocked = true;
        achievement.unlockedAt = Date.now();
        
        // Show notification
        this.manager.achievement(
            achievement.name,
            achievement.description,
            {
                icon: achievement.icon,
                action: achievement.reward ? () => this.claimReward(id) : null,
                actionLabel: achievement.reward ? 'Claim' : null
            }
        );
        
        // Save progress
        this.saveProgress();
    }
    
    /**
     * Claim achievement reward
     */
    claimReward(id) {
        const achievement = this.achievements.get(id);
        if (!achievement || !achievement.reward) return;
        
        // Reward logic here
        this.manager.reward(achievement.reward.type, achievement.reward.amount);
    }
    
    /**
     * Load progress from storage
     */
    loadProgress() {
        try {
            const saved = localStorage.getItem('gravshift_achievements');
            if (saved) {
                const data = JSON.parse(saved);
                this.stats = data.stats || {};
                
                // Restore unlocked status
                if (data.unlocked) {
                    data.unlocked.forEach(id => {
                        const achievement = this.achievements.get(id);
                        if (achievement) {
                            achievement.unlocked = true;
                        }
                    });
                }
            }
        } catch (e) {
            console.warn('Failed to load achievement progress:', e);
        }
    }
    
    /**
     * Save progress to storage
     */
    saveProgress() {
        try {
            const unlocked = [];
            this.achievements.forEach((achievement, id) => {
                if (achievement.unlocked) {
                    unlocked.push(id);
                }
            });
            
            localStorage.setItem('gravshift_achievements', JSON.stringify({
                stats: this.stats,
                unlocked
            }));
        } catch (e) {
            console.warn('Failed to save achievement progress:', e);
        }
    }
    
    /**
     * Get achievement progress
     */
    getProgress() {
        let total = 0;
        let unlocked = 0;
        
        this.achievements.forEach(achievement => {
            total++;
            if (achievement.unlocked) unlocked++;
        });
        
        return { total, unlocked, percentage: total > 0 ? (unlocked / total) * 100 : 0 };
    }
}

// Toast notification helper (simpler notifications)
class ToastManager {
    constructor(scene) {
        this.scene = scene;
        this.container = null;
        this.toasts = [];
        this.maxToasts = 3;
        
        this.init();
    }
    
    init() {
        if (!this.scene) return;
        
        this.container = this.scene.add.container(
            this.scene.cameras.main.width / 2,
            this.scene.cameras.main.height - 100
        );
        this.container.setDepth(10001);
    }
    
    show(message, duration = 2000) {
        if (!this.scene || !this.container) return;
        
        // Create toast
        const toast = {
            id: 'toast_' + Date.now(),
            message,
            duration
        };
        
        // Create container
        const toastContainer = this.scene.add.container(0, 0);
        toast.container = toastContainer;
        
        // Calculate width
        const width = Math.min(400, message.length * 10 + 40);
        const height = 40;
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x000000, 0.8);
        bg.fillRoundedRect(-width / 2, -height / 2, width, height, 20);
        toastContainer.add(bg);
        
        // Text
        const text = this.scene.add.text(0, 0, message, {
            fontSize: '14px',
            fontFamily: 'Arial',
            color: '#ffffff'
        }).setOrigin(0.5, 0.5);
        toastContainer.add(text);
        
        // Position
        const y = -this.toasts.length * 50;
        toastContainer.setPosition(0, y);
        toastContainer.setAlpha(0);
        
        // Add to container
        this.container.add(toastContainer);
        this.toasts.push(toast);
        
        // Animate in
        this.scene.tweens.add({
            targets: toastContainer,
            alpha: 1,
            y: y - 20,
            duration: 200,
            ease: 'Sine.easeOut'
        });
        
        // Remove after duration
        this.scene.time.delayedCall(duration, () => {
            this.removeToast(toast.id);
        });
    }
    
    removeToast(id) {
        const index = this.toasts.findIndex(t => t.id === id);
        if (index === -1) return;
        
        const toast = this.toasts[index];
        
        // Animate out
        this.scene.tweens.add({
            targets: toast.container,
            alpha: 0,
            y: toast.container.y + 20,
            duration: 200,
            ease: 'Sine.easeIn',
            onComplete: () => {
                toast.container.destroy();
                this.toasts.splice(index, 1);
                this.repositionToasts();
            }
        });
    }
    
    repositionToasts() {
        this.toasts.forEach((toast, index) => {
            const y = -index * 50;
            this.scene.tweens.add({
                targets: toast.container,
                y: y,
                duration: 150,
                ease: 'Sine.easeOut'
            });
        });
    }
    
    destroy() {
        if (this.container) {
            this.container.destroy();
        }
    }
}

// Register classes
if (typeof window !== 'undefined') {
    window.NotificationManager = NotificationManager;
    window.AchievementNotifier = AchievementNotifier;
    window.ToastManager = ToastManager;
}
