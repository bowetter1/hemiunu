/**
 * Screen effects system - shake, flash, etc.
 */
export class ScreenEffects {
    constructor(scene) {
        this.scene = scene;
        this.shakeIntensity = 0;
    }
    
    shake(intensity = 5, duration = 200) {
        this.scene.cameras.main.shake(duration, intensity / 1000);
    }
    
    flash(color, alpha = 0.3, duration = 200) {
        const { width, height } = this.scene.scale;
        const flash = this.scene.add.rectangle(
            width / 2,
            height / 2,
            width,
            height,
            color,
            alpha
        ).setDepth(1000);
        
        this.scene.tweens.add({
            targets: flash,
            alpha: 0,
            duration: duration,
            onComplete: () => flash.destroy()
        });
    }
    
    // Continuous shake based on panic level
    updatePanicShake(panicLevel) {
        if (panicLevel > 70) {
            const intensity = (panicLevel - 70) / 30 * 3;
            if (Math.random() < 0.1) {
                this.shake(intensity, 50);
            }
        }
    }
}
