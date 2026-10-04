import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { FrameGate } from '../main/ets/camera/FrameGate';
import { FrameHandler, FrameInjector, PreviewListener } from '../main/ets/camera/FrameSource';
import { FrameSourceSwitch } from '../main/ets/camera/FrameSourceSwitch';
import { padToSquare, squareLayout } from '../frames/injection/SquareFrame';

class FakeSource implements FrameInjector {
  reachable: boolean = false;
  active: boolean = false;
  starts: number = 0;
  handler?: FrameHandler;
  interval: number = -1;
  rotation: number;
  onSurface: boolean;

  constructor(rotation: number, onSurface: boolean) {
    this.rotation = rotation;
    this.onSurface = onSurface;
  }

  async isReachable(): Promise<boolean> {
    return this.reachable;
  }

  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void {
    this.handler = handler;
    this.interval = minIntervalMs;
  }

  setPreviewListener(listener: PreviewListener | undefined): void {
  }

  async start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    this.active = true;
    this.starts++;
    return true;
  }

  async stop(): Promise<void> {
    this.active = false;
  }

  async switchPosition(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    return false;
  }

  nextFrame(): Promise<image.PixelMap> {
    return new Promise<image.PixelMap>(() => {
    });
  }

  isActive(): boolean {
    return this.active;
  }

  isFront(): boolean {
    return false;
  }

  canSwitch(): boolean {
    return this.onSurface;
  }

  frameRotation(): number {
    return this.rotation;
  }

  previewMirrored(): boolean {
    return false;
  }

  previewOnSurface(): boolean {
    return this.onSurface;
  }
}

const CONTEXT: common.UIAbilityContext = {} as common.UIAbilityContext;

async function noFrame(frame: image.PixelMap): Promise<void> {
}

export default function frameSourceTest() {
  describe('frameGate', () => {
    it('takesTheFirstFrame', 0, () => {
      const gate = new FrameGate();
      gate.setInterval(250);
      expect(gate.tryTake(1000)).assertTrue();
    });
    it('skipsFramesWhileBusy', 0, () => {
      const gate = new FrameGate();
      gate.setInterval(0);
      expect(gate.tryTake(1000)).assertTrue();
      expect(gate.tryTake(2000)).assertFalse();
      gate.release();
      expect(gate.tryTake(2000)).assertTrue();
    });
    it('keepsTheMinimumInterval', 0, () => {
      const gate = new FrameGate();
      gate.setInterval(250);
      expect(gate.tryTake(1000)).assertTrue();
      gate.release();
      expect(gate.tryTake(1100)).assertFalse();
      expect(gate.waitMs(1100)).assertEqual(150);
      expect(gate.tryTake(1250)).assertTrue();
      expect(gate.waitMs(1250)).assertEqual(250);
    });
    it('treatsNegativeIntervalsAsZero', 0, () => {
      const gate = new FrameGate();
      gate.setInterval(-5);
      expect(gate.waitMs(0)).assertEqual(0);
      expect(gate.tryTake(10)).assertTrue();
      gate.release();
      expect(gate.tryTake(10)).assertTrue();
    });
  });

  describe('squareFrame', () => {
    it('centresLandscapeFrames', 0, () => {
      const layout = squareLayout(4, 2);
      expect(layout.side).assertEqual(4);
      expect(layout.offsetX).assertEqual(0);
      expect(layout.offsetY).assertEqual(1);
    });
    it('centresPortraitFrames', 0, () => {
      const layout = squareLayout(3, 6);
      expect(layout.side).assertEqual(6);
      expect(layout.offsetX).assertEqual(1);
      expect(layout.offsetY).assertEqual(0);
    });
    it('copiesRowsIntoTheMiddle', 0, () => {
      const pixels = new Uint8Array(2 * 1 * 4 + 4);
      pixels.set([1, 2, 3, 4, 5, 6, 7, 8, 99, 99, 99, 99]);
      const square = padToSquare(pixels, 2, 1, 12);
      expect(square.length).assertEqual(16);
      expect(square[0]).assertEqual(1);
      expect(square[7]).assertEqual(8);
      expect(square[8]).assertEqual(0);
      expect(square[15]).assertEqual(0);
    });
    it('skipsRowPadding', 0, () => {
      const pixels = new Uint8Array([10, 10, 10, 255, 0, 0, 0, 0, 20, 20, 20, 255, 0, 0, 0, 0]);
      const square = padToSquare(pixels, 1, 2, 8);
      expect(square.length).assertEqual(16);
      expect(square[0]).assertEqual(10);
      expect(square[8]).assertEqual(20);
      expect(square[4]).assertEqual(0);
    });
  });

  describe('frameSourceSwitch', () => {
    it('usesTheCameraWithoutInjector', 0, async () => {
      const camera = new FakeSource(90, true);
      const sources = new FrameSourceSwitch(camera, undefined);
      expect(await sources.start(CONTEXT, 'surface')).assertTrue();
      expect(camera.starts).assertEqual(1);
      expect(sources.injectionAvailable()).assertFalse();
      expect(sources.usingInjectedFrames()).assertFalse();
      expect(sources.frameRotation()).assertEqual(90);
    });
    it('usesTheCameraWhenTheServerIsDown', 0, async () => {
      const camera = new FakeSource(90, true);
      const injector = new FakeSource(0, false);
      const sources = new FrameSourceSwitch(camera, injector);
      await sources.start(CONTEXT, 'surface');
      expect(camera.starts).assertEqual(1);
      expect(injector.starts).assertEqual(0);
      expect(sources.previewOnSurface()).assertTrue();
    });
    it('switchesToInjectedFramesWhenReachable', 0, async () => {
      const camera = new FakeSource(90, true);
      const injector = new FakeSource(0, false);
      const sources = new FrameSourceSwitch(camera, injector);
      sources.setFrameHandler(noFrame, 250);
      injector.reachable = true;
      await sources.start(CONTEXT, 'surface');
      expect(camera.starts).assertEqual(0);
      expect(injector.starts).assertEqual(1);
      expect(sources.usingInjectedFrames()).assertTrue();
      expect(sources.frameRotation()).assertEqual(0);
      expect(sources.previewOnSurface()).assertFalse();
      expect(injector.interval).assertEqual(250);
      expect(camera.handler === undefined).assertTrue();
    });
    it('goesBackToTheCameraOnTheNextStart', 0, async () => {
      const camera = new FakeSource(90, true);
      const injector = new FakeSource(0, false);
      const sources = new FrameSourceSwitch(camera, injector);
      injector.reachable = true;
      await sources.start(CONTEXT, 'surface');
      await sources.stop();
      injector.reachable = false;
      sources.setFrameHandler(noFrame, 150);
      await sources.start(CONTEXT, 'surface');
      expect(sources.usingInjectedFrames()).assertFalse();
      expect(camera.starts).assertEqual(1);
      expect(camera.interval).assertEqual(150);
      expect(injector.handler === undefined).assertTrue();
    });
    it('keepsTheRunningSource', 0, async () => {
      const camera = new FakeSource(90, true);
      const injector = new FakeSource(0, false);
      const sources = new FrameSourceSwitch(camera, injector);
      await sources.start(CONTEXT, 'surface');
      injector.reachable = true;
      await sources.start(CONTEXT, 'surface');
      expect(sources.usingInjectedFrames()).assertFalse();
    });
  });
}
