import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { log } from '../common/Logger';
import { FrameHandler, FrameInjector, FrameSource, PreviewListener } from './FrameSource';

export class FrameSourceSwitch implements FrameSource {
  private readonly camera: FrameSource;
  private readonly injector?: FrameInjector;
  private current: FrameSource;
  private handler?: FrameHandler;
  private minIntervalMs: number = 0;
  private previewListener?: PreviewListener;

  constructor(camera: FrameSource, injector: FrameInjector | undefined) {
    this.camera = camera;
    this.injector = injector;
    this.current = camera;
  }

  injectionAvailable(): boolean {
    return this.injector !== undefined;
  }

  usingInjectedFrames(): boolean {
    return this.injector !== undefined && this.current === this.injector;
  }

  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void {
    this.handler = handler;
    this.minIntervalMs = minIntervalMs;
    this.current.setFrameHandler(handler, minIntervalMs);
  }

  setPreviewListener(listener: PreviewListener | undefined): void {
    this.previewListener = listener;
    this.current.setPreviewListener(listener);
  }

  async start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    await this.select();
    return this.current.start(context, surfaceId);
  }

  stop(): Promise<void> {
    return this.current.stop();
  }

  switchPosition(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    return this.current.switchPosition(context, surfaceId);
  }

  nextFrame(): Promise<image.PixelMap> {
    return this.current.nextFrame();
  }

  isActive(): boolean {
    return this.current.isActive();
  }

  isFront(): boolean {
    return this.current.isFront();
  }

  canSwitch(): boolean {
    return this.current.canSwitch();
  }

  frameRotation(): number {
    return this.current.frameRotation();
  }

  previewMirrored(): boolean {
    return this.current.previewMirrored();
  }

  previewOnSurface(): boolean {
    return this.current.previewOnSurface();
  }

  private async select(): Promise<void> {
    if (this.current.isActive()) {
      return;
    }
    let next: FrameSource = this.camera;
    if (this.injector !== undefined && await this.injector.isReachable()) {
      next = this.injector;
    }
    if (next === this.current) {
      return;
    }
    this.current.setFrameHandler(undefined, 0);
    this.current.setPreviewListener(undefined);
    this.current = next;
    this.current.setFrameHandler(this.handler, this.minIntervalMs);
    this.current.setPreviewListener(this.previewListener);
    log(next === this.camera ? 'frame source: camera' : 'frame source: injected frames');
  }
}
