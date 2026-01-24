/**
 * AnalyticsManager.js
 * Game analytics and telemetry system
 * Tracks player behavior, performance, and engagement metrics
 * Note: Privacy-first design - all data stored locally by default
 */

class AnalyticsManager {
    constructor() {
        // Configuration
        this.enabled = true;
        this.debugMode = false;
        this.batchSize = 50;
        this.flushInterval = 60000; // 1 minute
        
        // Session info
        this.sessionId = null;
        this.sessionStartTime = null;
        this.lastEventTime = null;
        
        // Event queue
        this.eventQueue = [];
        this.flushedEvents = [];
        
        // Metrics accumulators
        this.sessionMetrics = {
            events: 0,
            errors: 0,
            duration: 0,
            screens: [],
            interactions: 0
        };
        
        // Tracking state
        this.currentScreen = null;
        this.screenStartTime = null;
        this.funnelSteps = {};
        
        // Timer
        this.flushTimer = null;
        
        // Initialize
        this.initialize();
    }
    
    /**
     * Initialize analytics manager
     */
    initialize() {
        // Generate session ID
        this.sessionId = this.generateSessionId();
        this.sessionStartTime = Date.now();
        this.lastEventTime = this.sessionStartTime;
        
        // Load settings
        this.loadSettings();
        
        // Start flush timer
        this.startFlushTimer();
        
        // Track session start
        this.trackEvent('session_start', {
            platform: this.getPlatform(),
            language: navigator.language,
            screenSize: `${window.innerWidth}x${window.innerHeight}`,
            userAgent: navigator.userAgent,
            referrer: document.referrer
        });
        
        // Setup unload handler
        window.addEventListener('beforeunload', () => {
            this.trackEvent('session_end', {
                duration: Date.now() - this.sessionStartTime,
                events: this.sessionMetrics.events
            });
            this.flush(true);
        });
        
        console.log('AnalyticsManager initialized');
    }
    
    /**
     * Load settings from storage
     */
    loadSettings() {
        try {
            const saved = localStorage.getItem('gravshift_analytics_settings');
            if (saved) {
                const settings = JSON.parse(saved);
                this.enabled = settings.enabled !== false;
                this.debugMode = settings.debugMode || false;
            }
        } catch (e) {
            console.error('Failed to load analytics settings:', e);
        }
    }
    
    /**
     * Save settings
     */
    saveSettings() {
        try {
            const settings = {
                enabled: this.enabled,
                debugMode: this.debugMode
            };
            localStorage.setItem('gravshift_analytics_settings', JSON.stringify(settings));
        } catch (e) {
            console.error('Failed to save analytics settings:', e);
        }
    }
    
    /**
     * Enable/disable analytics
     */
    setEnabled(enabled) {
        this.enabled = enabled;
        this.saveSettings();
        
        if (!enabled) {
            this.eventQueue = [];
        }
    }
    
    /**
     * Generate unique session ID
     */
    generateSessionId() {
        return 'session_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    /**
     * Get platform info
     */
    getPlatform() {
        const ua = navigator.userAgent;
        
        if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
        if (/Android/.test(ua)) return 'android';
        if (/Windows/.test(ua)) return 'windows';
        if (/Mac/.test(ua)) return 'macos';
        if (/Linux/.test(ua)) return 'linux';
        
        return 'unknown';
    }
    
    /**
     * Track an event
     */
    trackEvent(eventName, properties = {}) {
        if (!this.enabled) return;
        
        const event = {
            name: eventName,
            timestamp: Date.now(),
            sessionId: this.sessionId,
            properties: {
                ...properties,
                sessionDuration: Date.now() - this.sessionStartTime
            }
        };
        
        this.eventQueue.push(event);
        this.sessionMetrics.events++;
        this.lastEventTime = Date.now();
        
        if (this.debugMode) {
            console.log('Analytics event:', eventName, properties);
        }
        
        // Auto-flush if queue is full
        if (this.eventQueue.length >= this.batchSize) {
            this.flush();
        }
    }
    
    /**
     * Track screen view
     */
    trackScreen(screenName, properties = {}) {
        // End previous screen tracking
        if (this.currentScreen) {
            const screenDuration = Date.now() - this.screenStartTime;
            this.trackEvent('screen_exit', {
                screen: this.currentScreen,
                duration: screenDuration
            });
        }
        
        // Start new screen tracking
        this.currentScreen = screenName;
        this.screenStartTime = Date.now();
        
        this.sessionMetrics.screens.push(screenName);
        
        this.trackEvent('screen_view', {
            screen: screenName,
            ...properties
        });
    }
    
    /**
     * Track user interaction
     */
    trackInteraction(interactionType, target, properties = {}) {
        this.sessionMetrics.interactions++;
        
        this.trackEvent('interaction', {
            type: interactionType,
            target: target,
            screen: this.currentScreen,
            ...properties
        });
    }
    
    /**
     * Track error
     */
    trackError(errorType, message, stack = null, properties = {}) {
        this.sessionMetrics.errors++;
        
        this.trackEvent('error', {
            errorType: errorType,
            message: message,
            stack: stack,
            screen: this.currentScreen,
            ...properties
        });
    }
    
    /**
     * Track timing metric
     */
    trackTiming(category, name, durationMs, properties = {}) {
        this.trackEvent('timing', {
            category: category,
            name: name,
            duration: durationMs,
            ...properties
        });
    }
    
    /**
     * Start timing measurement
     */
    startTiming(name) {
        return {
            name: name,
            startTime: performance.now()
        };
    }
    
    /**
     * End timing measurement and track
     */
    endTiming(timer, category = 'performance', properties = {}) {
        if (!timer) return;
        
        const duration = performance.now() - timer.startTime;
        this.trackTiming(category, timer.name, Math.round(duration), properties);
        
        return duration;
    }
    
    /**
     * Track game event
     */
    trackGameEvent(eventType, properties = {}) {
        this.trackEvent(`game_${eventType}`, properties);
    }
    
    /**
     * Track game start
     */
    trackGameStart(levelId, vehicleId, mode) {
        this.trackGameEvent('start', {
            level: levelId,
            vehicle: vehicleId,
            mode: mode
        });
    }
    
    /**
     * Track game end
     */
    trackGameEnd(levelId, score, distance, duration, outcome) {
        this.trackGameEvent('end', {
            level: levelId,
            score: score,
            distance: distance,
            duration: duration,
            outcome: outcome // 'complete', 'death', 'quit'
        });
    }
    
    /**
     * Track level progress
     */
    trackLevelProgress(levelId, checkpoint, score, time) {
        this.trackGameEvent('checkpoint', {
            level: levelId,
            checkpoint: checkpoint,
            score: score,
            time: time
        });
    }
    
    /**
     * Track achievement unlock
     */
    trackAchievement(achievementId, properties = {}) {
        this.trackEvent('achievement_unlock', {
            achievementId: achievementId,
            ...properties
        });
    }
    
    /**
     * Track purchase
     */
    trackPurchase(itemId, itemType, price, currency) {
        this.trackEvent('purchase', {
            itemId: itemId,
            itemType: itemType,
            price: price,
            currency: currency,
            screen: this.currentScreen
        });
    }
    
    /**
     * Track funnel step
     */
    trackFunnelStep(funnelName, stepName, stepNumber, properties = {}) {
        if (!this.funnelSteps[funnelName]) {
            this.funnelSteps[funnelName] = [];
        }
        
        this.funnelSteps[funnelName].push({
            step: stepName,
            number: stepNumber,
            timestamp: Date.now()
        });
        
        this.trackEvent('funnel_step', {
            funnel: funnelName,
            step: stepName,
            stepNumber: stepNumber,
            ...properties
        });
    }
    
    /**
     * Track tutorial progress
     */
    trackTutorialProgress(tutorialId, step, completed = false) {
        this.trackEvent('tutorial', {
            tutorialId: tutorialId,
            step: step,
            completed: completed
        });
    }
    
    /**
     * Track user property
     */
    setUserProperty(name, value) {
        this.trackEvent('user_property', {
            property: name,
            value: value
        });
    }
    
    /**
     * Track A/B test exposure
     */
    trackExperiment(experimentId, variant) {
        this.trackEvent('experiment_exposure', {
            experimentId: experimentId,
            variant: variant
        });
    }
    
    /**
     * Start flush timer
     */
    startFlushTimer() {
        this.flushTimer = setInterval(() => {
            this.flush();
        }, this.flushInterval);
    }
    
    /**
     * Stop flush timer
     */
    stopFlushTimer() {
        if (this.flushTimer) {
            clearInterval(this.flushTimer);
            this.flushTimer = null;
        }
    }
    
    /**
     * Flush events to storage
     */
    flush(sync = false) {
        if (this.eventQueue.length === 0) return;
        
        const events = [...this.eventQueue];
        this.eventQueue = [];
        
        // Store locally
        this.saveEventsToStorage(events);
        
        // In production, would send to analytics server
        // For now, just log and store locally
        
        if (this.debugMode) {
            console.log(`Analytics: Flushed ${events.length} events`);
        }
    }
    
    /**
     * Save events to local storage
     */
    saveEventsToStorage(events) {
        try {
            // Load existing events
            const existing = localStorage.getItem('gravshift_analytics_events');
            let allEvents = existing ? JSON.parse(existing) : [];
            
            // Add new events
            allEvents.push(...events);
            
            // Keep only last 1000 events
            if (allEvents.length > 1000) {
                allEvents = allEvents.slice(-1000);
            }
            
            localStorage.setItem('gravshift_analytics_events', JSON.stringify(allEvents));
        } catch (e) {
            console.error('Failed to save analytics events:', e);
        }
    }
    
    /**
     * Get stored events
     */
    getStoredEvents() {
        try {
            const stored = localStorage.getItem('gravshift_analytics_events');
            return stored ? JSON.parse(stored) : [];
        } catch (e) {
            return [];
        }
    }
    
    /**
     * Clear stored events
     */
    clearStoredEvents() {
        localStorage.removeItem('gravshift_analytics_events');
    }
    
    /**
     * Get session metrics
     */
    getSessionMetrics() {
        return {
            ...this.sessionMetrics,
            duration: Date.now() - this.sessionStartTime,
            sessionId: this.sessionId
        };
    }
    
    /**
     * Get aggregated metrics
     */
    getAggregatedMetrics() {
        const events = this.getStoredEvents();
        
        const metrics = {
            totalEvents: events.length,
            uniqueSessions: new Set(events.map(e => e.sessionId)).size,
            eventTypes: {},
            screenViews: {},
            errors: 0,
            purchases: 0,
            averageSessionDuration: 0
        };
        
        // Session durations
        const sessionDurations = {};
        
        events.forEach(event => {
            // Count event types
            metrics.eventTypes[event.name] = (metrics.eventTypes[event.name] || 0) + 1;
            
            // Count screen views
            if (event.name === 'screen_view') {
                const screen = event.properties?.screen || 'unknown';
                metrics.screenViews[screen] = (metrics.screenViews[screen] || 0) + 1;
            }
            
            // Count errors
            if (event.name === 'error') {
                metrics.errors++;
            }
            
            // Count purchases
            if (event.name === 'purchase') {
                metrics.purchases++;
            }
            
            // Track session durations
            if (event.name === 'session_end') {
                sessionDurations[event.sessionId] = event.properties?.duration || 0;
            }
        });
        
        // Calculate average session duration
        const durations = Object.values(sessionDurations);
        if (durations.length > 0) {
            metrics.averageSessionDuration = durations.reduce((a, b) => a + b, 0) / durations.length;
        }
        
        return metrics;
    }
    
    /**
     * Export analytics data
     */
    exportData() {
        const data = {
            version: '1.0.0',
            exportDate: new Date().toISOString(),
            sessionMetrics: this.getSessionMetrics(),
            aggregatedMetrics: this.getAggregatedMetrics(),
            events: this.getStoredEvents()
        };
        
        return JSON.stringify(data, null, 2);
    }
    
    /**
     * Download analytics report
     */
    downloadReport() {
        const data = this.exportData();
        const blob = new Blob([data], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `gravshift_analytics_${Date.now()}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
    
    /**
     * Reset all analytics data
     */
    resetData() {
        this.eventQueue = [];
        this.sessionMetrics = {
            events: 0,
            errors: 0,
            duration: 0,
            screens: [],
            interactions: 0
        };
        this.funnelSteps = {};
        this.clearStoredEvents();
    }
    
    /**
     * Destroy analytics manager
     */
    destroy() {
        this.flush(true);
        this.stopFlushTimer();
    }
}

// Game-specific analytics helper class
class GameAnalytics {
    constructor(analyticsManager) {
        this.analytics = analyticsManager;
        
        // Game-specific trackers
        this.gameStartTime = null;
        this.checkpointTimes = [];
        this.deathCount = 0;
        this.powerupsCollected = [];
        this.nearMisses = 0;
    }
    
    /**
     * Start tracking a game session
     */
    startGame(levelId, vehicleId, mode = 'single') {
        this.gameStartTime = Date.now();
        this.checkpointTimes = [];
        this.deathCount = 0;
        this.powerupsCollected = [];
        this.nearMisses = 0;
        
        this.analytics.trackGameStart(levelId, vehicleId, mode);
    }
    
    /**
     * Track checkpoint reached
     */
    checkpoint(levelId, checkpointId, score) {
        const time = Date.now() - this.gameStartTime;
        this.checkpointTimes.push({ id: checkpointId, time: time });
        
        this.analytics.trackLevelProgress(levelId, checkpointId, score, time);
    }
    
    /**
     * Track player death
     */
    death(cause, position) {
        this.deathCount++;
        
        this.analytics.trackGameEvent('death', {
            cause: cause,
            position: position,
            deathNumber: this.deathCount,
            gameTime: Date.now() - this.gameStartTime
        });
    }
    
    /**
     * Track power-up collection
     */
    powerupCollected(powerupType, position) {
        this.powerupsCollected.push(powerupType);
        
        this.analytics.trackGameEvent('powerup_collected', {
            type: powerupType,
            position: position,
            gameTime: Date.now() - this.gameStartTime
        });
    }
    
    /**
     * Track near miss
     */
    nearMiss(obstacleType, distance) {
        this.nearMisses++;
        
        this.analytics.trackGameEvent('near_miss', {
            obstacleType: obstacleType,
            distance: distance,
            totalNearMisses: this.nearMisses
        });
    }
    
    /**
     * Track game completion
     */
    completeGame(levelId, score, distance) {
        const duration = Date.now() - this.gameStartTime;
        
        this.analytics.trackGameEnd(levelId, score, distance, duration, 'complete');
        
        // Additional completion metrics
        this.analytics.trackGameEvent('completion_stats', {
            level: levelId,
            deaths: this.deathCount,
            powerups: this.powerupsCollected.length,
            nearMisses: this.nearMisses,
            checkpoints: this.checkpointTimes.length
        });
    }
    
    /**
     * Track game over (death)
     */
    gameOver(levelId, score, distance) {
        const duration = Date.now() - this.gameStartTime;
        
        this.analytics.trackGameEnd(levelId, score, distance, duration, 'death');
    }
    
    /**
     * Track game quit
     */
    quitGame(levelId, score, distance) {
        const duration = Date.now() - this.gameStartTime;
        
        this.analytics.trackGameEnd(levelId, score, distance, duration, 'quit');
    }
}

// Create singletons
if (typeof window !== 'undefined') {
    window.AnalyticsManager = new AnalyticsManager();
    window.GameAnalytics = new GameAnalytics(window.AnalyticsManager);
}
