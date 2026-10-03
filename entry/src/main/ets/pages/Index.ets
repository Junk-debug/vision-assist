import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { CameraSource } from '../camera/CameraSource';
import { Narrator } from '../speech/Narrator';
import { ContentRect, Detection, DetectionResult } from '../vision/DetectionTypes';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { SceneTracker } from '../vision/SceneTracker';
import { YoloDetector } from '../vision/YoloDetector';
import { describeError, log } from '../common/Logger';

const FRAME_ROTATION: number = 90;
const SCORE_THRESHOLD: number = 0.35;
const FRAME_INTERVAL_MS: number = 250;
const PREVIEW_ASPECT: number = 9 / 16;
const BOX_COLOR: string = '#FFD400';
const LABEL_TEXT_COLOR: string = '#000000';
const LABEL_FONT: string = '14vp sans-serif';
const LABEL_HEIGHT: number = 20;

@Entry
@Component
struct Index {
  @State running: boolean = false;
  @State statusText: string = 'Point the camera and press Start.';
  @State timingText: string = '';
  private xController: XComponentController = new XComponentController();
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private surfaceId: string = '';
  private camera: CameraSource = new CameraSource();
  private detector: YoloDetector = new YoloDetector();
  private narrator: Narrator = new Narrator();
  private tracker: SceneTracker = new SceneTracker();
  private cameraStarted: boolean = false;
  private cameraStarting: boolean = false;

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear(): Promise<void> {
    await this.narrator.init();
    try {
      await this.detector.load(this.ctx());
    } catch (error) {
      this.statusText = 'The recognition model could not be loaded.';
      log(`model load failed ${describeError(error)}`);
    }
    await this.requestCamera();
  }

  aboutToDisappear(): void {
    this.camera.setFrameHandler(undefined, 0);
    this.camera.stop();
    this.narrator.release();
  }

  private async requestCamera(): Promise<void> {
    const permissions: Permissions[] = ['ohos.permission.CAMERA'];
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.ctx(), permissions);
      if (result.authResults[0] !== 0) {
        this.statusText = 'Camera permission is required to describe your surroundings.';
        return;
      }
      await this.startCamera();
    } catch (error) {
      this.statusText = 'The camera permission request failed.';
      log(`permission request failed ${describeError(error)}`);
    }
  }

  private async startCamera(): Promise<void> {
    if (this.cameraStarted || this.cameraStarting || this.surfaceId === '') {
      return;
    }
    const permitted = await abilityAccessCtrl.createAtManager().checkAccessToken(
      this.ctx().applicationInfo.accessTokenId, 'ohos.permission.CAMERA');
    if (permitted !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return;
    }
    this.cameraStarting = true;
    this.cameraStarted = await this.camera.start(this.ctx(), this.surfaceId);
    this.cameraStarting = false;
    if (!this.cameraStarted) {
      this.statusText = 'The camera could not be started.';
    }
  }

  private async toggle(): Promise<void> {
    if (this.running) {
      this.running = false;
      this.camera.setFrameHandler(undefined, 0);
      this.clearOverlay();
      this.statusText = 'Stopped.';
      this.narrator.announce('Description stopped');
      return;
    }
    if (!this.detector.isReady() || !this.cameraStarted) {
      this.narrator.announce('Not ready yet');
      return;
    }
    this.tracker.reset();
    this.running = true;
    this.statusText = 'Looking around.';
    this.narrator.announce('Description started');
    this.camera.setFrameHandler((frame: image.PixelMap) => this.processFrame(frame), FRAME_INTERVAL_MS);
  }

  private async processFrame(frame: image.PixelMap): Promise<void> {
    if (!this.running) {
      return;
    }
    const content = await normalizeFrame(frame, FRAME_ROTATION);
    const result = await this.detector.detect(frame, SCORE_THRESHOLD);
    if (!this.running) {
      return;
    }
    this.drawOverlay(result.detections, content);
    this.timingText = this.timings(result);
    const sentence = this.tracker.update(result.detections, Date.now());
    if (sentence !== undefined) {
      this.statusText = sentence;
      this.narrator.announce(sentence);
    } else if (result.detections.length === 0) {
      this.statusText = 'Nothing recognised.';
    }
  }

  private timings(result: DetectionResult): string {
    const total = result.preprocessMs + result.inferenceMs + result.postprocessMs;
    return `${total} ms (prep ${result.preprocessMs}, model ${result.inferenceMs}, post ${result.postprocessMs})`;
  }

  private clearOverlay(): void {
    this.canvas.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
  }

  private drawOverlay(detections: Detection[], content: ContentRect): void {
    const width = this.canvasWidth;
    const height = this.canvasHeight;
    this.canvas.clearRect(0, 0, width, height);
    this.canvas.lineWidth = 3;
    this.canvas.font = LABEL_FONT;
    for (const detection of detections) {
      const x = (content.left + detection.x1 * content.width) * width;
      const y = (content.top + detection.y1 * content.height) * height;
      const boxW = (detection.x2 - detection.x1) * content.width * width;
      const boxH = (detection.y2 - detection.y1) * content.height * height;
      this.canvas.strokeStyle = BOX_COLOR;
      this.canvas.strokeRect(x, y, boxW, boxH);
      const caption = `${detection.label} ${Math.round(detection.score * 100)}%`;
      const captionW = this.canvas.measureText(caption).width + 8;
      this.canvas.fillStyle = BOX_COLOR;
      this.canvas.fillRect(x, Math.max(0, y - LABEL_HEIGHT), captionW, LABEL_HEIGHT);
      this.canvas.fillStyle = LABEL_TEXT_COLOR;
      this.canvas.fillText(caption, x + 4, Math.max(LABEL_HEIGHT - 5, y - 5));
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Bottom }) {
        XComponent({ type: XComponentType.SURFACE, controller: this.xController })
          .onLoad(() => {
            this.surfaceId = this.xController.getXComponentSurfaceId();
            this.startCamera();
          })
          .width('100%')
          .height('100%')
          .accessibilityLevel('no')
          .onAreaChange((oldArea: Area, newArea: Area) => {
            const uiContext = this.getUIContext();
            this.xController.setXComponentSurfaceRect({
              surfaceWidth: Math.round(uiContext.vp2px(Number(newArea.width))),
              surfaceHeight: Math.round(uiContext.vp2px(Number(newArea.height)))
            });
          })
        Canvas(this.canvas)
          .width('100%')
          .height('100%')
          .accessibilityLevel('no')
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.canvasWidth = Number(newArea.width);
            this.canvasHeight = Number(newArea.height);
          })
        Column({ space: 12 }) {
          Text(this.statusText)
            .fontSize(22)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width('100%')
            .accessibilityText(this.statusText)
          Text(this.timingText)
            .fontSize(12)
            .fontColor('#CCCCCC')
            .accessibilityLevel('no')
          Button(this.running ? 'Stop describing' : 'Start describing')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .height(80)
            .backgroundColor(this.running ? '#C62828' : '#1565C0')
            .accessibilityText(this.running ? 'Stop live description' : 'Start live description')
            .accessibilityDescription('Double tap to switch live description on or off')
            .onClick(() => {
              this.toggle();
            })
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 20 })
        .backgroundColor('#99000000')
      }
      .width('100%')
      .aspectRatio(PREVIEW_ASPECT)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(Color.Black)
  }
}
