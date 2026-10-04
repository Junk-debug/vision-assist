export enum EngineState {
  PENDING = 'pending',
  READY = 'ready',
  UNAVAILABLE = 'unavailable',
  DISABLED = 'disabled'
}

class EngineRecord {
  readonly name: string;
  state: EngineState = EngineState.PENDING;
  failures: number = 0;
  busy: boolean = false;

  constructor(name: string) {
    this.name = name;
  }
}

export class EnginePolicy {
  private readonly maxFailures: number;
  private readonly records: EngineRecord[] = [];

  constructor(maxFailures: number) {
    this.maxFailures = maxFailures;
  }

  register(name: string): void {
    if (this.find(name) === undefined) {
      this.records.push(new EngineRecord(name));
    }
  }

  prepared(name: string, ready: boolean): void {
    const record = this.find(name);
    if (record === undefined || record.state === EngineState.DISABLED) {
      return;
    }
    record.state = ready ? EngineState.READY : EngineState.UNAVAILABLE;
  }

  started(name: string): void {
    const record = this.find(name);
    if (record !== undefined) {
      record.busy = true;
    }
  }

  finished(name: string): void {
    const record = this.find(name);
    if (record !== undefined) {
      record.busy = false;
    }
  }

  succeeded(name: string): void {
    const record = this.find(name);
    if (record !== undefined) {
      record.failures = 0;
    }
  }

  failed(name: string): boolean {
    const record = this.find(name);
    if (record === undefined || record.state === EngineState.DISABLED) {
      return false;
    }
    record.failures += 1;
    if (record.failures < this.maxFailures || !this.hasAlternative(record)) {
      return false;
    }
    record.state = EngineState.DISABLED;
    return true;
  }

  order(): string[] {
    return this.records
      .filter((record: EngineRecord) => record.state === EngineState.READY && !record.busy)
      .map((record: EngineRecord) => record.name);
  }

  hasReady(): boolean {
    return this.records.some((record: EngineRecord) => record.state === EngineState.READY);
  }

  stateOf(name: string): EngineState | undefined {
    const record = this.find(name);
    return record === undefined ? undefined : record.state;
  }

  failuresOf(name: string): number {
    const record = this.find(name);
    return record === undefined ? 0 : record.failures;
  }

  private hasAlternative(excluded: EngineRecord): boolean {
    return this.records.some((record: EngineRecord) => record !== excluded &&
      (record.state === EngineState.READY || record.state === EngineState.PENDING));
  }

  private find(name: string): EngineRecord | undefined {
    return this.records.find((record: EngineRecord) => record.name === name);
  }
}
