export class RateLimiter {
  private readonly gapMs: number;
  private lastAt: number = Number.NEGATIVE_INFINITY;

  constructor(gapMs: number) {
    this.gapMs = gapMs;
  }

  allow(now: number): boolean {
    if (now - this.lastAt < this.gapMs) {
      return false;
    }
    this.lastAt = now;
    return true;
  }

  reset(): void {
    this.lastAt = Number.NEGATIVE_INFINITY;
  }
}
