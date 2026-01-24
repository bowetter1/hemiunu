/**
 * SocialManager.js
 * Social features: friends, sharing, invites, and community integration
 * Part of GRAVSHIFT - A gravity-defying racing game
 */

class SocialManager {
    constructor(scene) {
        this.scene = scene;
        
        // Friends list
        this.friends = [];
        this.friendRequests = [];
        this.blockedUsers = [];
        
        // Online status
        this.onlineFriends = new Set();
        this.friendActivities = new Map();
        
        // Party system
        this.currentParty = null;
        this.partyInvites = [];
        
        // Recent players
        this.recentPlayers = [];
        this.maxRecentPlayers = 50;
        
        // Social feed
        this.feed = [];
        this.maxFeedItems = 100;
        
        // Sharing settings
        this.sharingEnabled = true;
        this.autoShareAchievements = true;
        this.autoShareHighScores = false;
        
        // Integration endpoints (mock)
        this.endpoints = {
            friends: '/api/social/friends',
            requests: '/api/social/requests',
            party: '/api/social/party',
            activity: '/api/social/activity'
        };
        
        // Event emitter
        this.events = new Phaser.Events.EventEmitter();
        
        // Configuration
        this.config = {
            maxFriends: 200,
            maxPartySize: 4,
            activityUpdateInterval: 30000,
            presenceUpdateInterval: 60000
        };
        
        // Initialize
        this.init();
    }
    
    /**
     * Initialize social manager
     */
    init() {
        // Load saved data
        this.loadData();
        
        // Generate mock data for demo
        this.generateMockData();
        
        // Start presence updates
        this.startPresenceUpdates();
        
        // Start activity polling
        this.startActivityPolling();
    }
    
    /**
     * Load saved social data
     */
    loadData() {
        try {
            const saved = localStorage.getItem('gravshift_social');
            if (saved) {
                const data = JSON.parse(saved);
                this.friends = data.friends || [];
                this.friendRequests = data.friendRequests || [];
                this.blockedUsers = data.blockedUsers || [];
                this.recentPlayers = data.recentPlayers || [];
                this.sharingEnabled = data.sharingEnabled !== false;
                this.autoShareAchievements = data.autoShareAchievements !== false;
                this.autoShareHighScores = data.autoShareHighScores === true;
            }
        } catch (e) {
            console.warn('Failed to load social data:', e);
        }
    }
    
    /**
     * Save social data
     */
    saveData() {
        try {
            localStorage.setItem('gravshift_social', JSON.stringify({
                friends: this.friends,
                friendRequests: this.friendRequests,
                blockedUsers: this.blockedUsers,
                recentPlayers: this.recentPlayers,
                sharingEnabled: this.sharingEnabled,
                autoShareAchievements: this.autoShareAchievements,
                autoShareHighScores: this.autoShareHighScores
            }));
        } catch (e) {
            console.warn('Failed to save social data:', e);
        }
    }
    
    /**
     * Generate mock data for demonstration
     */
    generateMockData() {
        // Mock friends
        if (this.friends.length === 0) {
            const mockFriends = [
                { id: 'f1', username: 'SpeedDemon', avatar: '🏎️', level: 42, status: 'online' },
                { id: 'f2', username: 'NightRider', avatar: '🌙', level: 38, status: 'in-game' },
                { id: 'f3', username: 'QuantumRacer', avatar: '⚡', level: 55, status: 'offline' },
                { id: 'f4', username: 'GravMaster', avatar: '🌀', level: 67, status: 'online' },
                { id: 'f5', username: 'NeonBlaze', avatar: '💜', level: 29, status: 'away' },
                { id: 'f6', username: 'StellarAce', avatar: '⭐', level: 51, status: 'in-game' },
                { id: 'f7', username: 'CyberPilot', avatar: '🤖', level: 34, status: 'offline' },
                { id: 'f8', username: 'VelocityX', avatar: '💨', level: 45, status: 'online' }
            ];
            
            this.friends = mockFriends.map(f => ({
                ...f,
                addedAt: Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000,
                lastSeen: f.status === 'offline' ? Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000 : Date.now()
            }));
            
            // Set online friends
            this.friends.forEach(f => {
                if (f.status === 'online' || f.status === 'in-game') {
                    this.onlineFriends.add(f.id);
                }
            });
        }
        
        // Mock friend requests
        if (this.friendRequests.length === 0) {
            this.friendRequests = [
                { id: 'r1', username: 'NewRacer99', avatar: '🆕', level: 12, sentAt: Date.now() - 3600000 },
                { id: 'r2', username: 'ProDriver', avatar: '🏆', level: 78, sentAt: Date.now() - 86400000 }
            ];
        }
        
        // Mock activity feed
        this.generateMockFeed();
        
        // Mock recent players
        if (this.recentPlayers.length === 0) {
            this.recentPlayers = [
                { id: 'rp1', username: 'RandomPlayer1', level: 23, playedAt: Date.now() - 600000, result: 'won' },
                { id: 'rp2', username: 'RandomPlayer2', level: 31, playedAt: Date.now() - 1800000, result: 'lost' },
                { id: 'rp3', username: 'RandomPlayer3', level: 19, playedAt: Date.now() - 3600000, result: 'won' }
            ];
        }
    }
    
    /**
     * Generate mock activity feed
     */
    generateMockFeed() {
        const activities = [
            { type: 'achievement', user: 'SpeedDemon', content: 'unlocked "Speed Demon" achievement', time: Date.now() - 300000 },
            { type: 'highscore', user: 'GravMaster', content: 'set a new high score: 250,000', time: Date.now() - 900000 },
            { type: 'levelup', user: 'NightRider', content: 'reached level 39', time: Date.now() - 1800000 },
            { type: 'race', user: 'StellarAce', content: 'won a race on Neon Highway', time: Date.now() - 3600000 },
            { type: 'challenge', user: 'VelocityX', content: 'completed the daily challenge', time: Date.now() - 7200000 },
            { type: 'unlock', user: 'NeonBlaze', content: 'unlocked the Quantum Racer vehicle', time: Date.now() - 14400000 }
        ];
        
        this.feed = activities.map((a, i) => ({
            id: 'feed_' + i,
            ...a,
            liked: false,
            likes: Math.floor(Math.random() * 20)
        }));
    }
    
    /**
     * Start presence update loop
     */
    startPresenceUpdates() {
        if (this.scene && this.scene.time) {
            this.scene.time.addEvent({
                delay: this.config.presenceUpdateInterval,
                callback: this.updatePresence,
                callbackScope: this,
                loop: true
            });
        }
    }
    
    /**
     * Update presence (online status)
     */
    updatePresence() {
        // In a real implementation, this would ping the server
        // For demo, randomly toggle some friend statuses
        this.friends.forEach(friend => {
            if (Math.random() > 0.9) {
                const statuses = ['online', 'offline', 'in-game', 'away'];
                const newStatus = statuses[Math.floor(Math.random() * statuses.length)];
                
                const wasOnline = this.onlineFriends.has(friend.id);
                friend.status = newStatus;
                
                if (newStatus === 'online' || newStatus === 'in-game') {
                    this.onlineFriends.add(friend.id);
                    if (!wasOnline) {
                        this.events.emit('friendOnline', friend);
                    }
                } else {
                    this.onlineFriends.delete(friend.id);
                    if (wasOnline) {
                        this.events.emit('friendOffline', friend);
                    }
                }
            }
        });
    }
    
    /**
     * Start activity polling
     */
    startActivityPolling() {
        if (this.scene && this.scene.time) {
            this.scene.time.addEvent({
                delay: this.config.activityUpdateInterval,
                callback: this.pollActivity,
                callbackScope: this,
                loop: true
            });
        }
    }
    
    /**
     * Poll for new activity
     */
    pollActivity() {
        // In a real implementation, this would fetch from server
        // For demo, occasionally add new activities
        if (Math.random() > 0.7 && this.friends.length > 0) {
            const friend = this.friends[Math.floor(Math.random() * this.friends.length)];
            const activityTypes = [
                { type: 'race', content: 'won a race' },
                { type: 'highscore', content: 'set a new personal best' },
                { type: 'challenge', content: 'completed a challenge' }
            ];
            const activity = activityTypes[Math.floor(Math.random() * activityTypes.length)];
            
            const newActivity = {
                id: 'feed_' + Date.now(),
                type: activity.type,
                user: friend.username,
                content: activity.content,
                time: Date.now(),
                liked: false,
                likes: 0
            };
            
            this.feed.unshift(newActivity);
            if (this.feed.length > this.maxFeedItems) {
                this.feed.pop();
            }
            
            this.events.emit('newActivity', newActivity);
        }
    }
    
    // === Friends Management ===
    
    /**
     * Get friends list
     */
    getFriends() {
        return [...this.friends].sort((a, b) => {
            // Sort by status (online first), then by level
            const statusOrder = { 'in-game': 0, 'online': 1, 'away': 2, 'offline': 3 };
            if (statusOrder[a.status] !== statusOrder[b.status]) {
                return statusOrder[a.status] - statusOrder[b.status];
            }
            return b.level - a.level;
        });
    }
    
    /**
     * Get online friends
     */
    getOnlineFriends() {
        return this.friends.filter(f => this.onlineFriends.has(f.id));
    }
    
    /**
     * Get friend by ID
     */
    getFriend(friendId) {
        return this.friends.find(f => f.id === friendId);
    }
    
    /**
     * Send friend request
     */
    sendFriendRequest(username) {
        // Check if already friends
        if (this.friends.some(f => f.username.toLowerCase() === username.toLowerCase())) {
            return { success: false, error: 'Already friends with this user' };
        }
        
        // Check if already sent request
        if (this.friendRequests.some(r => r.username.toLowerCase() === username.toLowerCase())) {
            return { success: false, error: 'Friend request already sent' };
        }
        
        // Check max friends
        if (this.friends.length >= this.config.maxFriends) {
            return { success: false, error: 'Friend list is full' };
        }
        
        // In a real implementation, this would send to server
        this.events.emit('friendRequestSent', { username });
        return { success: true, message: 'Friend request sent!' };
    }
    
    /**
     * Accept friend request
     */
    acceptFriendRequest(requestId) {
        const index = this.friendRequests.findIndex(r => r.id === requestId);
        if (index === -1) {
            return { success: false, error: 'Request not found' };
        }
        
        const request = this.friendRequests[index];
        
        // Add to friends
        this.friends.push({
            id: 'f_' + Date.now(),
            username: request.username,
            avatar: request.avatar,
            level: request.level,
            status: 'offline',
            addedAt: Date.now(),
            lastSeen: Date.now()
        });
        
        // Remove request
        this.friendRequests.splice(index, 1);
        
        this.saveData();
        this.events.emit('friendAdded', { username: request.username });
        
        return { success: true, message: `${request.username} added as friend!` };
    }
    
    /**
     * Decline friend request
     */
    declineFriendRequest(requestId) {
        const index = this.friendRequests.findIndex(r => r.id === requestId);
        if (index === -1) {
            return { success: false, error: 'Request not found' };
        }
        
        this.friendRequests.splice(index, 1);
        this.saveData();
        
        return { success: true };
    }
    
    /**
     * Remove friend
     */
    removeFriend(friendId) {
        const index = this.friends.findIndex(f => f.id === friendId);
        if (index === -1) {
            return { success: false, error: 'Friend not found' };
        }
        
        const friend = this.friends[index];
        this.friends.splice(index, 1);
        this.onlineFriends.delete(friendId);
        
        this.saveData();
        this.events.emit('friendRemoved', { username: friend.username });
        
        return { success: true, message: `${friend.username} removed from friends` };
    }
    
    /**
     * Block user
     */
    blockUser(userId, username) {
        if (this.blockedUsers.some(b => b.id === userId)) {
            return { success: false, error: 'User already blocked' };
        }
        
        // Remove from friends if present
        this.removeFriend(userId);
        
        this.blockedUsers.push({
            id: userId,
            username,
            blockedAt: Date.now()
        });
        
        this.saveData();
        this.events.emit('userBlocked', { userId, username });
        
        return { success: true, message: `${username} has been blocked` };
    }
    
    /**
     * Unblock user
     */
    unblockUser(userId) {
        const index = this.blockedUsers.findIndex(b => b.id === userId);
        if (index === -1) {
            return { success: false, error: 'User not blocked' };
        }
        
        this.blockedUsers.splice(index, 1);
        this.saveData();
        
        return { success: true };
    }
    
    // === Party System ===
    
    /**
     * Create a party
     */
    createParty() {
        if (this.currentParty) {
            return { success: false, error: 'Already in a party' };
        }
        
        this.currentParty = {
            id: 'party_' + Date.now(),
            leaderId: 'self',
            members: [{ id: 'self', username: 'You', isLeader: true, ready: true }],
            createdAt: Date.now(),
            settings: {
                mode: 'race',
                track: null,
                isOpen: true
            }
        };
        
        this.events.emit('partyCreated', this.currentParty);
        return { success: true, party: this.currentParty };
    }
    
    /**
     * Join a party
     */
    joinParty(partyId) {
        if (this.currentParty) {
            return { success: false, error: 'Already in a party' };
        }
        
        // Mock joining
        this.currentParty = {
            id: partyId,
            leaderId: 'other',
            members: [
                { id: 'other', username: 'PartyLeader', isLeader: true, ready: true },
                { id: 'self', username: 'You', isLeader: false, ready: false }
            ],
            createdAt: Date.now() - 60000,
            settings: {
                mode: 'race',
                track: 'Neon Highway',
                isOpen: true
            }
        };
        
        this.events.emit('partyJoined', this.currentParty);
        return { success: true, party: this.currentParty };
    }
    
    /**
     * Leave current party
     */
    leaveParty() {
        if (!this.currentParty) {
            return { success: false, error: 'Not in a party' };
        }
        
        const partyId = this.currentParty.id;
        this.currentParty = null;
        
        this.events.emit('partyLeft', { partyId });
        return { success: true };
    }
    
    /**
     * Invite friend to party
     */
    inviteToParty(friendId) {
        if (!this.currentParty) {
            return { success: false, error: 'Not in a party' };
        }
        
        if (this.currentParty.members.length >= this.config.maxPartySize) {
            return { success: false, error: 'Party is full' };
        }
        
        const friend = this.getFriend(friendId);
        if (!friend) {
            return { success: false, error: 'Friend not found' };
        }
        
        // In real implementation, send invite to server
        this.events.emit('partyInviteSent', { friendId, friendName: friend.username });
        return { success: true, message: `Invite sent to ${friend.username}` };
    }
    
    /**
     * Accept party invite
     */
    acceptPartyInvite(inviteId) {
        const index = this.partyInvites.findIndex(i => i.id === inviteId);
        if (index === -1) {
            return { success: false, error: 'Invite not found or expired' };
        }
        
        const invite = this.partyInvites[index];
        this.partyInvites.splice(index, 1);
        
        return this.joinParty(invite.partyId);
    }
    
    /**
     * Set party ready status
     */
    setReady(ready) {
        if (!this.currentParty) {
            return { success: false, error: 'Not in a party' };
        }
        
        const member = this.currentParty.members.find(m => m.id === 'self');
        if (member) {
            member.ready = ready;
        }
        
        this.events.emit('readyStateChanged', { ready });
        return { success: true };
    }
    
    // === Activity Feed ===
    
    /**
     * Get activity feed
     */
    getFeed(limit = 20) {
        return this.feed.slice(0, limit);
    }
    
    /**
     * Like an activity
     */
    likeActivity(activityId) {
        const activity = this.feed.find(a => a.id === activityId);
        if (!activity) {
            return { success: false };
        }
        
        if (activity.liked) {
            activity.liked = false;
            activity.likes--;
        } else {
            activity.liked = true;
            activity.likes++;
        }
        
        this.events.emit('activityLiked', { activityId, liked: activity.liked });
        return { success: true, liked: activity.liked };
    }
    
    /**
     * Post activity
     */
    postActivity(type, content, data = null) {
        if (!this.sharingEnabled) {
            return { success: false, error: 'Sharing is disabled' };
        }
        
        const activity = {
            id: 'feed_' + Date.now(),
            type,
            user: 'You',
            content,
            data,
            time: Date.now(),
            liked: false,
            likes: 0
        };
        
        this.feed.unshift(activity);
        if (this.feed.length > this.maxFeedItems) {
            this.feed.pop();
        }
        
        this.events.emit('activityPosted', activity);
        return { success: true, activity };
    }
    
    // === Recent Players ===
    
    /**
     * Add recent player
     */
    addRecentPlayer(player) {
        // Remove if already exists
        const existingIndex = this.recentPlayers.findIndex(p => p.id === player.id);
        if (existingIndex !== -1) {
            this.recentPlayers.splice(existingIndex, 1);
        }
        
        // Add to beginning
        this.recentPlayers.unshift({
            ...player,
            playedAt: Date.now()
        });
        
        // Trim to max
        if (this.recentPlayers.length > this.maxRecentPlayers) {
            this.recentPlayers = this.recentPlayers.slice(0, this.maxRecentPlayers);
        }
        
        this.saveData();
    }
    
    /**
     * Get recent players
     */
    getRecentPlayers(limit = 10) {
        return this.recentPlayers.slice(0, limit);
    }
    
    // === Sharing ===
    
    /**
     * Share achievement
     */
    shareAchievement(achievementName, achievementDesc) {
        if (!this.autoShareAchievements) return;
        
        this.postActivity('achievement', `unlocked "${achievementName}" - ${achievementDesc}`);
    }
    
    /**
     * Share high score
     */
    shareHighScore(score, track) {
        if (!this.autoShareHighScores) return;
        
        this.postActivity('highscore', `set a new high score of ${score.toLocaleString()} on ${track}`, { score, track });
    }
    
    /**
     * Share to clipboard
     */
    async shareToClipboard(text) {
        try {
            await navigator.clipboard.writeText(text);
            return { success: true, message: 'Copied to clipboard!' };
        } catch (e) {
            return { success: false, error: 'Failed to copy' };
        }
    }
    
    /**
     * Share via Web Share API
     */
    async shareNative(title, text, url) {
        if (!navigator.share) {
            return { success: false, error: 'Sharing not supported' };
        }
        
        try {
            await navigator.share({ title, text, url });
            return { success: true };
        } catch (e) {
            if (e.name === 'AbortError') {
                return { success: false, error: 'Share cancelled' };
            }
            return { success: false, error: 'Share failed' };
        }
    }
    
    /**
     * Generate shareable replay link
     */
    generateReplayLink(replayId) {
        // In a real implementation, this would generate a proper URL
        const baseUrl = window.location.origin;
        return `${baseUrl}/replay/${replayId}`;
    }
    
    /**
     * Generate challenge link
     */
    generateChallengeLink(score, track) {
        const baseUrl = window.location.origin;
        const params = new URLSearchParams({
            score: score.toString(),
            track: track,
            challenge: 'beat-score'
        });
        return `${baseUrl}/challenge?${params.toString()}`;
    }
    
    // === Invites ===
    
    /**
     * Send game invite
     */
    sendInvite(friendId, mode = 'race') {
        const friend = this.getFriend(friendId);
        if (!friend) {
            return { success: false, error: 'Friend not found' };
        }
        
        if (friend.status === 'offline') {
            return { success: false, error: 'Friend is offline' };
        }
        
        // In real implementation, send to server
        this.events.emit('inviteSent', { friendId, mode });
        return { success: true, message: `Invite sent to ${friend.username}` };
    }
    
    // === Settings ===
    
    /**
     * Update sharing settings
     */
    updateSharingSettings(settings) {
        if (settings.enabled !== undefined) {
            this.sharingEnabled = settings.enabled;
        }
        if (settings.achievements !== undefined) {
            this.autoShareAchievements = settings.achievements;
        }
        if (settings.highScores !== undefined) {
            this.autoShareHighScores = settings.highScores;
        }
        
        this.saveData();
    }
    
    // === Utility ===
    
    /**
     * Get friend count
     */
    getFriendCount() {
        return this.friends.length;
    }
    
    /**
     * Get online friend count
     */
    getOnlineCount() {
        return this.onlineFriends.size;
    }
    
    /**
     * Get pending request count
     */
    getPendingRequestCount() {
        return this.friendRequests.length;
    }
    
    /**
     * Check if user is blocked
     */
    isBlocked(userId) {
        return this.blockedUsers.some(b => b.id === userId);
    }
    
    /**
     * Check if user is friend
     */
    isFriend(userId) {
        return this.friends.some(f => f.id === userId);
    }
    
    /**
     * Format relative time
     */
    formatRelativeTime(timestamp) {
        const diff = Date.now() - timestamp;
        
        if (diff < 60000) {
            return 'just now';
        } else if (diff < 3600000) {
            const minutes = Math.floor(diff / 60000);
            return `${minutes}m ago`;
        } else if (diff < 86400000) {
            const hours = Math.floor(diff / 3600000);
            return `${hours}h ago`;
        } else {
            const days = Math.floor(diff / 86400000);
            return `${days}d ago`;
        }
    }
    
    /**
     * Destroy manager
     */
    destroy() {
        this.saveData();
        this.events.destroy();
    }
}

// Friend list UI component
class FriendListUI {
    constructor(scene, socialManager, x, y, width, height) {
        this.scene = scene;
        this.social = socialManager;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        
        this.container = null;
        this.listContainer = null;
        this.scrollOffset = 0;
        this.itemHeight = 60;
        
        this.selectedFriend = null;
        
        this.create();
    }
    
    create() {
        this.container = this.scene.add.container(this.x, this.y);
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x1a1a3a, 0.9);
        bg.fillRoundedRect(0, 0, this.width, this.height, 15);
        bg.lineStyle(2, 0x00ffaa, 0.5);
        bg.strokeRoundedRect(0, 0, this.width, this.height, 15);
        this.container.add(bg);
        
        // Header
        this.createHeader();
        
        // Friend list
        this.createList();
        
        // Subscribe to events
        this.social.events.on('friendOnline', this.refresh, this);
        this.social.events.on('friendOffline', this.refresh, this);
        this.social.events.on('friendAdded', this.refresh, this);
        this.social.events.on('friendRemoved', this.refresh, this);
    }
    
    createHeader() {
        const headerHeight = 50;
        
        // Header background
        const headerBg = this.scene.add.graphics();
        headerBg.fillStyle(0x2a2a4a, 1);
        headerBg.fillRoundedRect(0, 0, this.width, headerHeight, { tl: 15, tr: 15, bl: 0, br: 0 });
        this.container.add(headerBg);
        
        // Title
        const title = this.scene.add.text(15, 15, '👥 Friends', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.container.add(title);
        
        // Online count
        const onlineCount = this.social.getOnlineCount();
        const total = this.social.getFriendCount();
        const countText = this.scene.add.text(this.width - 15, 25, `${onlineCount}/${total} online`, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#00ff88'
        }).setOrigin(1, 0.5);
        this.container.add(countText);
        this.countText = countText;
    }
    
    createList() {
        const listY = 55;
        const listHeight = this.height - 60;
        
        // List container with mask
        this.listContainer = this.scene.add.container(0, listY);
        this.container.add(this.listContainer);
        
        // Create mask
        const mask = this.scene.add.graphics();
        mask.fillStyle(0xffffff);
        mask.fillRect(this.x, this.y + listY, this.width, listHeight);
        this.listContainer.setMask(new Phaser.Display.Masks.GeometryMask(this.scene, mask));
        
        // Populate list
        this.refresh();
        
        // Scroll handling
        this.container.setInteractive(new Phaser.Geom.Rectangle(0, listY, this.width, listHeight), Phaser.Geom.Rectangle.Contains);
        this.container.on('wheel', (pointer, dx, dy) => {
            this.scroll(dy > 0 ? 1 : -1);
        });
    }
    
    refresh() {
        // Clear existing
        this.listContainer.removeAll(true);
        
        const friends = this.social.getFriends();
        
        if (friends.length === 0) {
            const emptyText = this.scene.add.text(this.width / 2, 50, 'No friends yet\nAdd some friends to play together!', {
                fontSize: '14px',
                fontFamily: 'Arial',
                color: '#888899',
                align: 'center'
            }).setOrigin(0.5, 0.5);
            this.listContainer.add(emptyText);
            return;
        }
        
        friends.forEach((friend, index) => {
            this.createFriendItem(friend, index);
        });
        
        // Update count
        if (this.countText) {
            const onlineCount = this.social.getOnlineCount();
            const total = this.social.getFriendCount();
            this.countText.setText(`${onlineCount}/${total} online`);
        }
    }
    
    createFriendItem(friend, index) {
        const y = index * this.itemHeight - this.scrollOffset;
        const itemContainer = this.scene.add.container(0, y);
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x2a2a4a, 0.5);
        bg.fillRoundedRect(5, 0, this.width - 10, this.itemHeight - 5, 8);
        itemContainer.add(bg);
        
        // Status indicator
        const statusColors = {
            'online': 0x00ff00,
            'in-game': 0x00aaff,
            'away': 0xffaa00,
            'offline': 0x666666
        };
        
        const statusDot = this.scene.add.graphics();
        statusDot.fillStyle(statusColors[friend.status] || 0x666666, 1);
        statusDot.fillCircle(25, (this.itemHeight - 5) / 2, 5);
        itemContainer.add(statusDot);
        
        // Avatar
        const avatar = this.scene.add.text(45, (this.itemHeight - 5) / 2, friend.avatar, {
            fontSize: '24px'
        }).setOrigin(0, 0.5);
        itemContainer.add(avatar);
        
        // Username
        const username = this.scene.add.text(75, 15, friend.username, {
            fontSize: '14px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        itemContainer.add(username);
        
        // Status text
        const statusText = this.scene.add.text(75, 35, this.getStatusText(friend), {
            fontSize: '11px',
            fontFamily: 'Arial',
            color: '#888899'
        });
        itemContainer.add(statusText);
        
        // Level
        const level = this.scene.add.text(this.width - 20, (this.itemHeight - 5) / 2, `Lv.${friend.level}`, {
            fontSize: '12px',
            fontFamily: 'Arial',
            color: '#9966ff'
        }).setOrigin(1, 0.5);
        itemContainer.add(level);
        
        // Interactive
        const zone = this.scene.add.zone(this.width / 2, (this.itemHeight - 5) / 2, this.width - 10, this.itemHeight - 5)
            .setInteractive({ useHandCursor: true })
            .on('pointerover', () => {
                bg.clear();
                bg.fillStyle(0x3a3a5a, 0.8);
                bg.fillRoundedRect(5, 0, this.width - 10, this.itemHeight - 5, 8);
            })
            .on('pointerout', () => {
                bg.clear();
                bg.fillStyle(0x2a2a4a, 0.5);
                bg.fillRoundedRect(5, 0, this.width - 10, this.itemHeight - 5, 8);
            })
            .on('pointerdown', () => {
                this.selectFriend(friend);
            });
        itemContainer.add(zone);
        
        this.listContainer.add(itemContainer);
    }
    
    getStatusText(friend) {
        switch (friend.status) {
            case 'online':
                return 'Online';
            case 'in-game':
                return 'In Game - Racing';
            case 'away':
                return 'Away';
            case 'offline':
                return 'Last seen ' + this.social.formatRelativeTime(friend.lastSeen);
            default:
                return 'Unknown';
        }
    }
    
    scroll(direction) {
        const friends = this.social.getFriends();
        const maxScroll = Math.max(0, friends.length * this.itemHeight - (this.height - 60));
        
        this.scrollOffset += direction * 30;
        this.scrollOffset = Math.max(0, Math.min(maxScroll, this.scrollOffset));
        
        this.refresh();
    }
    
    selectFriend(friend) {
        this.selectedFriend = friend;
        // Could show a context menu or friend details
    }
    
    destroy() {
        this.social.events.off('friendOnline', this.refresh, this);
        this.social.events.off('friendOffline', this.refresh, this);
        this.social.events.off('friendAdded', this.refresh, this);
        this.social.events.off('friendRemoved', this.refresh, this);
        
        this.container.destroy();
    }
}

// Activity feed UI component
class ActivityFeedUI {
    constructor(scene, socialManager, x, y, width, height) {
        this.scene = scene;
        this.social = socialManager;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        
        this.container = null;
        this.feedContainer = null;
        this.scrollOffset = 0;
        this.itemHeight = 70;
        
        this.create();
    }
    
    create() {
        this.container = this.scene.add.container(this.x, this.y);
        
        // Background
        const bg = this.scene.add.graphics();
        bg.fillStyle(0x1a1a3a, 0.9);
        bg.fillRoundedRect(0, 0, this.width, this.height, 15);
        this.container.add(bg);
        
        // Header
        const header = this.scene.add.text(15, 15, '📰 Activity Feed', {
            fontSize: '16px',
            fontFamily: 'Arial Black',
            color: '#ffffff'
        });
        this.container.add(header);
        
        // Feed container
        this.feedContainer = this.scene.add.container(0, 50);
        this.container.add(this.feedContainer);
        
        // Populate
        this.refresh();
        
        // Subscribe to events
        this.social.events.on('newActivity', this.refresh, this);
    }
    
    refresh() {
        this.feedContainer.removeAll(true);
        
        const feed = this.social.getFeed(10);
        
        feed.forEach((activity, index) => {
            this.createActivityItem(activity, index);
        });
    }
    
    createActivityItem(activity, index) {
        const y = index * this.itemHeight;
        const itemContainer = this.scene.add.container(10, y);
        
        // Type icon
        const typeIcons = {
            achievement: '🏆',
            highscore: '⭐',
            levelup: '📈',
            race: '🏁',
            challenge: '🎯',
            unlock: '🔓'
        };
        
        const icon = this.scene.add.text(0, 20, typeIcons[activity.type] || '📝', {
            fontSize: '20px'
        });
        itemContainer.add(icon);
        
        // User and content
        const text = this.scene.add.text(35, 10, activity.user, {
            fontSize: '12px',
            fontFamily: 'Arial Black',
            color: '#00ffaa'
        });
        itemContainer.add(text);
        
        const content = this.scene.add.text(35, 28, activity.content, {
            fontSize: '11px',
            fontFamily: 'Arial',
            color: '#ffffff',
            wordWrap: { width: this.width - 80 }
        });
        itemContainer.add(content);
        
        // Time
        const time = this.scene.add.text(35, 50, this.social.formatRelativeTime(activity.time), {
            fontSize: '10px',
            fontFamily: 'Arial',
            color: '#666666'
        });
        itemContainer.add(time);
        
        // Likes
        const likes = this.scene.add.text(this.width - 50, 30, `❤️ ${activity.likes}`, {
            fontSize: '11px',
            fontFamily: 'Arial',
            color: activity.liked ? '#ff4444' : '#888888'
        }).setOrigin(0, 0.5)
            .setInteractive({ useHandCursor: true })
            .on('pointerdown', () => {
                this.social.likeActivity(activity.id);
                this.refresh();
            });
        itemContainer.add(likes);
        
        this.feedContainer.add(itemContainer);
    }
    
    destroy() {
        this.social.events.off('newActivity', this.refresh, this);
        this.container.destroy();
    }
}

// Register classes
if (typeof window !== 'undefined') {
    window.SocialManager = SocialManager;
    window.FriendListUI = FriendListUI;
    window.ActivityFeedUI = ActivityFeedUI;
}
