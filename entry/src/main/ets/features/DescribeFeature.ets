import { image } from '@kit.ImageKit';
import { Feature, FeatureServices, PhotoAnalyzer } from './Feature';
import { DETECTION_THRESHOLD, LIVE_FRAME_INTERVAL_MS } from '../common/Config';
import { Messages } from '../common/Messages';
import { Priority } from '../speech/Narrator';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { ContentRect, DetectionResult } from '../vision/DetectionTypes';
import { describeScene, SceneTracker } from '../vision/SceneTracker';

export class DescribeFeature implements Feature, PhotoAnalyzer {
  readonly id: string = 'describe';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private readonly tracker: SceneTracker = new SceneTracker();
  private running: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  startedMessage(): string {
    return Messages.DESCRIBE_STARTED;
  }

  stoppedMessage(): string {
    return Messages.DESCRIBE_STOPPED;
  }

  async start(): Promise<void> {
    this.tracker.reset();
    this.running = true;
    this.services.setStatus(Messages.DESCRIBE_LOOKING);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), LIVE_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.services.overlay.clear();
  }

  async analyzePhoto(photo: image.PixelMap, content: ContentRect): Promise<void> {
    this.services.overlay.clear();
    this.services.setStatus(Messages.ANALYSING_PHOTO);
    const result = await this.services.detector.detect(photo, DETECTION_THRESHOLD);
    this.services.overlay.drawDetections(result.detections, content);
    this.services.setTiming(this.timings(result));
    const sentence = describeScene(result.detections);
    if (sentence === '') {
      this.services.reportFailure(Messages.NOTHING_IN_PHOTO);
    } else {
      this.services.reportResult(sentence);
    }
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
      this.services.resultReady();
      this.services.narrator.announce(sentence, Priority.BACKGROUND);
    } else if (result.detections.length === 0) {
      this.services.setStatus(Messages.NOTHING_RECOGNISED);
    }
  }

  private timings(result: DetectionResult): string {
    const total = result.preprocessMs + result.inferenceMs + result.postprocessMs;
    return Messages.timing(total, result.preprocessMs, result.inferenceMs, result.postprocessMs);
  }
}
