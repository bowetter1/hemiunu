/**
 * GRAVSHIFT - Leaderboard Manager
 * Handles local and online leaderboards
 */

class LeaderboardManager {
    constructor(scene) {
        this.scene = scene;
        
        // Local leaderboards by level
        this.localLeaderboards = {};
        this.globalLeaderboards = {};
        
        // Player data
        this.playerId = this.getOrCreatePlayerId();
        this.playerName = this.getPlayerName();
        
        // Online status
        this.isOnline = navigator.onLine;
        this.lastSync = 0;
        
        // Configuration
        this.maxEntriesPerLevel = 100;
        this.maxEntriesPerDisplay = 20;
        
        // Load local data
        this.loadLocalLeaderboards();
        
        // Listen for online status changes
        window.addEventListener('online', () => this.isOnline = true);
        window.addEventListener('offline', () => this.isOnline = false);
    }
    
    /**
     * Get or create a unique player ID
     */
    getOrCreatePlayerId() {
        let playerId = localStorage.getItem('gravshift_player_id');
        if (!playerId) {
            playerId = 'player_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 9);
            localStorage.setItem('gravshift_player_id', playerId);
        }
        return playerId;
    }
    
    /**
     * Get player name
     */
    getPlayerName() {
        return localStorage.getItem('gravshift_player_name') || 'Anonymous';
    }
    
    /**
     * Set player name
     */
    setPlayerName(name) {
        // Sanitize and limit length
        name = name.trim().substring(0, 20).replace(/[<>]/g, '');
        this.playerName = name || 'Anonymous';
        localStorage.setItem('gravshift_player_name', this.playerName);
        return this.playerName;
    }
    
    /**
     * Load local leaderboards from storage
     */
    loadLocalLeaderboards() {
        try {
            const data = localStorage.getItem('gravshift_leaderboards');
            if (data) {
                this.localLeaderboards = JSON.parse(data);
            }
        } catch (e) {
            console.warn('Could not load leaderboards');
            this.localLeaderboards = {};
        }
    }
    
    /**
     * Save local leaderboards to storage
     */
    saveLocalLeaderboards() {
        try {
            localStorage.setItem('gravshift_leaderboards', JSON.stringify(this.localLeaderboards));
        } catch (e) {
            console.warn('Could not save leaderboards');
        }
    }
    
    /**
     * Submit a score
     */
    submitScore(levelId, score, stats = {}) {
        const entry = {
            id: Date.now().toString(36) + Math.random().toString(36).substr(2, 5),
            playerId: this.playerId,
            playerName: this.playerName,
            levelId: levelId,
            score: score,
            timestamp: Date.now(),
            stats: {
                time: stats.time || 0,
                distance: stats.distance || 0,
                combo: stats.maxCombo || 0,
                hits: stats.hits || 0,
                powerups: stats.powerupsCollected || 0,
                nearMisses: stats.nearMisses || 0,
                driftTime: stats.driftTime || 0,
                perfectRun: stats.perfectRun || false,
            },
            vehicleId: stats.vehicleId || 'BALANCED',
        };
        
        // Add to local leaderboard
        const result = this.addToLocalLeaderboard(entry);
        
        // Try to submit to global leaderboard (async)
        this.submitToGlobalLeaderboard(entry);
        
        return result;
    }
    
    /**
     * Add entry to local leaderboard
     */
    addToLocalLeaderboard(entry) {
        const levelId = entry.levelId;
        
        // Initialize level leaderboard if needed
        if (!this.localLeaderboards[levelId]) {
            this.localLeaderboards[levelId] = [];
        }
        
        const leaderboard = this.localLeaderboards[levelId];
        
        // Check if this beats player's existing score
        const existingIndex = leaderboard.findIndex(e => e.playerId === entry.playerId);
        let isNewRecord = false;
        let previousRank = -1;
        
        if (existingIndex >= 0) {
            previousRank = existingIndex + 1;
            if (entry.score > leaderboard[existingIndex].score) {
                // Remove old entry
                leaderboard.splice(existingIndex, 1);
                isNewRecord = true;
            } else {
                // Not a new record, don't add
                return {
                    success: true,
                    isNewRecord: false,
                    rank: previousRank,
                    previousRank,
                };
            }
        } else {
            isNewRecord = true;
        }
        
        // Insert in sorted position
        let insertIndex = 0;
        for (let i = 0; i < leaderboard.length; i++) {
            if (entry.score > leaderboard[i].score) {
                break;
            }
            insertIndex = i + 1;
        }
        
        leaderboard.splice(insertIndex, 0, entry);
        
        // Trim to max entries
        if (leaderboard.length > this.maxEntriesPerLevel) {
            leaderboard.pop();
        }
        
        // Save
        this.saveLocalLeaderboards();
        
        return {
            success: true,
            isNewRecord,
            rank: insertIndex + 1,
            previousRank,
            totalEntries: leaderboard.length,
        };
    }
    
    /**
     * Submit to global leaderboard (stub for server integration)
     */
    async submitToGlobalLeaderboard(entry) {
        if (!this.isOnline) return { success: false, error: 'Offline' };
        
        // This would integrate with a backend server
        // For now, just simulate success
        console.log('Would submit to global leaderboard:', entry);
        
        return { success: true };
    }
    
    /**
     * Get leaderboard for a level
     */
    getLeaderboard(levelId, options = {}) {
        const {
            limit = this.maxEntriesPerDisplay,
            offset = 0,
            includePlayer = true,
            global = false,
        } = options;
        
        let leaderboard = global 
            ? this.globalLeaderboards[levelId] || []
            : this.localLeaderboards[levelId] || [];
        
        // Get total count
        const totalEntries = leaderboard.length;
        
        // Slice for pagination
        leaderboard = leaderboard.slice(offset, offset + limit);
        
        // Add rank numbers
        leaderboard = leaderboard.map((entry, index) => ({
            ...entry,
            rank: offset + index + 1,
            isCurrentPlayer: entry.playerId === this.playerId,
        }));
        
        // Find player's entry if not in range
        let playerEntry = null;
        let playerRank = -1;
        
        if (includePlayer) {
            const fullLeaderboard = global 
                ? this.globalLeaderboards[levelId] || []
                : this.localLeaderboards[levelId] || [];
            
            const playerIndex = fullLeaderboard.findIndex(e => e.playerId === this.playerId);
            if (playerIndex >= 0) {
                playerRank = playerIndex + 1;
                playerEntry = {
                    ...fullLeaderboard[playerIndex],
                    rank: playerRank,
                    isCurrentPlayer: true,
                };
            }
        }
        
        return {
            levelId,
            entries: leaderboard,
            totalEntries,
            offset,
            limit,
            playerEntry,
            playerRank,
            isGlobal: global,
        };
    }
    
    /**
     * Get player's rank on a level
     */
    getPlayerRank(levelId, global = false) {
        const leaderboard = global 
            ? this.globalLeaderboards[levelId] || []
            : this.localLeaderboards[levelId] || [];
        
        const index = leaderboard.findIndex(e => e.playerId === this.playerId);
        return index >= 0 ? index + 1 : -1;
    }
    
    /**
     * Get player's best score on a level
     */
    getPlayerBestScore(levelId, global = false) {
        const leaderboard = global 
            ? this.globalLeaderboards[levelId] || []
            : this.localLeaderboards[levelId] || [];
        
        const entry = leaderboard.find(e => e.playerId === this.playerId);
        return entry ? entry.score : 0;
    }
    
    /**
     * Get top scores across all levels
     */
    getOverallLeaderboard(limit = 20) {
        // Aggregate scores across all levels
        const playerScores = {};
        
        Object.values(this.localLeaderboards).forEach(leaderboard => {
            leaderboard.forEach(entry => {
                if (!playerScores[entry.playerId]) {
                    playerScores[entry.playerId] = {
                        playerId: entry.playerId,
                        playerName: entry.playerName,
                        totalScore: 0,
                        levelsPlayed: 0,
                        bestLevel: null,
                        bestScore: 0,
                    };
                }
                
                playerScores[entry.playerId].totalScore += entry.score;
                playerScores[entry.playerId].levelsPlayed++;
                
                if (entry.score > playerScores[entry.playerId].bestScore) {
                    playerScores[entry.playerId].bestScore = entry.score;
                    playerScores[entry.playerId].bestLevel = entry.levelId;
                }
            });
        });
        
        // Sort by total score
        const sorted = Object.values(playerScores).sort((a, b) => b.totalScore - a.totalScore);
        
        // Add ranks
        return sorted.slice(0, limit).map((entry, index) => ({
            ...entry,
            rank: index + 1,
            isCurrentPlayer: entry.playerId === this.playerId,
        }));
    }
    
    /**
     * Get player statistics summary
     */
    getPlayerStats() {
        let totalScore = 0;
        let levelsPlayed = 0;
        let bestRank = Infinity;
        let bestLevel = null;
        let totalTime = 0;
        let perfectRuns = 0;
        
        Object.entries(this.localLeaderboards).forEach(([levelId, leaderboard]) => {
            const playerEntry = leaderboard.find(e => e.playerId === this.playerId);
            if (playerEntry) {
                totalScore += playerEntry.score;
                levelsPlayed++;
                
                const rank = leaderboard.findIndex(e => e.playerId === this.playerId) + 1;
                if (rank < bestRank) {
                    bestRank = rank;
                    bestLevel = levelId;
                }
                
                totalTime += playerEntry.stats.time || 0;
                if (playerEntry.stats.perfectRun) perfectRuns++;
            }
        });
        
        return {
            playerId: this.playerId,
            playerName: this.playerName,
            totalScore,
            levelsPlayed,
            bestRank: bestRank === Infinity ? 0 : bestRank,
            bestLevel,
            totalTime,
            perfectRuns,
            averageScore: levelsPlayed > 0 ? Math.round(totalScore / levelsPlayed) : 0,
        };
    }
    
    /**
     * Get recent scores
     */
    getRecentScores(limit = 10) {
        const allEntries = [];
        
        Object.entries(this.localLeaderboards).forEach(([levelId, leaderboard]) => {
            leaderboard.forEach(entry => {
                if (entry.playerId === this.playerId) {
                    allEntries.push({ ...entry, levelId });
                }
            });
        });
        
        // Sort by timestamp descending
        allEntries.sort((a, b) => b.timestamp - a.timestamp);
        
        return allEntries.slice(0, limit);
    }
    
    /**
     * Get rivals (players with similar scores)
     */
    getRivals(levelId, range = 3) {
        const leaderboard = this.localLeaderboards[levelId] || [];
        const playerIndex = leaderboard.findIndex(e => e.playerId === this.playerId);
        
        if (playerIndex < 0) return [];
        
        const start = Math.max(0, playerIndex - range);
        const end = Math.min(leaderboard.length, playerIndex + range + 1);
        
        return leaderboard.slice(start, end).map((entry, index) => ({
            ...entry,
            rank: start + index + 1,
            isCurrentPlayer: entry.playerId === this.playerId,
            isAbove: start + index < playerIndex,
            isBelow: start + index > playerIndex,
        }));
    }
    
    /**
     * Get score required to beat next rank
     */
    getScoreToNextRank(levelId) {
        const leaderboard = this.localLeaderboards[levelId] || [];
        const playerIndex = leaderboard.findIndex(e => e.playerId === this.playerId);
        
        if (playerIndex <= 0) return null;
        
        const nextEntry = leaderboard[playerIndex - 1];
        const playerEntry = leaderboard[playerIndex];
        
        return {
            currentRank: playerIndex + 1,
            targetRank: playerIndex,
            currentScore: playerEntry.score,
            targetScore: nextEntry.score,
            scoreDiff: nextEntry.score - playerEntry.score + 1,
            targetPlayerName: nextEntry.playerName,
        };
    }
    
    /**
     * Clear all leaderboard data
     */
    clearAllData() {
        this.localLeaderboards = {};
        this.saveLocalLeaderboards();
    }
    
    /**
     * Clear leaderboard for specific level
     */
    clearLevelLeaderboard(levelId) {
        delete this.localLeaderboards[levelId];
        this.saveLocalLeaderboards();
    }
    
    /**
     * Fetch global leaderboard (stub for server integration)
     */
    async fetchGlobalLeaderboard(levelId) {
        if (!this.isOnline) return { success: false, error: 'Offline' };
        
        // This would fetch from a backend server
        console.log('Would fetch global leaderboard for level:', levelId);
        
        return { success: true, entries: [] };
    }
    
    /**
     * Sync local scores with server (stub)
     */
    async syncWithServer() {
        if (!this.isOnline) return { success: false, error: 'Offline' };
        
        // This would sync with a backend server
        this.lastSync = Date.now();
        
        return { success: true };
    }
    
    /**
     * Generate mock leaderboard for testing
     */
    generateMockLeaderboard(levelId, count = 50) {
        const names = [
            'NeonRacer', 'GravityKing', 'SpeedDemon', 'DriftMaster', 'CyberRunner',
            'VoidWalker', 'StarChaser', 'PixelPilot', 'LaserFox', 'TurboNinja',
            'NightRider', 'PhantomX', 'BlazeMaster', 'IceBreaker', 'ThunderBolt',
            'ShadowRacer', 'CosmicDust', 'NeonPulse', 'WarpDrive', 'QuantumLeap',
        ];
        
        const entries = [];
        
        for (let i = 0; i < count; i++) {
            const baseScore = 100000 - i * 1500 + Math.floor(Math.random() * 500);
            
            entries.push({
                id: `mock_${i}_${Date.now().toString(36)}`,
                playerId: `mock_player_${i}`,
                playerName: names[Math.floor(Math.random() * names.length)] + (Math.floor(Math.random() * 99) + 1),
                levelId: levelId,
                score: Math.max(1000, baseScore),
                timestamp: Date.now() - Math.floor(Math.random() * 7 * 24 * 60 * 60 * 1000),
                stats: {
                    time: 60000 + Math.floor(Math.random() * 120000),
                    distance: 3000 + Math.floor(Math.random() * 5000),
                    combo: Math.floor(Math.random() * 100),
                    hits: Math.floor(Math.random() * 5),
                    powerups: Math.floor(Math.random() * 20),
                    nearMisses: Math.floor(Math.random() * 50),
                    driftTime: Math.floor(Math.random() * 30000),
                    perfectRun: Math.random() > 0.8,
                },
                vehicleId: ['BALANCED', 'SPEEDER', 'TANK', 'DRIFTER'][Math.floor(Math.random() * 4)],
            });
        }
        
        this.localLeaderboards[levelId] = entries;
        this.saveLocalLeaderboards();
        
        return entries.length;
    }
}

// Export
if (typeof window !== 'undefined') {
    window.LeaderboardManager = LeaderboardManager;
}
