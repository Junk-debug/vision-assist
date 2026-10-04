export class FrameGate {
  private minIntervalMs: number = 0;
  private lastTakenAt: number = 0;
  private busy: boolean = false;
  private taken: boolean = false;

  setInterval(minIntervalMs: number): void {
    this.minIntervalMs = Math.max(0, minIntervalMs);
  }

  tryTake(now: number): boolean {
    if (this.busy) {
      return false;
    }
    if (this.taken && now - this.lastTakenAt < this.minIntervalMs) {
      return false;
    }
    this.busy = true;
    this.taken = true;
    this.lastTakenAt = now;
    return true;
  }

  release(): void {
    this.busy = false;
  }

  isBusy(): boolean {
    return this.busy;
  }

  waitMs(now: number): number {
    if (!this.taken) {
      return 0;
    }
    return Math.max(0, this.lastTakenAt + this.minIntervalMs - now);
  }
}
