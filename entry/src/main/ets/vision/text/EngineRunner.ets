import { EnginePolicy } from './EnginePolicy';
import { TextEngine, TextReadResult } from './TextTypes';

export interface Timer {
  start(delayMs: number, onExpire: () => void): number;
  cancel(id: number): void;
}

export class SystemTimer implements Timer {
  start(delayMs: number, onExpire: () => void): number {
    return setTimeout(onExpire, delayMs);
  }

  cancel(id: number): void {
    clearTimeout(id);
  }
}

export const TIMEOUT_ERROR_NAME: string = 'TimeoutError';

function timeoutError(message: string): Error {
  const error = new Error(message);
  error.name = TIMEOUT_ERROR_NAME;
  return error;
}

export function withTimeout<T>(work: Promise<T>, delayMs: number, timer: Timer, label: string): Promise<T> {
  return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void) => {
    const id = timer.start(delayMs, () => reject(timeoutError(`${label} timed out after ${delayMs} ms`)));
    work.then((value: T) => {
      timer.cancel(id);
      resolve(value);
    }, (error: Error) => {
      timer.cancel(id);
      reject(error);
    });
  });
}

export interface EngineEnvironment {
  timer: Timer;
  log: (message: string) => void;
  describe: (error: Object) => string;
}

export class EngineRunner<F> {
  private readonly engines: TextEngine<F>[] = [];
  private readonly policy: EnginePolicy;
  private readonly environment: EngineEnvironment;
  private lastEngine: string = '';

  constructor(policy: EnginePolicy, environment: EngineEnvironment) {
    this.policy = policy;
    this.environment = environment;
  }

  add(engine: TextEngine<F>): void {
    this.engines.push(engine);
    this.policy.register(engine.name);
  }

  async prepare(): Promise<void> {
    await Promise.all(this.engines.map((engine: TextEngine<F>) => this.prepareOne(engine)));
  }

  isAvailable(): boolean {
    return this.policy.hasReady();
  }

  async read(frame: F): Promise<TextReadResult | undefined> {
    for (const name of this.policy.order()) {
      const engine = this.engines.find((candidate: TextEngine<F>) => candidate.name === name);
      if (engine === undefined) {
        continue;
      }
      const result = await this.attempt(engine, frame);
      if (result !== undefined) {
        return result;
      }
    }
    this.environment.log('text read failed: no engine produced a result');
    return undefined;
  }

  release(): void {
    for (const engine of this.engines) {
      engine.release();
    }
  }

  private async prepareOne(engine: TextEngine<F>): Promise<void> {
    const work = this.prepareSafely(engine);
    try {
      const ready = await withTimeout(work, engine.prepareTimeoutMs, this.environment.timer, `${engine.name} prepare`);
      this.policy.prepared(engine.name, ready);
      this.environment.log(`text engine ${engine.name} ready: ${ready}`);
    } catch (error) {
      this.policy.prepared(engine.name, false);
      this.environment.log(`text engine ${engine.name} not ready: ${this.environment.describe(error)}`);
      work.then((ready: boolean) => {
        if (ready) {
          this.policy.prepared(engine.name, true);
          this.environment.log(`text engine ${engine.name} became ready late`);
        }
      });
    }
  }

  private async prepareSafely(engine: TextEngine<F>): Promise<boolean> {
    try {
      return await engine.prepare();
    } catch (error) {
      this.environment.log(`text engine ${engine.name} prepare failed: ${this.environment.describe(error)}`);
      return false;
    }
  }

  private async recognizeSafely(engine: TextEngine<F>, frame: F): Promise<TextReadResult> {
    return engine.recognize(frame);
  }

  private async attempt(engine: TextEngine<F>, frame: F): Promise<TextReadResult | undefined> {
    const name = engine.name;
    this.policy.started(name);
    const work = this.recognizeSafely(engine, frame);
    work.then(() => this.policy.finished(name), () => this.policy.finished(name));
    try {
      const result = await withTimeout(work, engine.recognizeTimeoutMs, this.environment.timer, `${name} recognize`);
      this.policy.succeeded(name);
      if (this.lastEngine !== name) {
        this.environment.log(`text engine in use: ${name}`);
        this.lastEngine = name;
      }
      return result;
    } catch (error) {
      this.environment.log(`text engine ${name} failed: ${this.environment.describe(error)}`);
      if (this.policy.failed(name)) {
        this.environment.log(`text engine ${name} disabled for this session after ${this.policy.failuresOf(name)} failures`);
      }
      return undefined;
    }
  }
}
