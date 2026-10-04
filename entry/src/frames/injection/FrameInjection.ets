import { FrameInjector } from '../../main/ets/camera/FrameSource';
import { InjectedFrameSource } from './InjectedFrameSource';

export function createFrameInjector(): FrameInjector | undefined {
  return new InjectedFrameSource();
}
