/**
 * LocalizationManager.js
 * Multi-language support system
 * Handles text translations, date/number formatting, and RTL support
 */

class LocalizationManager {
    constructor() {
        // Configuration
        this.defaultLanguage = 'en';
        this.currentLanguage = 'en';
        this.fallbackLanguage = 'en';
        
        // Loaded translations
        this.translations = {};
        this.loadedLanguages = new Set();
        
        // Supported languages
        this.supportedLanguages = {
            'en': { name: 'English', nativeName: 'English', rtl: false },
            'sv': { name: 'Swedish', nativeName: 'Svenska', rtl: false },
            'de': { name: 'German', nativeName: 'Deutsch', rtl: false },
            'fr': { name: 'French', nativeName: 'Français', rtl: false },
            'es': { name: 'Spanish', nativeName: 'Español', rtl: false },
            'pt': { name: 'Portuguese', nativeName: 'Português', rtl: false },
            'it': { name: 'Italian', nativeName: 'Italiano', rtl: false },
            'ja': { name: 'Japanese', nativeName: '日本語', rtl: false },
            'ko': { name: 'Korean', nativeName: '한국어', rtl: false },
            'zh': { name: 'Chinese', nativeName: '中文', rtl: false },
            'ru': { name: 'Russian', nativeName: 'Русский', rtl: false },
            'ar': { name: 'Arabic', nativeName: 'العربية', rtl: true }
        };
        
        // Callbacks
        this.onLanguageChange = null;
        
        // Initialize
        this.initialize();
    }
    
    /**
     * Initialize localization manager
     */
    initialize() {
        // Load default translations
        this.loadBuiltInTranslations();
        
        // Detect or load saved language
        this.currentLanguage = this.detectLanguage();
        
        console.log(`LocalizationManager initialized with language: ${this.currentLanguage}`);
    }
    
    /**
     * Detect user language
     */
    detectLanguage() {
        // Check saved preference
        const saved = localStorage.getItem('gravshift_language');
        if (saved && this.supportedLanguages[saved]) {
            return saved;
        }
        
        // Check browser language
        const browserLang = navigator.language.split('-')[0];
        if (this.supportedLanguages[browserLang]) {
            return browserLang;
        }
        
        return this.defaultLanguage;
    }
    
    /**
     * Load built-in translations
     */
    loadBuiltInTranslations() {
        // English (base language)
        this.translations['en'] = {
            // Menu
            'menu.title': 'GRAVSHIFT',
            'menu.tagline': 'Racing Where Gravity Is Just A Suggestion',
            'menu.play': 'PLAY',
            'menu.levels': 'LEVELS',
            'menu.garage': 'GARAGE',
            'menu.shop': 'SHOP',
            'menu.settings': 'SETTINGS',
            'menu.achievements': 'ACHIEVEMENTS',
            'menu.stats': 'STATISTICS',
            'menu.leaderboard': 'LEADERBOARD',
            'menu.multiplayer': 'MULTIPLAYER',
            'menu.credits': 'CREDITS',
            'menu.quit': 'QUIT',
            
            // Game
            'game.score': 'SCORE',
            'game.combo': 'COMBO',
            'game.distance': 'DISTANCE',
            'game.time': 'TIME',
            'game.speed': 'SPEED',
            'game.pause': 'PAUSED',
            'game.resume': 'RESUME',
            'game.restart': 'RESTART',
            'game.quit_to_menu': 'QUIT TO MENU',
            'game.game_over': 'GAME OVER',
            'game.new_highscore': 'NEW HIGH SCORE!',
            'game.final_score': 'FINAL SCORE',
            'game.best_score': 'BEST',
            'game.try_again': 'TRY AGAIN',
            'game.next_level': 'NEXT LEVEL',
            'game.level_complete': 'LEVEL COMPLETE!',
            'game.perfect': 'PERFECT!',
            'game.get_ready': 'GET READY',
            'game.go': 'GO!',
            
            // Power-ups
            'powerup.boost': 'BOOST',
            'powerup.shield': 'SHIELD',
            'powerup.slowmo': 'SLOW-MO',
            'powerup.magnet': 'MAGNET',
            'powerup.ghost': 'GHOST',
            
            // Levels
            'level.select': 'SELECT LEVEL',
            'level.locked': 'LOCKED',
            'level.unlocked': 'UNLOCKED',
            'level.stars': 'Stars',
            'level.best': 'Best',
            
            // Garage
            'garage.title': 'GARAGE',
            'garage.vehicles': 'VEHICLES',
            'garage.skins': 'SKINS',
            'garage.upgrades': 'UPGRADES',
            'garage.select': 'SELECT',
            'garage.selected': 'SELECTED',
            'garage.locked': 'LOCKED',
            'garage.unlock_at': 'Unlock at Level {0}',
            'garage.stats': 'STATS',
            'garage.speed': 'Speed',
            'garage.handling': 'Handling',
            'garage.boost': 'Boost',
            'garage.durability': 'Durability',
            
            // Shop
            'shop.title': 'SHOP',
            'shop.featured': 'FEATURED',
            'shop.vehicles': 'VEHICLES',
            'shop.skins': 'SKINS',
            'shop.upgrades': 'UPGRADES',
            'shop.consumables': 'ITEMS',
            'shop.bundles': 'BUNDLES',
            'shop.buy': 'BUY',
            'shop.purchased': 'PURCHASED',
            'shop.not_enough': 'NOT ENOUGH',
            'shop.daily_deals': 'DAILY DEALS',
            'shop.refresh_in': 'Refresh in {0}',
            
            // Settings
            'settings.title': 'SETTINGS',
            'settings.audio': 'AUDIO',
            'settings.graphics': 'GRAPHICS',
            'settings.controls': 'CONTROLS',
            'settings.gameplay': 'GAMEPLAY',
            'settings.accessibility': 'ACCESSIBILITY',
            'settings.master_volume': 'Master Volume',
            'settings.music_volume': 'Music Volume',
            'settings.sfx_volume': 'SFX Volume',
            'settings.mute': 'Mute All',
            'settings.quality': 'Quality',
            'settings.quality_low': 'Low',
            'settings.quality_medium': 'Medium',
            'settings.quality_high': 'High',
            'settings.particles': 'Particles',
            'settings.screen_shake': 'Screen Shake',
            'settings.language': 'Language',
            'settings.reset': 'Reset to Defaults',
            'settings.save': 'SAVE',
            'settings.back': 'BACK',
            
            // Achievements
            'achievements.title': 'ACHIEVEMENTS',
            'achievements.unlocked': 'UNLOCKED',
            'achievements.locked': 'LOCKED',
            'achievements.progress': 'Progress',
            'achievements.reward': 'Reward',
            
            // Leaderboard
            'leaderboard.title': 'LEADERBOARD',
            'leaderboard.global': 'GLOBAL',
            'leaderboard.friends': 'FRIENDS',
            'leaderboard.local': 'LOCAL',
            'leaderboard.weekly': 'WEEKLY',
            'leaderboard.your_rank': 'YOUR RANK',
            'leaderboard.top': 'Top {0}%',
            
            // Multiplayer
            'multiplayer.title': 'MULTIPLAYER',
            'multiplayer.browse': 'BROWSE ROOMS',
            'multiplayer.create': 'CREATE ROOM',
            'multiplayer.quick_match': 'QUICK MATCH',
            'multiplayer.searching': 'Searching for match...',
            'multiplayer.connecting': 'Connecting...',
            'multiplayer.connected': 'Connected',
            'multiplayer.disconnected': 'Disconnected',
            'multiplayer.room_name': 'Room Name',
            'multiplayer.max_players': 'Max Players',
            'multiplayer.level': 'Level',
            'multiplayer.private': 'Private',
            'multiplayer.join': 'JOIN',
            'multiplayer.leave': 'LEAVE',
            'multiplayer.ready': 'READY',
            'multiplayer.not_ready': 'NOT READY',
            'multiplayer.start': 'START GAME',
            'multiplayer.waiting': 'Waiting for players...',
            'multiplayer.host': 'HOST',
            
            // Missions
            'missions.title': 'MISSIONS',
            'missions.story': 'STORY',
            'missions.side': 'SIDE',
            'missions.daily': 'DAILY',
            'missions.weekly': 'WEEKLY',
            'missions.active': 'ACTIVE',
            'missions.completed': 'COMPLETED',
            'missions.start': 'START MISSION',
            'missions.in_progress': 'IN PROGRESS',
            'missions.claim': 'CLAIM REWARD',
            
            // Daily Challenge
            'daily.title': 'DAILY CHALLENGE',
            'daily.complete': 'COMPLETE',
            'daily.time_remaining': 'Time Remaining',
            'daily.streak': 'Streak',
            'daily.reward': 'Reward',
            
            // Common
            'common.ok': 'OK',
            'common.cancel': 'CANCEL',
            'common.confirm': 'CONFIRM',
            'common.back': 'BACK',
            'common.close': 'CLOSE',
            'common.continue': 'CONTINUE',
            'common.loading': 'Loading...',
            'common.error': 'Error',
            'common.success': 'Success',
            'common.coins': 'Coins',
            'common.gems': 'Gems',
            'common.level': 'Level',
            'common.score': 'Score',
            'common.time': 'Time',
            'common.yes': 'YES',
            'common.no': 'NO',
            
            // Tutorial
            'tutorial.welcome': 'Welcome to GRAVSHIFT!',
            'tutorial.controls': 'Controls',
            'tutorial.move_left': 'Press LEFT or A to move left',
            'tutorial.move_right': 'Press RIGHT or D to move right',
            'tutorial.boost': 'Press SPACE to boost',
            'tutorial.gravity': 'Gravity shifts with the track!',
            'tutorial.skip': 'SKIP',
            'tutorial.next': 'NEXT',
            'tutorial.got_it': 'GOT IT'
        };
        
        // Swedish
        this.translations['sv'] = {
            'menu.title': 'GRAVSHIFT',
            'menu.tagline': 'Racing Där Gravitation Bara Är Ett Förslag',
            'menu.play': 'SPELA',
            'menu.levels': 'NIVÅER',
            'menu.garage': 'GARAGE',
            'menu.shop': 'BUTIK',
            'menu.settings': 'INSTÄLLNINGAR',
            'menu.achievements': 'PRESTATIONER',
            'menu.stats': 'STATISTIK',
            'menu.leaderboard': 'TOPPLISTA',
            'menu.multiplayer': 'MULTIPLAYER',
            'menu.credits': 'MEDVERKANDE',
            'menu.quit': 'AVSLUTA',
            
            'game.score': 'POÄNG',
            'game.combo': 'KOMBO',
            'game.distance': 'DISTANS',
            'game.time': 'TID',
            'game.speed': 'HASTIGHET',
            'game.pause': 'PAUSAD',
            'game.resume': 'FORTSÄTT',
            'game.restart': 'STARTA OM',
            'game.quit_to_menu': 'AVSLUTA TILL MENY',
            'game.game_over': 'SPELET SLUT',
            'game.new_highscore': 'NYTT REKORD!',
            'game.final_score': 'SLUTPOÄNG',
            'game.best_score': 'BÄST',
            'game.try_again': 'FÖRSÖK IGEN',
            'game.next_level': 'NÄSTA NIVÅ',
            'game.level_complete': 'NIVÅ KLAR!',
            
            'settings.title': 'INSTÄLLNINGAR',
            'settings.audio': 'LJUD',
            'settings.graphics': 'GRAFIK',
            'settings.controls': 'KONTROLLER',
            'settings.language': 'Språk',
            'settings.save': 'SPARA',
            'settings.back': 'TILLBAKA',
            
            'common.ok': 'OK',
            'common.cancel': 'AVBRYT',
            'common.back': 'TILLBAKA',
            'common.loading': 'Laddar...'
        };
        
        // German
        this.translations['de'] = {
            'menu.title': 'GRAVSHIFT',
            'menu.tagline': 'Rennen Wo Schwerkraft Nur Ein Vorschlag Ist',
            'menu.play': 'SPIELEN',
            'menu.levels': 'LEVEL',
            'menu.garage': 'GARAGE',
            'menu.shop': 'SHOP',
            'menu.settings': 'EINSTELLUNGEN',
            'menu.achievements': 'ERFOLGE',
            'menu.stats': 'STATISTIKEN',
            'menu.leaderboard': 'BESTENLISTE',
            'menu.multiplayer': 'MEHRSPIELER',
            'menu.credits': 'CREDITS',
            'menu.quit': 'BEENDEN',
            
            'game.score': 'PUNKTE',
            'game.combo': 'KOMBO',
            'game.distance': 'DISTANZ',
            'game.time': 'ZEIT',
            'game.speed': 'TEMPO',
            'game.pause': 'PAUSIERT',
            'game.resume': 'FORTSETZEN',
            'game.restart': 'NEUSTART',
            'game.game_over': 'SPIEL VORBEI',
            'game.new_highscore': 'NEUER HIGHSCORE!',
            
            'settings.title': 'EINSTELLUNGEN',
            'settings.audio': 'AUDIO',
            'settings.graphics': 'GRAFIK',
            'settings.language': 'Sprache',
            'settings.save': 'SPEICHERN',
            'settings.back': 'ZURÜCK',
            
            'common.ok': 'OK',
            'common.cancel': 'ABBRECHEN',
            'common.back': 'ZURÜCK',
            'common.loading': 'Laden...'
        };
        
        // Japanese
        this.translations['ja'] = {
            'menu.title': 'GRAVSHIFT',
            'menu.tagline': '重力が提案に過ぎないレース',
            'menu.play': 'プレイ',
            'menu.levels': 'レベル',
            'menu.garage': 'ガレージ',
            'menu.shop': 'ショップ',
            'menu.settings': '設定',
            'menu.achievements': '実績',
            'menu.stats': '統計',
            'menu.leaderboard': 'ランキング',
            'menu.multiplayer': 'マルチプレイ',
            'menu.credits': 'クレジット',
            'menu.quit': '終了',
            
            'game.score': 'スコア',
            'game.combo': 'コンボ',
            'game.distance': '距離',
            'game.time': '時間',
            'game.speed': '速度',
            'game.pause': '一時停止',
            'game.resume': '再開',
            'game.restart': 'やり直す',
            'game.game_over': 'ゲームオーバー',
            'game.new_highscore': '新記録！',
            
            'settings.title': '設定',
            'settings.audio': 'オーディオ',
            'settings.graphics': 'グラフィック',
            'settings.language': '言語',
            'settings.save': '保存',
            'settings.back': '戻る',
            
            'common.ok': 'OK',
            'common.cancel': 'キャンセル',
            'common.back': '戻る',
            'common.loading': '読み込み中...'
        };
        
        // Mark languages as loaded
        this.loadedLanguages.add('en');
        this.loadedLanguages.add('sv');
        this.loadedLanguages.add('de');
        this.loadedLanguages.add('ja');
    }
    
    /**
     * Get translation for a key
     */
    t(key, ...args) {
        // Try current language
        let translation = this.translations[this.currentLanguage]?.[key];
        
        // Fallback to default language
        if (!translation) {
            translation = this.translations[this.fallbackLanguage]?.[key];
        }
        
        // Return key if no translation found
        if (!translation) {
            if (this.currentLanguage !== 'en') {
                console.warn(`Missing translation: ${key} [${this.currentLanguage}]`);
            }
            return key;
        }
        
        // Replace placeholders {0}, {1}, etc.
        if (args.length > 0) {
            args.forEach((arg, index) => {
                translation = translation.replace(`{${index}}`, arg);
            });
        }
        
        return translation;
    }
    
    /**
     * Get current language
     */
    getLanguage() {
        return this.currentLanguage;
    }
    
    /**
     * Set language
     */
    setLanguage(langCode) {
        if (!this.supportedLanguages[langCode]) {
            console.warn(`Unsupported language: ${langCode}`);
            return false;
        }
        
        this.currentLanguage = langCode;
        
        // Save preference
        localStorage.setItem('gravshift_language', langCode);
        
        // Update document direction for RTL languages
        document.documentElement.dir = this.isRTL() ? 'rtl' : 'ltr';
        
        // Trigger callback
        if (this.onLanguageChange) {
            this.onLanguageChange(langCode);
        }
        
        return true;
    }
    
    /**
     * Check if current language is RTL
     */
    isRTL() {
        return this.supportedLanguages[this.currentLanguage]?.rtl || false;
    }
    
    /**
     * Get list of supported languages
     */
    getSupportedLanguages() {
        return Object.entries(this.supportedLanguages).map(([code, info]) => ({
            code: code,
            ...info
        }));
    }
    
    /**
     * Format number according to locale
     */
    formatNumber(number, options = {}) {
        try {
            return new Intl.NumberFormat(this.currentLanguage, options).format(number);
        } catch (e) {
            return number.toLocaleString();
        }
    }
    
    /**
     * Format currency
     */
    formatCurrency(amount, currency = 'USD') {
        try {
            return new Intl.NumberFormat(this.currentLanguage, {
                style: 'currency',
                currency: currency
            }).format(amount);
        } catch (e) {
            return `${currency} ${amount}`;
        }
    }
    
    /**
     * Format date
     */
    formatDate(date, options = {}) {
        const defaultOptions = {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        };
        
        try {
            return new Intl.DateTimeFormat(this.currentLanguage, { ...defaultOptions, ...options })
                .format(date instanceof Date ? date : new Date(date));
        } catch (e) {
            return date.toString();
        }
    }
    
    /**
     * Format time
     */
    formatTime(date, options = {}) {
        const defaultOptions = {
            hour: '2-digit',
            minute: '2-digit'
        };
        
        try {
            return new Intl.DateTimeFormat(this.currentLanguage, { ...defaultOptions, ...options })
                .format(date instanceof Date ? date : new Date(date));
        } catch (e) {
            return date.toString();
        }
    }
    
    /**
     * Format relative time (e.g., "2 hours ago")
     */
    formatRelativeTime(date) {
        const now = new Date();
        const then = date instanceof Date ? date : new Date(date);
        const diffMs = now - then;
        const diffSecs = Math.floor(diffMs / 1000);
        const diffMins = Math.floor(diffSecs / 60);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);
        
        try {
            const rtf = new Intl.RelativeTimeFormat(this.currentLanguage, { numeric: 'auto' });
            
            if (diffDays > 0) {
                return rtf.format(-diffDays, 'day');
            } else if (diffHours > 0) {
                return rtf.format(-diffHours, 'hour');
            } else if (diffMins > 0) {
                return rtf.format(-diffMins, 'minute');
            } else {
                return rtf.format(-diffSecs, 'second');
            }
        } catch (e) {
            return `${diffDays}d ago`;
        }
    }
    
    /**
     * Format duration (e.g., "1:30:45")
     */
    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        } else {
            return `${minutes}:${secs.toString().padStart(2, '0')}`;
        }
    }
    
    /**
     * Add custom translations
     */
    addTranslations(langCode, translations) {
        if (!this.translations[langCode]) {
            this.translations[langCode] = {};
        }
        
        Object.assign(this.translations[langCode], translations);
        this.loadedLanguages.add(langCode);
    }
    
    /**
     * Check if a translation exists
     */
    hasTranslation(key, langCode = null) {
        const lang = langCode || this.currentLanguage;
        return !!this.translations[lang]?.[key];
    }
    
    /**
     * Get all translations for current language
     */
    getAllTranslations() {
        return { ...this.translations[this.currentLanguage] };
    }
}

// Create singleton
if (typeof window !== 'undefined') {
    window.LocalizationManager = new LocalizationManager();
    
    // Shorthand function
    window.t = (key, ...args) => LocalizationManager.t(key, ...args);
}
