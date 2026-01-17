class AudioManager {
  constructor() {
    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.muted = false;
    // Placeholder URLs as requested (unused in this synth-based implementation, but structure is ready)
    this.soundUrls = {
      mine: "data:audio/wav;base64,",
      place: "data:audio/wav;base64,",
      error: "data:audio/wav;base64,",
      milestone: "data:audio/wav;base64,",
      achievement: "data:audio/wav;base64,",
    };
  }

  _ensureContext() {
    if (this.ctx.state === "suspended") {
      this.ctx.resume();
    }
  }

  unlock() {
    this._ensureContext();
  }

  toggleMute() {
    this.muted = !this.muted;
    this._ensureContext();
    return this.muted;
  }

  playSound(name) {
    if (this.muted) return;
    this._ensureContext();

    // In a full implementation with assets, we would load/play from this.soundUrls[name]
    // For this prototype, we synthesize sounds using oscillators.
    switch (name) {
      case "mine":
        this._playMineSound();
        break;
      case "place":
        this._playPlaceSound();
        break;
      case "error":
        this._playErrorSound();
        break;
      case "milestone":
        this._playMilestoneSound();
        break;
      case "achievement":
        this._playAchievementSound();
        break;
    }
  }

  _playMineSound() {
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.connect(gain);
    gain.connect(this.ctx.destination);

    // Pickaxe "clink"
    osc.type = "sine";
    osc.frequency.setValueAtTime(800, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      1200,
      this.ctx.currentTime + 0.05,
    );

    gain.gain.setValueAtTime(0.3, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.1);

    osc.start();
    osc.stop(this.ctx.currentTime + 0.1);
  }

  _playPlaceSound() {
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.connect(gain);
    gain.connect(this.ctx.destination);

    // Heavy "thud"
    osc.type = "square";
    osc.frequency.setValueAtTime(100, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      40,
      this.ctx.currentTime + 0.15,
    );

    gain.gain.setValueAtTime(0.4, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + 0.2);

    osc.start();
    osc.stop(this.ctx.currentTime + 0.2);
  }

  _playErrorSound() {
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.connect(gain);
    gain.connect(this.ctx.destination);

    // Buzzer
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(150, this.ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(120, this.ctx.currentTime + 0.3);

    gain.gain.setValueAtTime(0.2, this.ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0.01, this.ctx.currentTime + 0.3);

    osc.start();
    osc.stop(this.ctx.currentTime + 0.3);
  }

  _playMilestoneSound() {
    const now = this.ctx.currentTime;
    const gain = this.ctx.createGain();
    gain.connect(this.ctx.destination);
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 1.0);

    // Major triad arpeggio
    [440, 554.37, 659.25].forEach((freq, i) => {
      const osc = this.ctx.createOscillator();
      osc.connect(gain);
      osc.type = "triangle";
      osc.frequency.value = freq;
      osc.start(now + i * 0.1);
      osc.stop(now + 1.0);
    });
  }

  _playAchievementSound() {
    const now = this.ctx.currentTime;
    const gain = this.ctx.createGain();
    gain.connect(this.ctx.destination);

    // Create pleasant "pling" sound for achievement unlock
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.4);

    // Play a quick ascending arpeggio (short and pleasant)
    const frequencies = [523.25, 659.25, 783.99]; // C-E-G (C major chord)
    frequencies.forEach((freq, i) => {
      const osc = this.ctx.createOscillator();
      osc.connect(gain);
      osc.type = "sine";
      osc.frequency.value = freq;
      osc.start(now + i * 0.05);
      osc.stop(now + 0.4);
    });
  }
}

export default new AudioManager();
