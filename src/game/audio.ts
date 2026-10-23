export class FlightAudio {
  private context: AudioContext | null = null;
  private rotorGain: GainNode | null = null;
  private enabled = false;

  async toggle() {
    this.enabled = !this.enabled;
    if (this.enabled) {
      if (!this.context) this.initialize();
      await this.context?.resume();
    }
    if (this.rotorGain && this.context) {
      this.rotorGain.gain.setTargetAtTime(
        this.enabled ? 1 : 0,
        this.context.currentTime,
        0.15,
      );
    }
    return this.enabled;
  }

  private initialize() {
    const context = new AudioContext();
    this.context = context;
    const buffer = context.createBuffer(
      1,
      context.sampleRate * 2,
      context.sampleRate,
    );
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    const noise = context.createBufferSource();
    noise.buffer = buffer;
    noise.loop = true;
    const filter = context.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 380;
    const gain = context.createGain();
    gain.gain.value = 0.035;
    const master = context.createGain();
    master.gain.value = 0;
    const pulse = context.createOscillator();
    pulse.frequency.value = 19;
    const pulseGain = context.createGain();
    pulseGain.gain.value = 0.018;
    pulse.connect(pulseGain);
    pulseGain.connect(gain.gain);
    noise.connect(filter);
    filter.connect(gain);
    gain.connect(master);
    master.connect(context.destination);
    noise.start();
    pulse.start();
    this.rotorGain = master;
  }

  cue(type: "rescue" | "damage" | "complete" | "winch") {
    if (!this.enabled || !this.context) return;
    const context = this.context;
    const oscillator = context.createOscillator();
    const volume = context.createGain();
    const frequencies = { rescue: 660, damage: 140, complete: 880, winch: 420 };
    oscillator.type = type === "damage" ? "sawtooth" : "sine";
    oscillator.frequency.setValueAtTime(frequencies[type], context.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(
      frequencies[type] * 1.5,
      context.currentTime + 0.16,
    );
    volume.gain.setValueAtTime(0.09, context.currentTime);
    volume.gain.exponentialRampToValueAtTime(0.001, context.currentTime + 0.35);
    oscillator.connect(volume);
    volume.connect(context.destination);
    oscillator.start();
    oscillator.stop(context.currentTime + 0.36);
  }

  destroy() {
    void this.context?.close();
  }
}
