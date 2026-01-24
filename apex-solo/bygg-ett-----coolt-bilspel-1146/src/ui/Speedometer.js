/**
 * GRAVSHIFT - Speedometer Component
 * Standalone speedometer gauge
 */

class Speedometer {
    constructor(scene, x, y, radius = 60) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.radius = radius;
        
        this.speed = 0;
        this.maxSpeed = 1000;
        this.targetSpeed = 0;
        
        this.container = scene.add.container(x, y);
        this.container.setDepth(1000);
        
        this.create();
    }
    
    create() {
        // Background circle
        this.background = this.scene.add.graphics();
        this.drawBackground();
        this.container.add(this.background);
        
        // Speed arc
        this.arc = this.scene.add.graphics();
        this.container.add(this.arc);
        
        // Needle
        this.needle = this.scene.add.graphics();
        this.container.add(this.needle);
        
        // Center cap
        this.centerCap = this.scene.add.graphics();
        this.centerCap.fillStyle(0x1a1a2e, 1);
        this.centerCap.fillCircle(0, 0, this.radius * 0.15);
        this.centerCap.lineStyle(2, 0x00ffff, 1);
        this.centerCap.strokeCircle(0, 0, this.radius * 0.15);
        this.container.add(this.centerCap);
        
        // Speed text
        this.speedText = this.scene.add.text(0, this.radius * 0.1, '0', {
            fontFamily: 'Orbitron, sans-serif',
            fontSize: `${this.radius * 0.4}px`,
            color: '#ffffff',
        }).setOrigin(0.5);
        this.container.add(this.speedText);
        
        // Unit label
        this.unitText = this.scene.add.text(0, this.radius * 0.5, 'KM/H', {
            fontFamily: 'Rajdhani, sans-serif',
            fontSize: `${this.radius * 0.15}px`,
            color: '#888888',
        }).setOrigin(0.5);
        this.container.add(this.unitText);
    }
    
    drawBackground() {
        this.background.clear();
        
        // Outer ring
        this.background.fillStyle(0x0a0a0f, 0.9);
        this.background.fillCircle(0, 0, this.radius);
        
        // Gradient ring
        for (let i = 0; i < 10; i++) {
            const r = this.radius - i * 2;
            const alpha = 0.1 - i * 0.01;
            this.background.lineStyle(2, 0x00ffff, alpha);
            this.background.strokeCircle(0, 0, r);
        }
        
        // Tick marks
        this.background.lineStyle(2, 0x444444, 1);
        const startAngle = Math.PI * 0.75;
        const endAngle = Math.PI * 2.25;
        const ticks = 10;
        
        for (let i = 0; i <= ticks; i++) {
            const angle = startAngle + (i / ticks) * (endAngle - startAngle);
            const innerR = this.radius * 0.75;
            const outerR = this.radius * 0.9;
            
            const x1 = Math.cos(angle) * innerR;
            const y1 = Math.sin(angle) * innerR;
            const x2 = Math.cos(angle) * outerR;
            const y2 = Math.sin(angle) * outerR;
            
            // Major ticks
            if (i % 2 === 0) {
                this.background.lineStyle(3, 0x666666, 1);
            } else {
                this.background.lineStyle(1, 0x444444, 1);
            }
            
            this.background.lineBetween(x1, y1, x2, y2);
        }
        
        // Outer border
        this.background.lineStyle(3, 0x00ffff, 0.5);
        this.background.strokeCircle(0, 0, this.radius);
    }
    
    drawArc(percent) {
        this.arc.clear();
        
        const startAngle = Math.PI * 0.75;
        const totalAngle = Math.PI * 1.5;
        const endAngle = startAngle + totalAngle * percent;
        
        // Determine color based on speed
        let color;
        if (percent > 0.9) {
            color = 0xff0000;
        } else if (percent > 0.7) {
            color = 0xffff00;
        } else if (percent > 0.5) {
            color = 0x00ff00;
        } else {
            color = 0x00ffff;
        }
        
        // Draw arc segments
        const segments = Math.ceil(percent * 20);
        const innerR = this.radius * 0.6;
        const outerR = this.radius * 0.75;
        
        for (let i = 0; i < segments; i++) {
            const segStart = startAngle + (i / 20) * totalAngle;
            const segEnd = startAngle + ((i + 1) / 20) * totalAngle;
            
            if (segEnd > endAngle) break;
            
            const segPercent = i / 20;
            let segColor = color;
            
            // Gradient effect
            if (segPercent > 0.7) {
                segColor = ColorUtils.lerpColor(0x00ffff, 0xff0000, (segPercent - 0.7) / 0.3);
            }
            
            this.arc.fillStyle(segColor, 0.8);
            this.arc.slice(0, 0, outerR, segStart, segEnd);
            this.arc.fillPath();
            
            // Cut out inner
            this.arc.fillStyle(0x0a0a0f, 1);
            this.arc.slice(0, 0, innerR, segStart - 0.05, segEnd + 0.05);
            this.arc.fillPath();
        }
        
        // Glow effect at the end
        const glowX = Math.cos(endAngle) * (innerR + (outerR - innerR) / 2);
        const glowY = Math.sin(endAngle) * (innerR + (outerR - innerR) / 2);
        
        this.arc.fillStyle(color, 0.5);
        this.arc.fillCircle(glowX, glowY, 8);
        this.arc.fillStyle(0xffffff, 0.8);
        this.arc.fillCircle(glowX, glowY, 4);
    }
    
    drawNeedle(percent) {
        this.needle.clear();
        
        const startAngle = Math.PI * 0.75;
        const totalAngle = Math.PI * 1.5;
        const angle = startAngle + totalAngle * percent;
        
        const length = this.radius * 0.65;
        const tipX = Math.cos(angle) * length;
        const tipY = Math.sin(angle) * length;
        
        // Needle shadow
        this.needle.fillStyle(0x000000, 0.3);
        this.needle.fillTriangle(
            tipX + 2, tipY + 2,
            -5 + 2, 5 + 2,
            5 + 2, -5 + 2
        );
        
        // Needle body
        this.needle.fillStyle(0xff0000, 1);
        this.needle.fillTriangle(tipX, tipY, -4, 4, 4, -4);
        
        // Needle highlight
        this.needle.fillStyle(0xffffff, 0.5);
        this.needle.fillTriangle(tipX, tipY, -2, 0, 0, -2);
    }
    
    setSpeed(speed, maxSpeed = null) {
        this.targetSpeed = speed;
        if (maxSpeed !== null) {
            this.maxSpeed = maxSpeed;
        }
    }
    
    update(deltaTime) {
        // Smooth speed animation
        this.speed = MathUtils.lerp(this.speed, this.targetSpeed, 0.15);
        
        const percent = Math.min(this.speed / this.maxSpeed, 1);
        
        // Update visuals
        this.drawArc(percent);
        this.drawNeedle(percent);
        
        // Update text
        const displaySpeed = Math.floor(this.speed * 0.5); // Convert to KM/H-like
        this.speedText.setText(displaySpeed.toString());
        
        // Color text based on speed
        if (percent > 0.9) {
            this.speedText.setColor('#ff0000');
        } else if (percent > 0.7) {
            this.speedText.setColor('#ffff00');
        } else {
            this.speedText.setColor('#ffffff');
        }
    }
    
    setPosition(x, y) {
        this.x = x;
        this.y = y;
        this.container.setPosition(x, y);
    }
    
    setVisible(visible) {
        this.container.setVisible(visible);
    }
    
    destroy() {
        this.container.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Speedometer = Speedometer;
}
