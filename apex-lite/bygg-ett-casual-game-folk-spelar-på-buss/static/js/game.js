/**
 * ORBIT - A hypnotic casual game for commuters
 * Core game engine with orbital mechanics
 */

class OrbitGame {
    constructor() {
        this.canvas = document.getElementById('game-canvas');
        this.ctx = this.canvas.getContext('2d');

        // Screens
        this.startScreen = document.getElementById('start-screen');
        this.gameUI = document.getElementById('game-ui');
        this.gameoverScreen = document.getElementById('gameover-screen');

        // UI Elements
        this.scoreEl = document.getElementById('score');
        this.bestScoreEl = document.getElementById('best-score');
        this.finalScoreEl = document.getElementById('final-score');
        this.gameoverBestEl = document.getElementById('gameover-best');
        this.newBestEl = document.getElementById('new-best');
        this.comboDisplay = document.getElementById('combo-display');
        this.comboCount = document.getElementById('combo-count');

        // Game state
        this.state = 'start'; // start, playing, gameover
        this.score = 0;
        this.bestScore = this.loadBestScore();
        this.combo = 0;

        // Game objects
        this.player = null;
        this.stars = [];
        this.obstacles = [];
        this.particles = [];
        this.bgStars = [];

        // Orbital system
        this.centerX = 0;
        this.centerY = 0;
        this.orbits = [];
        this.currentOrbitIndex = 1;
        this.targetOrbitIndex = 1;

        // Timing
        this.lastTime = 0;
        this.gameTime = 0;
        this.starSpawnTimer = 0;
        this.obstacleSpawnTimer = 0;

        // Colors
        this.colors = {
            background: '#0a0a1a',
            orbitDim: 'rgba(255, 255, 255, 0.05)',
            orbitBright: 'rgba(0, 212, 255, 0.2)',
            player: '#00d4ff',
            playerGlow: 'rgba(0, 212, 255, 0.5)',
            star: '#ffd700',
            starGlow: 'rgba(255, 215, 0, 0.5)',
            obstacle: '#ff4757',
            obstacleGlow: 'rgba(255, 71, 87, 0.5)',
            trail: 'rgba(0, 212, 255, 0.3)'
        };

        // Settings
        this.baseSpeed = 0.02; // radians per frame
        this.speed = this.baseSpeed;
        this.starSpawnInterval = 1500; // ms
        this.obstacleSpawnInterval = 4000; // ms

        // Screen shake
        this.shakeIntensity = 0;
        this.shakeDecay = 0.9;

        // Floating score indicators
        this.floatingScores = [];

        this.init();
    }

    init() {
        this.resize();
        this.setupEventListeners();
        this.createBackgroundStars();
        this.updateBestScoreDisplay();
        this.animate(0);
    }

    resize() {
        const dpr = window.devicePixelRatio || 1;
        this.canvas.width = window.innerWidth * dpr;
        this.canvas.height = window.innerHeight * dpr;
        this.canvas.style.width = window.innerWidth + 'px';
        this.canvas.style.height = window.innerHeight + 'px';
        this.ctx.scale(dpr, dpr);

        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.centerX = this.width / 2;
        this.centerY = this.height / 2;

        // Setup orbits based on screen size
        const maxRadius = Math.min(this.width, this.height) * 0.4;
        this.orbits = [
            maxRadius * 0.4,
            maxRadius * 0.6,
            maxRadius * 0.8,
            maxRadius * 1.0
        ];

        this.playerRadius = Math.max(8, maxRadius * 0.04);
        this.starRadius = Math.max(6, maxRadius * 0.03);
        this.obstacleRadius = Math.max(10, maxRadius * 0.05);
    }

    setupEventListeners() {
        window.addEventListener('resize', () => this.resize());

        // Touch/click to switch orbits
        const handleTap = (e) => {
            e.preventDefault();
            if (this.state === 'playing') {
                this.switchOrbit();
            }
        };

        this.canvas.addEventListener('touchstart', handleTap, { passive: false });
        this.canvas.addEventListener('mousedown', handleTap);

        // Start button
        document.getElementById('start-btn').addEventListener('click', () => this.startGame());
        document.getElementById('start-btn').addEventListener('touchend', (e) => {
            e.preventDefault();
            this.startGame();
        });

        // Retry button
        document.getElementById('retry-btn').addEventListener('click', () => this.startGame());
        document.getElementById('retry-btn').addEventListener('touchend', (e) => {
            e.preventDefault();
            this.startGame();
        });

        // Share button
        const shareBtn = document.getElementById('share-btn');
        if (shareBtn) {
            shareBtn.addEventListener('click', () => this.shareScore());
            shareBtn.addEventListener('touchend', (e) => {
                e.preventDefault();
                this.shareScore();
            });
        }
    }

    async shareScore() {
        const shareData = {
            title: 'ORBIT',
            text: `I scored ${this.score} points in ORBIT! Can you beat my score?`,
            url: window.location.href
        };

        try {
            if (navigator.share) {
                await navigator.share(shareData);
            } else {
                // Fallback: copy to clipboard
                const text = `${shareData.text} ${shareData.url}`;
                await navigator.clipboard.writeText(text);
                this.showToast('Score copied to clipboard!');
            }
        } catch (err) {
            // User cancelled or error
            if (err.name !== 'AbortError') {
                console.log('Share failed:', err);
            }
        }
    }

    showToast(message) {
        const toast = document.createElement('div');
        toast.className = 'install-prompt';
        toast.textContent = message;
        document.body.appendChild(toast);
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(-50%) translateY(20px)';
            toast.style.transition = 'all 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 2000);
    }

    createBackgroundStars() {
        this.bgStars = [];
        for (let i = 0; i < 100; i++) {
            this.bgStars.push({
                x: Math.random() * this.width,
                y: Math.random() * this.height,
                radius: Math.random() * 1.5 + 0.5,
                alpha: Math.random() * 0.5 + 0.2,
                twinkleSpeed: Math.random() * 0.02 + 0.01
            });
        }
    }

    startGame() {
        this.state = 'playing';
        this.score = 0;
        this.combo = 0;
        this.gameTime = 0;
        this.speed = this.baseSpeed;
        this.starSpawnTimer = 0;
        this.obstacleSpawnTimer = 0;

        this.currentOrbitIndex = 1;
        this.targetOrbitIndex = 1;

        this.player = {
            angle: 0,
            orbitRadius: this.orbits[this.currentOrbitIndex],
            targetRadius: this.orbits[this.currentOrbitIndex],
            trail: []
        };

        this.stars = [];
        this.obstacles = [];
        this.particles = [];

        // Spawn initial star
        setTimeout(() => this.spawnStar(), 500);

        this.startScreen.classList.add('hidden');
        this.gameoverScreen.classList.add('hidden');
        this.gameUI.classList.remove('hidden');
        this.comboDisplay.classList.add('hidden');

        this.updateScoreDisplay();
    }

    switchOrbit() {
        // Cycle through orbits
        this.targetOrbitIndex = (this.currentOrbitIndex + 1) % this.orbits.length;
        this.currentOrbitIndex = this.targetOrbitIndex;
        this.player.targetRadius = this.orbits[this.targetOrbitIndex];

        // Create pulse effect
        this.createPulseParticles(this.getPlayerX(), this.getPlayerY());
    }

    getPlayerX() {
        return this.centerX + Math.cos(this.player.angle) * this.player.orbitRadius;
    }

    getPlayerY() {
        return this.centerY + Math.sin(this.player.angle) * this.player.orbitRadius;
    }

    spawnStar() {
        if (this.state !== 'playing') return;

        const orbitIndex = Math.floor(Math.random() * this.orbits.length);
        const angle = this.player.angle + Math.PI + (Math.random() - 0.5) * Math.PI;

        this.stars.push({
            orbitIndex: orbitIndex,
            orbitRadius: this.orbits[orbitIndex],
            angle: angle,
            rotation: 0,
            scale: 0,
            collected: false
        });
    }

    spawnObstacle() {
        if (this.state !== 'playing') return;
        if (this.gameTime < 5000) return; // No obstacles in first 5 seconds

        const orbitIndex = Math.floor(Math.random() * this.orbits.length);
        const angle = this.player.angle + Math.PI + (Math.random() - 0.5) * 0.5;

        this.obstacles.push({
            orbitIndex: orbitIndex,
            orbitRadius: this.orbits[orbitIndex],
            angle: angle,
            rotation: 0,
            scale: 0
        });
    }

    createPulseParticles(x, y) {
        for (let i = 0; i < 8; i++) {
            const angle = (i / 8) * Math.PI * 2;
            this.particles.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * 3,
                vy: Math.sin(angle) * 3,
                radius: 3,
                alpha: 1,
                color: this.colors.player,
                type: 'pulse'
            });
        }
    }

    createStarParticles(x, y) {
        for (let i = 0; i < 12; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 4 + 2;
            this.particles.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                radius: Math.random() * 3 + 1,
                alpha: 1,
                color: this.colors.star,
                type: 'star'
            });
        }
    }

    createExplosionParticles(x, y) {
        for (let i = 0; i < 30; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 8 + 3;
            this.particles.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                radius: Math.random() * 5 + 2,
                alpha: 1,
                color: i % 3 === 0 ? this.colors.obstacle : (i % 3 === 1 ? this.colors.player : '#ffffff'),
                type: 'explosion'
            });
        }
        // Trigger screen shake
        this.shakeIntensity = 15;
    }

    createFloatingScore(x, y, points, isCombo) {
        this.floatingScores.push({
            x: x,
            y: y,
            points: points,
            alpha: 1,
            scale: 0,
            vy: -2,
            isCombo: isCombo
        });
    }

    update(deltaTime) {
        if (this.state !== 'playing') return;

        this.gameTime += deltaTime;

        // Increase speed over time
        this.speed = this.baseSpeed + (this.gameTime / 100000) * 0.01;

        // Update player
        this.player.angle += this.speed;

        // Smooth orbit transition
        const radiusDiff = this.player.targetRadius - this.player.orbitRadius;
        this.player.orbitRadius += radiusDiff * 0.15;

        // Update trail
        const playerX = this.getPlayerX();
        const playerY = this.getPlayerY();
        this.player.trail.unshift({ x: playerX, y: playerY, alpha: 1 });
        if (this.player.trail.length > 20) {
            this.player.trail.pop();
        }
        this.player.trail.forEach((point, i) => {
            point.alpha = 1 - (i / this.player.trail.length);
        });

        // Spawn stars
        this.starSpawnTimer += deltaTime;
        const currentStarInterval = Math.max(800, this.starSpawnInterval - this.gameTime / 50);
        if (this.starSpawnTimer >= currentStarInterval) {
            this.spawnStar();
            this.starSpawnTimer = 0;
        }

        // Spawn obstacles
        this.obstacleSpawnTimer += deltaTime;
        const currentObstacleInterval = Math.max(2000, this.obstacleSpawnInterval - this.gameTime / 30);
        if (this.obstacleSpawnTimer >= currentObstacleInterval) {
            this.spawnObstacle();
            this.obstacleSpawnTimer = 0;
        }

        // Update stars
        this.stars.forEach(star => {
            star.rotation += 0.02;
            star.scale = Math.min(1, star.scale + 0.05);
        });

        // Update obstacles
        this.obstacles.forEach(obstacle => {
            obstacle.rotation += 0.03;
            obstacle.scale = Math.min(1, obstacle.scale + 0.03);
        });

        // Check star collection
        this.stars = this.stars.filter(star => {
            if (star.collected) return false;

            const starX = this.centerX + Math.cos(star.angle) * star.orbitRadius;
            const starY = this.centerY + Math.sin(star.angle) * star.orbitRadius;
            const dist = Math.hypot(playerX - starX, playerY - starY);

            if (dist < this.playerRadius + this.starRadius * star.scale) {
                this.collectStar(starX, starY);
                return false;
            }

            // Remove stars that player has passed
            const angleDiff = this.normalizeAngle(this.player.angle - star.angle);
            if (angleDiff > 0.5 && angleDiff < Math.PI) {
                // Missed the star
                this.combo = 0;
                this.updateComboDisplay();
                return false;
            }

            return true;
        });

        // Check obstacle collision
        for (const obstacle of this.obstacles) {
            const obsX = this.centerX + Math.cos(obstacle.angle) * obstacle.orbitRadius;
            const obsY = this.centerY + Math.sin(obstacle.angle) * obstacle.orbitRadius;
            const dist = Math.hypot(playerX - obsX, playerY - obsY);

            if (dist < this.playerRadius + this.obstacleRadius * obstacle.scale * 0.8) {
                this.createExplosionParticles(playerX, playerY);
                this.gameOver();
                return;
            }
        }

        // Remove passed obstacles
        this.obstacles = this.obstacles.filter(obstacle => {
            const angleDiff = this.normalizeAngle(this.player.angle - obstacle.angle);
            return !(angleDiff > 0.5 && angleDiff < Math.PI);
        });

        // Update particles
        this.particles = this.particles.filter(particle => {
            particle.x += particle.vx;
            particle.y += particle.vy;
            particle.vx *= 0.95;
            particle.vy *= 0.95;
            particle.alpha -= 0.03;
            particle.radius *= 0.98;
            return particle.alpha > 0;
        });

        // Update floating scores
        this.floatingScores = this.floatingScores.filter(fs => {
            fs.y += fs.vy;
            fs.alpha -= 0.02;
            fs.scale = Math.min(1, fs.scale + 0.1);
            return fs.alpha > 0;
        });

        // Update screen shake
        if (this.shakeIntensity > 0.1) {
            this.shakeIntensity *= this.shakeDecay;
        } else {
            this.shakeIntensity = 0;
        }
    }

    normalizeAngle(angle) {
        while (angle < 0) angle += Math.PI * 2;
        while (angle >= Math.PI * 2) angle -= Math.PI * 2;
        return angle;
    }

    collectStar(x, y) {
        this.combo++;
        const comboMultiplier = Math.min(this.combo, 5);
        const points = 10 * comboMultiplier;
        this.score += points;

        this.createStarParticles(x, y);
        this.createFloatingScore(x, y - 20, points, this.combo >= 2);
        this.updateScoreDisplay();
        this.updateComboDisplay();

        // Pop animation for score
        this.scoreEl.classList.add('pop');
        setTimeout(() => this.scoreEl.classList.remove('pop'), 100);

        // Small screen pulse on collect
        if (this.combo >= 3) {
            this.shakeIntensity = Math.min(this.combo, 5);
        }

        // Haptic feedback hint (if supported)
        if (navigator.vibrate) {
            navigator.vibrate(10);
        }
    }

    updateScoreDisplay() {
        this.scoreEl.textContent = this.score;
    }

    updateComboDisplay() {
        if (this.combo >= 2) {
            this.comboDisplay.classList.remove('hidden');
            this.comboCount.textContent = `x${Math.min(this.combo, 5)}`;
        } else {
            this.comboDisplay.classList.add('hidden');
        }
    }

    updateBestScoreDisplay() {
        this.bestScoreEl.textContent = this.bestScore;
    }

    gameOver() {
        this.state = 'gameover';

        const isNewBest = this.score > this.bestScore;
        if (isNewBest) {
            this.bestScore = this.score;
            this.saveBestScore();
        }

        this.gameUI.classList.add('hidden');

        // Delay showing game over screen for dramatic effect
        setTimeout(() => {
            this.finalScoreEl.textContent = this.score;
            this.gameoverBestEl.textContent = this.bestScore;

            if (isNewBest && this.score > 0) {
                this.newBestEl.classList.remove('hidden');
            } else {
                this.newBestEl.classList.add('hidden');
            }

            this.gameoverScreen.classList.remove('hidden');
            this.updateBestScoreDisplay();
        }, 500);
    }

    loadBestScore() {
        return parseInt(localStorage.getItem('orbit_best_score') || '0');
    }

    saveBestScore() {
        localStorage.setItem('orbit_best_score', this.bestScore.toString());
    }

    draw() {
        const ctx = this.ctx;

        // Apply screen shake
        ctx.save();
        if (this.shakeIntensity > 0) {
            const shakeX = (Math.random() - 0.5) * this.shakeIntensity * 2;
            const shakeY = (Math.random() - 0.5) * this.shakeIntensity * 2;
            ctx.translate(shakeX, shakeY);
        }

        // Clear canvas
        ctx.fillStyle = this.colors.background;
        ctx.fillRect(-10, -10, this.width + 20, this.height + 20);

        // Draw background gradient
        const gradient = ctx.createRadialGradient(
            this.centerX, this.centerY, 0,
            this.centerX, this.centerY, Math.max(this.width, this.height) * 0.7
        );
        gradient.addColorStop(0, 'rgba(10, 20, 40, 1)');
        gradient.addColorStop(1, 'rgba(5, 5, 15, 1)');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, this.width, this.height);

        // Draw background stars
        this.bgStars.forEach(star => {
            const twinkle = Math.sin(Date.now() * star.twinkleSpeed) * 0.3 + 0.7;
            ctx.beginPath();
            ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(255, 255, 255, ${star.alpha * twinkle})`;
            ctx.fill();
        });

        // Draw orbits
        this.orbits.forEach((radius, i) => {
            ctx.beginPath();
            ctx.arc(this.centerX, this.centerY, radius, 0, Math.PI * 2);
            ctx.strokeStyle = this.state === 'playing' && i === this.currentOrbitIndex
                ? this.colors.orbitBright
                : this.colors.orbitDim;
            ctx.lineWidth = 2;
            ctx.stroke();
        });

        if (this.state === 'playing' || this.state === 'gameover') {
            // Draw player trail
            if (this.player && this.player.trail) {
                ctx.beginPath();
                this.player.trail.forEach((point, i) => {
                    if (i === 0) {
                        ctx.moveTo(point.x, point.y);
                    } else {
                        ctx.lineTo(point.x, point.y);
                    }
                });
                ctx.strokeStyle = this.colors.trail;
                ctx.lineWidth = this.playerRadius * 0.8;
                ctx.lineCap = 'round';
                ctx.stroke();
            }

            // Draw stars
            this.stars.forEach(star => {
                const x = this.centerX + Math.cos(star.angle) * star.orbitRadius;
                const y = this.centerY + Math.sin(star.angle) * star.orbitRadius;
                const radius = this.starRadius * star.scale;

                // Glow
                ctx.beginPath();
                ctx.arc(x, y, radius * 2, 0, Math.PI * 2);
                ctx.fillStyle = this.colors.starGlow;
                ctx.fill();

                // Star shape
                this.drawStar(ctx, x, y, 5, radius, radius * 0.5, star.rotation);
            });

            // Draw obstacles
            this.obstacles.forEach(obstacle => {
                const x = this.centerX + Math.cos(obstacle.angle) * obstacle.orbitRadius;
                const y = this.centerY + Math.sin(obstacle.angle) * obstacle.orbitRadius;
                const radius = this.obstacleRadius * obstacle.scale;

                // Glow
                ctx.beginPath();
                ctx.arc(x, y, radius * 1.5, 0, Math.PI * 2);
                ctx.fillStyle = this.colors.obstacleGlow;
                ctx.fill();

                // Asteroid shape
                this.drawAsteroid(ctx, x, y, radius, obstacle.rotation);
            });

            // Draw player (if not game over or recently game over)
            if (this.player && this.state === 'playing') {
                const playerX = this.getPlayerX();
                const playerY = this.getPlayerY();

                // Pulsating glow based on time
                const pulseTime = Date.now() * 0.003;
                const pulseScale = 1 + Math.sin(pulseTime) * 0.15;
                const pulseAlpha = 0.5 + Math.sin(pulseTime) * 0.2;

                // Outer glow (pulsating)
                ctx.beginPath();
                ctx.arc(playerX, playerY, this.playerRadius * 2.5 * pulseScale, 0, Math.PI * 2);
                const outerGlow = ctx.createRadialGradient(
                    playerX, playerY, 0,
                    playerX, playerY, this.playerRadius * 2.5 * pulseScale
                );
                outerGlow.addColorStop(0, `rgba(0, 212, 255, ${pulseAlpha * 0.3})`);
                outerGlow.addColorStop(1, 'transparent');
                ctx.fillStyle = outerGlow;
                ctx.fill();

                // Inner glow
                ctx.beginPath();
                ctx.arc(playerX, playerY, this.playerRadius * 2, 0, Math.PI * 2);
                const glowGradient = ctx.createRadialGradient(
                    playerX, playerY, 0,
                    playerX, playerY, this.playerRadius * 2
                );
                glowGradient.addColorStop(0, this.colors.playerGlow);
                glowGradient.addColorStop(1, 'transparent');
                ctx.fillStyle = glowGradient;
                ctx.fill();

                // Player orb
                ctx.beginPath();
                ctx.arc(playerX, playerY, this.playerRadius, 0, Math.PI * 2);
                const playerGradient = ctx.createRadialGradient(
                    playerX - this.playerRadius * 0.3,
                    playerY - this.playerRadius * 0.3,
                    0,
                    playerX, playerY, this.playerRadius
                );
                playerGradient.addColorStop(0, '#ffffff');
                playerGradient.addColorStop(0.3, this.colors.player);
                playerGradient.addColorStop(1, '#0088aa');
                ctx.fillStyle = playerGradient;
                ctx.fill();

                // Highlight
                ctx.beginPath();
                ctx.arc(playerX - this.playerRadius * 0.25, playerY - this.playerRadius * 0.25,
                        this.playerRadius * 0.3, 0, Math.PI * 2);
                ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
                ctx.fill();
            }
        }

        // Draw particles
        this.particles.forEach(particle => {
            ctx.beginPath();
            ctx.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
            ctx.fillStyle = particle.color.replace(')', `, ${particle.alpha})`).replace('rgb', 'rgba');
            if (particle.color.startsWith('#')) {
                const r = parseInt(particle.color.slice(1, 3), 16);
                const g = parseInt(particle.color.slice(3, 5), 16);
                const b = parseInt(particle.color.slice(5, 7), 16);
                ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${particle.alpha})`;
            }
            ctx.fill();
        });

        // Draw floating scores
        this.floatingScores.forEach(fs => {
            ctx.save();
            ctx.translate(fs.x, fs.y);
            ctx.scale(fs.scale, fs.scale);
            ctx.font = `bold ${fs.isCombo ? 18 : 14}px Orbitron`;
            ctx.textAlign = 'center';
            ctx.fillStyle = fs.isCombo
                ? `rgba(255, 107, 53, ${fs.alpha})`  // Orange for combo
                : `rgba(255, 215, 0, ${fs.alpha})`;  // Gold for normal
            ctx.fillText(`+${fs.points}`, 0, 0);
            ctx.restore();
        });

        // Restore context after screen shake
        ctx.restore();
    }

    drawStar(ctx, cx, cy, spikes, outerRadius, innerRadius, rotation) {
        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(rotation);

        ctx.beginPath();
        for (let i = 0; i < spikes * 2; i++) {
            const radius = i % 2 === 0 ? outerRadius : innerRadius;
            const angle = (i * Math.PI) / spikes - Math.PI / 2;
            const x = Math.cos(angle) * radius;
            const y = Math.sin(angle) * radius;
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        }
        ctx.closePath();

        ctx.fillStyle = this.colors.star;
        ctx.fill();

        ctx.restore();
    }

    drawAsteroid(ctx, cx, cy, radius, rotation) {
        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(rotation);

        ctx.beginPath();
        const points = 8;
        for (let i = 0; i < points; i++) {
            const angle = (i / points) * Math.PI * 2;
            const r = radius * (0.7 + Math.sin(i * 3) * 0.3);
            const x = Math.cos(angle) * r;
            const y = Math.sin(angle) * r;
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        }
        ctx.closePath();

        ctx.fillStyle = this.colors.obstacle;
        ctx.fill();

        ctx.restore();
    }

    animate(currentTime) {
        const deltaTime = currentTime - this.lastTime;
        this.lastTime = currentTime;

        this.update(deltaTime);
        this.draw();

        requestAnimationFrame((time) => this.animate(time));
    }
}

// Start the game when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.orbitGame = new OrbitGame();
});
