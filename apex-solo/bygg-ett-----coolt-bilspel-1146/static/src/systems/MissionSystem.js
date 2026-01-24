/**
 * MissionSystem.js
 * Mission/Quest system with objectives, rewards, and progression
 * Includes story missions, side quests, and special events
 */

class MissionSystem {
    constructor() {
        // Mission state
        this.activeMissions = [];
        this.completedMissions = [];
        this.availableMissions = [];
        this.missionProgress = {};
        
        // Mission definitions
        this.missions = this.defineMissions();
        this.missionChains = this.defineMissionChains();
        
        // Event missions
        this.eventMissions = [];
        this.currentEvent = null;
        
        // Rewards
        this.pendingRewards = [];
        
        // Callbacks
        this.onMissionComplete = null;
        this.onMissionProgress = null;
        this.onRewardClaimed = null;
        
        // Initialize
        this.loadState();
        this.updateAvailableMissions();
    }
    
    /**
     * Define all missions
     */
    defineMissions() {
        return {
            // Tutorial/Story missions
            'story_1_begin': {
                id: 'story_1_begin',
                name: 'First Steps',
                description: 'Complete your first race in GRAVSHIFT',
                type: 'story',
                chapter: 1,
                objectives: [
                    { type: 'complete_race', count: 1, progress: 0 }
                ],
                rewards: {
                    coins: 500,
                    xp: 100,
                    unlocks: []
                },
                prerequisites: [],
                repeatable: false
            },
            
            'story_1_gravity': {
                id: 'story_1_gravity',
                name: 'Gravity\'s Pull',
                description: 'Learn to navigate gravity shifts - survive 30 seconds without hitting obstacles',
                type: 'story',
                chapter: 1,
                objectives: [
                    { type: 'survive_time_clean', seconds: 30, progress: 0 }
                ],
                rewards: {
                    coins: 750,
                    xp: 150,
                    unlocks: ['level_2']
                },
                prerequisites: ['story_1_begin'],
                repeatable: false
            },
            
            'story_1_speed': {
                id: 'story_1_speed',
                name: 'Need for Speed',
                description: 'Reach a speed of 500 km/h',
                type: 'story',
                chapter: 1,
                objectives: [
                    { type: 'reach_speed', speed: 500, progress: 0 }
                ],
                rewards: {
                    coins: 1000,
                    xp: 200,
                    unlocks: ['vehicle_speeder']
                },
                prerequisites: ['story_1_gravity'],
                repeatable: false
            },
            
            'story_2_combo': {
                id: 'story_2_combo',
                name: 'Chain Reaction',
                description: 'Build a combo of 50x',
                type: 'story',
                chapter: 2,
                objectives: [
                    { type: 'reach_combo', combo: 50, progress: 0 }
                ],
                rewards: {
                    coins: 1500,
                    xp: 300,
                    unlocks: ['level_3']
                },
                prerequisites: ['story_1_speed'],
                repeatable: false
            },
            
            'story_2_powerup': {
                id: 'story_2_powerup',
                name: 'Power Surge',
                description: 'Collect all 5 power-up types in a single run',
                type: 'story',
                chapter: 2,
                objectives: [
                    { type: 'collect_powerup_types', types: ['BOOST', 'SHIELD', 'SLOWMO', 'MAGNET', 'GHOST'], progress: [] }
                ],
                rewards: {
                    coins: 2000,
                    xp: 400,
                    unlocks: ['level_4']
                },
                prerequisites: ['story_2_combo'],
                repeatable: false
            },
            
            'story_3_master': {
                id: 'story_3_master',
                name: 'Gravity Master',
                description: 'Complete Level 5 with 3 stars',
                type: 'story',
                chapter: 3,
                objectives: [
                    { type: 'complete_level_stars', level: 5, stars: 3, progress: 0 }
                ],
                rewards: {
                    coins: 5000,
                    xp: 1000,
                    unlocks: ['vehicle_quantum', 'endless_mode']
                },
                prerequisites: ['story_2_powerup'],
                repeatable: false
            },
            
            // Side missions - Distance
            'side_distance_1': {
                id: 'side_distance_1',
                name: 'Short Run',
                description: 'Travel 5,000 meters total',
                type: 'side',
                category: 'distance',
                objectives: [
                    { type: 'total_distance', distance: 5000, progress: 0 }
                ],
                rewards: { coins: 200, xp: 50 },
                prerequisites: ['story_1_begin'],
                repeatable: false
            },
            
            'side_distance_2': {
                id: 'side_distance_2',
                name: 'Medium Run',
                description: 'Travel 25,000 meters total',
                type: 'side',
                category: 'distance',
                objectives: [
                    { type: 'total_distance', distance: 25000, progress: 0 }
                ],
                rewards: { coins: 500, xp: 100 },
                prerequisites: ['side_distance_1'],
                repeatable: false
            },
            
            'side_distance_3': {
                id: 'side_distance_3',
                name: 'Long Run',
                description: 'Travel 100,000 meters total',
                type: 'side',
                category: 'distance',
                objectives: [
                    { type: 'total_distance', distance: 100000, progress: 0 }
                ],
                rewards: { coins: 1500, xp: 300, unlocks: ['skin_marathon'] },
                prerequisites: ['side_distance_2'],
                repeatable: false
            },
            
            'side_distance_4': {
                id: 'side_distance_4',
                name: 'Ultra Marathon',
                description: 'Travel 500,000 meters total',
                type: 'side',
                category: 'distance',
                objectives: [
                    { type: 'total_distance', distance: 500000, progress: 0 }
                ],
                rewards: { coins: 5000, xp: 1000, unlocks: ['title_marathoner'] },
                prerequisites: ['side_distance_3'],
                repeatable: false
            },
            
            // Side missions - Score
            'side_score_1': {
                id: 'side_score_1',
                name: 'Point Rookie',
                description: 'Score 50,000 points in a single run',
                type: 'side',
                category: 'score',
                objectives: [
                    { type: 'single_score', score: 50000, progress: 0 }
                ],
                rewards: { coins: 300, xp: 75 },
                prerequisites: ['story_1_begin'],
                repeatable: false
            },
            
            'side_score_2': {
                id: 'side_score_2',
                name: 'Point Hunter',
                description: 'Score 200,000 points in a single run',
                type: 'side',
                category: 'score',
                objectives: [
                    { type: 'single_score', score: 200000, progress: 0 }
                ],
                rewards: { coins: 1000, xp: 200 },
                prerequisites: ['side_score_1'],
                repeatable: false
            },
            
            'side_score_3': {
                id: 'side_score_3',
                name: 'Point Master',
                description: 'Score 500,000 points in a single run',
                type: 'side',
                category: 'score',
                objectives: [
                    { type: 'single_score', score: 500000, progress: 0 }
                ],
                rewards: { coins: 3000, xp: 500, unlocks: ['skin_golden'] },
                prerequisites: ['side_score_2'],
                repeatable: false
            },
            
            // Side missions - Collection
            'side_collect_coins_1': {
                id: 'side_collect_coins_1',
                name: 'Coin Collector',
                description: 'Collect 1,000 coins total',
                type: 'side',
                category: 'collection',
                objectives: [
                    { type: 'total_coins', coins: 1000, progress: 0 }
                ],
                rewards: { coins: 100, xp: 25 },
                prerequisites: ['story_1_begin'],
                repeatable: false
            },
            
            'side_collect_coins_2': {
                id: 'side_collect_coins_2',
                name: 'Coin Hoarder',
                description: 'Collect 10,000 coins total',
                type: 'side',
                category: 'collection',
                objectives: [
                    { type: 'total_coins', coins: 10000, progress: 0 }
                ],
                rewards: { coins: 500, xp: 100 },
                prerequisites: ['side_collect_coins_1'],
                repeatable: false
            },
            
            'side_collect_powerups': {
                id: 'side_collect_powerups',
                name: 'Power Collector',
                description: 'Collect 100 power-ups total',
                type: 'side',
                category: 'collection',
                objectives: [
                    { type: 'total_powerups', count: 100, progress: 0 }
                ],
                rewards: { coins: 750, xp: 150 },
                prerequisites: ['story_1_begin'],
                repeatable: false
            },
            
            // Side missions - Skills
            'side_drift_1': {
                id: 'side_drift_1',
                name: 'Drift Beginner',
                description: 'Drift for a total of 60 seconds',
                type: 'side',
                category: 'skills',
                objectives: [
                    { type: 'total_drift_time', seconds: 60, progress: 0 }
                ],
                rewards: { coins: 400, xp: 100 },
                prerequisites: ['story_1_gravity'],
                repeatable: false
            },
            
            'side_drift_2': {
                id: 'side_drift_2',
                name: 'Drift Expert',
                description: 'Drift for a total of 5 minutes',
                type: 'side',
                category: 'skills',
                objectives: [
                    { type: 'total_drift_time', seconds: 300, progress: 0 }
                ],
                rewards: { coins: 1200, xp: 250, unlocks: ['vehicle_drifter'] },
                prerequisites: ['side_drift_1'],
                repeatable: false
            },
            
            'side_nearmiss_1': {
                id: 'side_nearmiss_1',
                name: 'Daredevil',
                description: 'Perform 50 near misses',
                type: 'side',
                category: 'skills',
                objectives: [
                    { type: 'total_near_misses', count: 50, progress: 0 }
                ],
                rewards: { coins: 600, xp: 150 },
                prerequisites: ['story_1_gravity'],
                repeatable: false
            },
            
            // Daily missions (repeatable)
            'daily_play': {
                id: 'daily_play',
                name: 'Daily Racer',
                description: 'Complete 3 races today',
                type: 'daily',
                objectives: [
                    { type: 'daily_races', count: 3, progress: 0 }
                ],
                rewards: { coins: 200, xp: 50 },
                prerequisites: [],
                repeatable: true,
                resetTime: 'daily'
            },
            
            'daily_score': {
                id: 'daily_score',
                name: 'Daily Score',
                description: 'Earn 100,000 points today',
                type: 'daily',
                objectives: [
                    { type: 'daily_score', score: 100000, progress: 0 }
                ],
                rewards: { coins: 300, xp: 75 },
                prerequisites: [],
                repeatable: true,
                resetTime: 'daily'
            },
            
            'daily_powerup': {
                id: 'daily_powerup',
                name: 'Daily Collector',
                description: 'Collect 20 power-ups today',
                type: 'daily',
                objectives: [
                    { type: 'daily_powerups', count: 20, progress: 0 }
                ],
                rewards: { coins: 250, xp: 60 },
                prerequisites: [],
                repeatable: true,
                resetTime: 'daily'
            },
            
            // Weekly missions
            'weekly_challenge': {
                id: 'weekly_challenge',
                name: 'Weekly Champion',
                description: 'Complete all daily missions this week',
                type: 'weekly',
                objectives: [
                    { type: 'complete_daily_missions', count: 7, progress: 0 }
                ],
                rewards: { coins: 2500, xp: 500, items: ['premium_crate'] },
                prerequisites: [],
                repeatable: true,
                resetTime: 'weekly'
            },
            
            'weekly_distance': {
                id: 'weekly_distance',
                name: 'Weekly Traveler',
                description: 'Travel 50,000 meters this week',
                type: 'weekly',
                objectives: [
                    { type: 'weekly_distance', distance: 50000, progress: 0 }
                ],
                rewards: { coins: 1500, xp: 300 },
                prerequisites: [],
                repeatable: true,
                resetTime: 'weekly'
            }
        };
    }
    
    /**
     * Define mission chains (story progression)
     */
    defineMissionChains() {
        return {
            'main_story': {
                id: 'main_story',
                name: 'Main Story',
                missions: [
                    'story_1_begin',
                    'story_1_gravity',
                    'story_1_speed',
                    'story_2_combo',
                    'story_2_powerup',
                    'story_3_master'
                ],
                finalReward: {
                    coins: 10000,
                    unlocks: ['true_ending', 'hardcore_mode']
                }
            },
            
            'distance_chain': {
                id: 'distance_chain',
                name: 'Distance Master',
                missions: ['side_distance_1', 'side_distance_2', 'side_distance_3', 'side_distance_4'],
                finalReward: {
                    coins: 3000,
                    unlocks: ['title_distance_master']
                }
            },
            
            'score_chain': {
                id: 'score_chain',
                name: 'Score Master',
                missions: ['side_score_1', 'side_score_2', 'side_score_3'],
                finalReward: {
                    coins: 2500,
                    unlocks: ['title_score_master']
                }
            }
        };
    }
    
    /**
     * Load mission state from storage
     */
    loadState() {
        try {
            const saved = localStorage.getItem('gravshift_missions');
            if (saved) {
                const data = JSON.parse(saved);
                this.completedMissions = data.completed || [];
                this.missionProgress = data.progress || {};
                this.activeMissions = data.active || [];
            }
        } catch (e) {
            console.error('Failed to load mission state:', e);
        }
    }
    
    /**
     * Save mission state
     */
    saveState() {
        try {
            const data = {
                completed: this.completedMissions,
                progress: this.missionProgress,
                active: this.activeMissions
            };
            localStorage.setItem('gravshift_missions', JSON.stringify(data));
        } catch (e) {
            console.error('Failed to save mission state:', e);
        }
    }
    
    /**
     * Update list of available missions
     */
    updateAvailableMissions() {
        this.availableMissions = [];
        
        Object.values(this.missions).forEach(mission => {
            // Skip completed non-repeatable missions
            if (this.completedMissions.includes(mission.id) && !mission.repeatable) {
                return;
            }
            
            // Check prerequisites
            const prereqsMet = mission.prerequisites.every(prereq => 
                this.completedMissions.includes(prereq)
            );
            
            if (prereqsMet) {
                this.availableMissions.push(mission.id);
            }
        });
    }
    
    /**
     * Activate a mission
     */
    activateMission(missionId) {
        if (!this.availableMissions.includes(missionId)) {
            console.warn(`Mission not available: ${missionId}`);
            return false;
        }
        
        if (this.activeMissions.includes(missionId)) {
            return false; // Already active
        }
        
        const mission = this.missions[missionId];
        if (!mission) return false;
        
        // Initialize progress
        this.missionProgress[missionId] = {
            startTime: Date.now(),
            objectives: mission.objectives.map(obj => ({ ...obj, progress: 0 }))
        };
        
        this.activeMissions.push(missionId);
        this.saveState();
        
        return true;
    }
    
    /**
     * Report progress on objectives
     */
    reportProgress(eventType, data = {}) {
        this.activeMissions.forEach(missionId => {
            const mission = this.missions[missionId];
            const progress = this.missionProgress[missionId];
            
            if (!mission || !progress) return;
            
            let updated = false;
            
            progress.objectives.forEach((objective, index) => {
                if (this.matchesObjective(objective, eventType, data)) {
                    const oldProgress = objective.progress;
                    this.updateObjectiveProgress(objective, eventType, data);
                    
                    if (objective.progress !== oldProgress) {
                        updated = true;
                    }
                }
            });
            
            if (updated) {
                if (this.onMissionProgress) {
                    this.onMissionProgress(missionId, progress);
                }
                
                // Check if mission is complete
                if (this.isMissionComplete(missionId)) {
                    this.completeMission(missionId);
                }
            }
        });
        
        this.saveState();
    }
    
    /**
     * Check if objective matches event type
     */
    matchesObjective(objective, eventType, data) {
        switch (objective.type) {
            case 'complete_race':
                return eventType === 'race_complete';
            case 'survive_time_clean':
                return eventType === 'survival_time' && data.clean === true;
            case 'reach_speed':
                return eventType === 'speed_reached';
            case 'reach_combo':
                return eventType === 'combo_reached';
            case 'collect_powerup_types':
                return eventType === 'powerup_collected';
            case 'complete_level_stars':
                return eventType === 'level_complete' && data.level === objective.level;
            case 'total_distance':
            case 'weekly_distance':
                return eventType === 'distance_traveled';
            case 'single_score':
                return eventType === 'score_earned';
            case 'total_coins':
            case 'daily_score':
                return eventType === 'coins_collected' || eventType === 'score_earned';
            case 'total_powerups':
            case 'daily_powerups':
                return eventType === 'powerup_collected';
            case 'total_drift_time':
                return eventType === 'drift_time';
            case 'total_near_misses':
                return eventType === 'near_miss';
            case 'daily_races':
                return eventType === 'race_complete';
            case 'complete_daily_missions':
                return eventType === 'daily_mission_complete';
            default:
                return false;
        }
    }
    
    /**
     * Update objective progress
     */
    updateObjectiveProgress(objective, eventType, data) {
        switch (objective.type) {
            case 'complete_race':
            case 'daily_races':
            case 'total_near_misses':
            case 'complete_daily_missions':
                objective.progress = Math.min(objective.progress + 1, objective.count);
                break;
                
            case 'survive_time_clean':
                objective.progress = Math.max(objective.progress, data.time || 0);
                break;
                
            case 'reach_speed':
                objective.progress = Math.max(objective.progress, data.speed || 0);
                break;
                
            case 'reach_combo':
                objective.progress = Math.max(objective.progress, data.combo || 0);
                break;
                
            case 'collect_powerup_types':
                if (data.type && !objective.progress.includes(data.type)) {
                    objective.progress.push(data.type);
                }
                break;
                
            case 'complete_level_stars':
                objective.progress = Math.max(objective.progress, data.stars || 0);
                break;
                
            case 'total_distance':
            case 'weekly_distance':
                objective.progress += data.distance || 0;
                break;
                
            case 'single_score':
                objective.progress = Math.max(objective.progress, data.score || 0);
                break;
                
            case 'total_coins':
            case 'daily_score':
                objective.progress += data.amount || data.score || 0;
                break;
                
            case 'total_powerups':
            case 'daily_powerups':
                objective.progress += 1;
                break;
                
            case 'total_drift_time':
                objective.progress += data.time || 0;
                break;
        }
    }
    
    /**
     * Check if mission is complete
     */
    isMissionComplete(missionId) {
        const mission = this.missions[missionId];
        const progress = this.missionProgress[missionId];
        
        if (!mission || !progress) return false;
        
        return progress.objectives.every((objective, index) => {
            const missionObj = mission.objectives[index];
            return this.isObjectiveComplete(objective, missionObj);
        });
    }
    
    /**
     * Check if objective is complete
     */
    isObjectiveComplete(objective, missionObj) {
        switch (objective.type) {
            case 'complete_race':
            case 'daily_races':
            case 'total_near_misses':
            case 'complete_daily_missions':
            case 'total_powerups':
            case 'daily_powerups':
                return objective.progress >= missionObj.count;
                
            case 'survive_time_clean':
            case 'total_drift_time':
                return objective.progress >= missionObj.seconds;
                
            case 'reach_speed':
                return objective.progress >= missionObj.speed;
                
            case 'reach_combo':
                return objective.progress >= missionObj.combo;
                
            case 'collect_powerup_types':
                return missionObj.types.every(t => objective.progress.includes(t));
                
            case 'complete_level_stars':
                return objective.progress >= missionObj.stars;
                
            case 'total_distance':
            case 'weekly_distance':
                return objective.progress >= missionObj.distance;
                
            case 'single_score':
            case 'total_coins':
            case 'daily_score':
                return objective.progress >= (missionObj.score || missionObj.coins);
                
            default:
                return false;
        }
    }
    
    /**
     * Complete a mission
     */
    completeMission(missionId) {
        const mission = this.missions[missionId];
        if (!mission) return;
        
        // Remove from active
        const index = this.activeMissions.indexOf(missionId);
        if (index !== -1) {
            this.activeMissions.splice(index, 1);
        }
        
        // Add to completed
        if (!this.completedMissions.includes(missionId)) {
            this.completedMissions.push(missionId);
        }
        
        // Queue rewards
        this.pendingRewards.push({
            missionId: missionId,
            rewards: mission.rewards
        });
        
        // Check for chain completion
        this.checkChainCompletion(missionId);
        
        // Update available missions
        this.updateAvailableMissions();
        
        // Trigger callback
        if (this.onMissionComplete) {
            this.onMissionComplete(missionId, mission);
        }
        
        // Report to daily challenge if applicable
        if (mission.type === 'daily') {
            this.reportProgress('daily_mission_complete', {});
        }
        
        this.saveState();
    }
    
    /**
     * Check if a mission chain is complete
     */
    checkChainCompletion(completedMissionId) {
        Object.values(this.missionChains).forEach(chain => {
            if (chain.missions.includes(completedMissionId)) {
                const allComplete = chain.missions.every(m => this.completedMissions.includes(m));
                
                if (allComplete && !this.completedMissions.includes(`chain_${chain.id}`)) {
                    this.completedMissions.push(`chain_${chain.id}`);
                    
                    // Add chain final reward
                    this.pendingRewards.push({
                        chainId: chain.id,
                        rewards: chain.finalReward
                    });
                }
            }
        });
    }
    
    /**
     * Claim pending rewards
     */
    claimRewards() {
        const rewards = [...this.pendingRewards];
        this.pendingRewards = [];
        
        let totalCoins = 0;
        let totalXP = 0;
        let unlocks = [];
        let items = [];
        
        rewards.forEach(reward => {
            if (reward.rewards.coins) totalCoins += reward.rewards.coins;
            if (reward.rewards.xp) totalXP += reward.rewards.xp;
            if (reward.rewards.unlocks) unlocks.push(...reward.rewards.unlocks);
            if (reward.rewards.items) items.push(...reward.rewards.items);
        });
        
        const claimedRewards = {
            coins: totalCoins,
            xp: totalXP,
            unlocks: unlocks,
            items: items
        };
        
        // Apply rewards
        this.applyRewards(claimedRewards);
        
        if (this.onRewardClaimed) {
            this.onRewardClaimed(claimedRewards);
        }
        
        return claimedRewards;
    }
    
    /**
     * Apply rewards to player
     */
    applyRewards(rewards) {
        // In production, this would update actual player data
        console.log('Applying rewards:', rewards);
        
        // Update coins
        if (rewards.coins && window.SaveManager) {
            const garage = SaveManager.loadData('garage');
            if (garage) {
                garage.coins = (garage.coins || 0) + rewards.coins;
                SaveManager.saveData('garage', garage);
            }
        }
        
        // Process unlocks
        if (rewards.unlocks && window.SaveManager) {
            const unlocks = SaveManager.loadData('unlocks');
            if (unlocks) {
                rewards.unlocks.forEach(unlock => {
                    if (unlock.startsWith('level_')) {
                        if (!unlocks.levels.includes(parseInt(unlock.split('_')[1]))) {
                            unlocks.levels.push(parseInt(unlock.split('_')[1]));
                        }
                    } else if (unlock.startsWith('vehicle_')) {
                        if (!unlocks.vehicles.includes(unlock.replace('vehicle_', ''))) {
                            unlocks.vehicles.push(unlock.replace('vehicle_', ''));
                        }
                    } else if (unlock.startsWith('skin_')) {
                        if (!unlocks.skins.includes(unlock.replace('skin_', ''))) {
                            unlocks.skins.push(unlock.replace('skin_', ''));
                        }
                    }
                });
                SaveManager.saveData('unlocks', unlocks);
            }
        }
    }
    
    /**
     * Get mission by ID
     */
    getMission(missionId) {
        return this.missions[missionId] || null;
    }
    
    /**
     * Get mission progress
     */
    getMissionProgress(missionId) {
        return this.missionProgress[missionId] || null;
    }
    
    /**
     * Get all active missions
     */
    getActiveMissions() {
        return this.activeMissions.map(id => ({
            ...this.missions[id],
            progress: this.missionProgress[id]
        }));
    }
    
    /**
     * Get available missions by type
     */
    getAvailableMissionsByType(type) {
        return this.availableMissions
            .map(id => this.missions[id])
            .filter(m => m && m.type === type);
    }
    
    /**
     * Get chain progress
     */
    getChainProgress(chainId) {
        const chain = this.missionChains[chainId];
        if (!chain) return null;
        
        const completed = chain.missions.filter(m => this.completedMissions.includes(m)).length;
        const total = chain.missions.length;
        
        return {
            chain: chain,
            completed: completed,
            total: total,
            percentage: Math.round((completed / total) * 100),
            isComplete: completed >= total
        };
    }
    
    /**
     * Reset daily missions
     */
    resetDailyMissions() {
        Object.values(this.missions).forEach(mission => {
            if (mission.type === 'daily' && mission.repeatable) {
                // Reset progress
                delete this.missionProgress[mission.id];
                
                // Remove from completed
                const index = this.completedMissions.indexOf(mission.id);
                if (index !== -1) {
                    this.completedMissions.splice(index, 1);
                }
                
                // Remove from active
                const activeIndex = this.activeMissions.indexOf(mission.id);
                if (activeIndex !== -1) {
                    this.activeMissions.splice(activeIndex, 1);
                }
            }
        });
        
        this.updateAvailableMissions();
        this.saveState();
    }
    
    /**
     * Reset weekly missions
     */
    resetWeeklyMissions() {
        Object.values(this.missions).forEach(mission => {
            if (mission.type === 'weekly' && mission.repeatable) {
                delete this.missionProgress[mission.id];
                
                const index = this.completedMissions.indexOf(mission.id);
                if (index !== -1) {
                    this.completedMissions.splice(index, 1);
                }
                
                const activeIndex = this.activeMissions.indexOf(mission.id);
                if (activeIndex !== -1) {
                    this.activeMissions.splice(activeIndex, 1);
                }
            }
        });
        
        this.updateAvailableMissions();
        this.saveState();
    }
}

// Create singleton
if (typeof window !== 'undefined') {
    window.MissionSystem = new MissionSystem();
}
