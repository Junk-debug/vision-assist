import { describe, it, expect } from '@ohos/hypium';
import { EnginePolicy, EngineState } from '../main/ets/vision/text/EnginePolicy';
import { EngineRunner, SystemTimer, TIMEOUT_ERROR_NAME, withTimeout } from '../main/ets/vision/text/EngineRunner';
import { TextEngine, TextReadResult } from '../main/ets/vision/text/TextTypes';

const SHORT_TIMEOUT_MS: number = 30;
const SLOW_TIMEOUT_MS: number = 2000;

enum Behaviour {
  WORKS = 'works',
  THROWS = 'throws',
  HANGS = 'hangs'
}

class FakeEngine implements TextEngine<number> {
  readonly name: string;
  readonly prepareTimeoutMs: number;
  readonly recognizeTimeoutMs: number;
  ready: boolean;
  prepareDeferred: boolean = false;
  private finishPrepare?: (ready: boolean) => void;
  behaviour: Behaviour = Behaviour.WORKS;
  calls: number = 0;
  released: boolean = false;

  constructor(name: string, ready: boolean, timeoutMs: number) {
    this.name = name;
    this.ready = ready;
    this.prepareTimeoutMs = timeoutMs;
    this.recognizeTimeoutMs = timeoutMs;
  }

  prepare(): Promise<boolean> {
    if (this.prepareDeferred) {
      return new Promise<boolean>((resolve: (ready: boolean) => void) => {
        this.finishPrepare = resolve;
      });
    }
    return Promise.resolve(this.ready);
  }

  recognize(frame: number): Promise<TextReadResult> {
    this.calls += 1;
    if (this.behaviour === Behaviour.THROWS) {
      return Promise.reject(new Error(`${this.name} broken`));
    }
    if (this.behaviour === Behaviour.HANGS) {
      return new Promise<TextReadResult>(() => {
      });
    }
    const result: TextReadResult = { text: `frame ${frame}`, lines: [], words: [], engine: this.name, elapsedMs: 1 };
    return Promise.resolve(result);
  }

  completePrepare(ready: boolean): void {
    if (this.finishPrepare !== undefined) {
      this.finishPrepare(ready);
    }
  }

  release(): void {
    this.released = true;
  }
}

function pause(delayMs: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, delayMs);
  });
}

class Harness {
  readonly policy: EnginePolicy = new EnginePolicy(2);
  readonly lines: string[] = [];
  readonly runner: EngineRunner<number>;

  constructor() {
    this.runner = new EngineRunner<number>(this.policy, {
      timer: new SystemTimer(),
      log: (message: string) => {
        this.lines.push(message);
      },
      describe: (error: Object) => (error as Error).message
    });
  }

  logged(fragment: string): boolean {
    return this.lines.some((line: string) => line.includes(fragment));
  }
}

function engineOf(result: TextReadResult | undefined): string {
  return result === undefined ? 'none' : result.engine;
}

export default function textEnginesTest() {
  describe('textEngines', () => {
    it('policyOrdersReadyEnginesByPriority', 0, () => {
      const policy = new EnginePolicy(2);
      policy.register('system');
      policy.register('on-device');
      expect(policy.hasReady()).assertFalse();
      policy.prepared('on-device', true);
      expect(policy.order().join('|')).assertEqual('on-device');
      policy.prepared('system', true);
      expect(policy.order().join('|')).assertEqual('system|on-device');
      policy.started('system');
      expect(policy.order().join('|')).assertEqual('on-device');
      policy.finished('system');
      expect(policy.order().join('|')).assertEqual('system|on-device');
    });
    it('policyDisablesAfterConsecutiveFailures', 0, () => {
      const policy = new EnginePolicy(2);
      policy.register('system');
      policy.register('on-device');
      policy.prepared('system', true);
      policy.prepared('on-device', true);
      expect(policy.failed('system')).assertFalse();
      policy.succeeded('system');
      expect(policy.failed('system')).assertFalse();
      expect(policy.failed('system')).assertTrue();
      expect(policy.stateOf('system')).assertEqual(EngineState.DISABLED);
      policy.prepared('system', true);
      expect(policy.stateOf('system')).assertEqual(EngineState.DISABLED);
      expect(policy.order().join('|')).assertEqual('on-device');
    });
    it('policyKeepsLastEngine', 0, () => {
      const policy = new EnginePolicy(2);
      policy.register('system');
      policy.register('on-device');
      policy.prepared('system', false);
      policy.prepared('on-device', true);
      expect(policy.failed('on-device')).assertFalse();
      expect(policy.failed('on-device')).assertFalse();
      expect(policy.stateOf('on-device')).assertEqual(EngineState.READY);
    });
    it('withTimeoutRejectsSlowWork', 0, async (done: Function) => {
      let error: Error | undefined = undefined;
      try {
        await withTimeout(new Promise<number>(() => {
        }), SHORT_TIMEOUT_MS, new SystemTimer(), 'slow');
      } catch (caught) {
        error = caught as Error;
      }
      expect(error === undefined ? '' : (error as Error).name).assertEqual(TIMEOUT_ERROR_NAME);
      expect(await withTimeout(Promise.resolve(7), SHORT_TIMEOUT_MS, new SystemTimer(), 'fast')).assertEqual(7);
      done();
    });
    it('systemReadyIsUsed', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SLOW_TIMEOUT_MS);
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      harness.runner.add(system);
      harness.runner.add(fallback);
      await harness.runner.prepare();
      expect(harness.runner.isAvailable()).assertTrue();
      expect(engineOf(await harness.runner.read(1))).assertEqual('system');
      expect(fallback.calls).assertEqual(0);
      expect(harness.logged('text engine in use: system')).assertTrue();
      harness.runner.release();
      expect(system.released && fallback.released).assertTrue();
      done();
    });
    it('systemFailingTwiceIsDisabled', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SLOW_TIMEOUT_MS);
      system.behaviour = Behaviour.THROWS;
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      harness.runner.add(system);
      harness.runner.add(fallback);
      await harness.runner.prepare();
      expect(engineOf(await harness.runner.read(1))).assertEqual('on-device');
      expect(engineOf(await harness.runner.read(2))).assertEqual('on-device');
      expect(engineOf(await harness.runner.read(3))).assertEqual('on-device');
      expect(system.calls).assertEqual(2);
      expect(harness.policy.stateOf('system')).assertEqual(EngineState.DISABLED);
      expect(harness.logged('text engine system disabled for this session')).assertTrue();
      done();
    });
    it('systemTimeoutFallsBackWithinTimeout', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SHORT_TIMEOUT_MS);
      system.behaviour = Behaviour.HANGS;
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      harness.runner.add(system);
      harness.runner.add(fallback);
      await harness.runner.prepare();
      const start = Date.now();
      const result = await harness.runner.read(1);
      const elapsed = Date.now() - start;
      expect(engineOf(result)).assertEqual('on-device');
      expect(elapsed < SLOW_TIMEOUT_MS / 2).assertTrue();
      expect(harness.logged('timed out')).assertTrue();
      expect(engineOf(await harness.runner.read(2))).assertEqual('on-device');
      expect(system.calls).assertEqual(1);
      done();
    });
    it('slowPrepareDoesNotBlockReadyEngine', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SLOW_TIMEOUT_MS);
      system.prepareDeferred = true;
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      harness.runner.add(system);
      harness.runner.add(fallback);
      const preparing = harness.runner.prepare();
      await pause(10);
      expect(harness.policy.stateOf('system')).assertEqual(EngineState.PENDING);
      expect(engineOf(await harness.runner.read(1))).assertEqual('on-device');
      system.completePrepare(true);
      await preparing;
      expect(engineOf(await harness.runner.read(2))).assertEqual('system');
      done();
    });
    it('prepareTimeoutMarksUnavailableAndLateReadyIsUsed', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SHORT_TIMEOUT_MS);
      system.prepareDeferred = true;
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      harness.runner.add(system);
      harness.runner.add(fallback);
      await harness.runner.prepare();
      expect(harness.policy.stateOf('system')).assertEqual(EngineState.UNAVAILABLE);
      expect(engineOf(await harness.runner.read(1))).assertEqual('on-device');
      system.completePrepare(true);
      await pause(10);
      expect(harness.policy.stateOf('system')).assertEqual(EngineState.READY);
      expect(engineOf(await harness.runner.read(2))).assertEqual('system');
      done();
    });
    it('bothFailingReturnsUndefined', 0, async (done: Function) => {
      const harness = new Harness();
      const system = new FakeEngine('system', true, SLOW_TIMEOUT_MS);
      system.behaviour = Behaviour.THROWS;
      const fallback = new FakeEngine('on-device', true, SLOW_TIMEOUT_MS);
      fallback.behaviour = Behaviour.THROWS;
      harness.runner.add(system);
      harness.runner.add(fallback);
      await harness.runner.prepare();
      expect(engineOf(await harness.runner.read(1))).assertEqual('none');
      expect(harness.logged('text read failed: no engine produced a result')).assertTrue();
      expect(engineOf(await harness.runner.read(2))).assertEqual('none');
      expect(harness.runner.isAvailable()).assertTrue();
      done();
    });
    it('noEngineReadyIsUnavailable', 0, async (done: Function) => {
      const harness = new Harness();
      harness.runner.add(new FakeEngine('system', false, SLOW_TIMEOUT_MS));
      harness.runner.add(new FakeEngine('on-device', false, SLOW_TIMEOUT_MS));
      await harness.runner.prepare();
      expect(harness.runner.isAvailable()).assertFalse();
      expect(engineOf(await harness.runner.read(1))).assertEqual('none');
      done();
    });
  });
}
