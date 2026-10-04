import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';

export type FrameHandler = (frame: image.PixelMap) => Promise<void>;

export type PreviewListener = (frame: image.PixelMap | undefined) => void;

export interface FrameSource {
  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void;
  setPreviewListener(listener: PreviewListener | undefined): void;
  start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean>;
  stop(): Promise<void>;
  switchPosition(context: common.UIAbilityContext, surfaceId: string): Promise<boolean>;
  nextFrame(): Promise<image.PixelMap>;
  isActive(): boolean;
  isFront(): boolean;
  canSwitch(): boolean;
  frameRotation(): number;
  previewMirrored(): boolean;
  previewOnSurface(): boolean;
}

export interface FrameInjector extends FrameSource {
  isReachable(): Promise<boolean>;
}
