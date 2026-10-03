import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { DETECTION_THRESHOLD, LIVE_FRAME_INTERVAL_MS } from '../common/Config';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { DetectionResult } from '../vision/DetectionTypes';
import { SceneTracker } from '../vision/SceneTracker';

export class DescribeFeature implements Feature {
  readonly id: string = 'describe';
  readonly title: string = 'Start describing';
  readonly activeTitle: string = 'Stop describing';
  readonly hint: string = 'Double tap to switch live description on or off';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private readonly tracker: SceneTracker = new SceneTracker();
  private running: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  async start(): Promise<void> {
    this.tracker.reset();
    this.running = true;
    this.services.setStatus('Looking around.');
    this.services.narrator.announce('Description started', true);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), LIVE_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.services.overlay.clear();
    this.services.setStatus('Stopped.');
    this.services.narrator.announce('Description stopped', true);
  }

  private async process(frame: image.PixelMap): Promise<void> {
    if (!this.running) {
      return;
    }
    const content = await normalizeFrame(frame, this.services.camera.frameRotation());
    const result = await this.services.detector.detect(frame, DETECTION_THRESHOLD);
    if (!this.running) {
      return;
    }
    this.services.overlay.drawDetections(result.detections, content);
    this.services.setTiming(this.timings(result));
    const sentence = this.tracker.update(result.detections, Date.now());
    if (sentence !== undefined) {
      this.services.setStatus(sentence);
      this.services.narrator.announce(sentence);
    } else if (result.detections.length === 0) {
      this.services.setStatus('Nothing recognised.');
    }
  }

  private timings(result: DetectionResult): string {
    const total = result.preprocessMs + result.inferenceMs + result.postprocessMs;
    return `${total} ms (prep ${result.preprocessMs}, model ${result.inferenceMs}, post ${result.postprocessMs})`;
  }
}
