import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { CameraSource } from '../camera/CameraSource';
import { FIND_TARGETS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { ColorFeature } from '../features/ColorFeature';
import { DescribeFeature } from '../features/DescribeFeature';
import { Feature, FeatureServices } from '../features/Feature';
import { FindFeature } from '../features/FindFeature';
import { LightFeature } from '../features/LightFeature';
import { ReadFeature } from '../features/ReadFeature';
import { Narrator } from '../speech/Narrator';
import { Overlay } from '../ui/Overlay';
import { YoloDetector } from '../vision/YoloDetector';
import { PaddleTextRecognizer } from '../vision/text/PaddleTextRecognizer';
import { SystemTextRecognizer } from '../vision/text/SystemTextRecognizer';
import { TextReader } from '../vision/text/TextReader';

const PREVIEW_ASPECT: number = 9 / 16;
const MAX_SHOWN_LINES: number = 4;
const BUTTON_HEIGHT: number = 64;
const IDLE_COLOR: string = '#1565C0';
const ACTIVE_COLOR: string = '#C62828';
const BUSY_COLOR: string = '#546E7A';

@Entry
@Component
struct Index {
  @State activeId: string = '';
  @State statusText: string = 'Choose what you need.';
  @State timingText: string = '';
  @State pickerOpen: boolean = false;
  private xController: XComponentController = new XComponentController();
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private sceneOverlay: Overlay = new Overlay(this.canvas);
  private camera: CameraSource = new CameraSource();
  private detector: YoloDetector = new YoloDetector();
  private narrator: Narrator = new Narrator();
  private textReader: TextReader = new TextReader();
  private services: FeatureServices = new FeatureServices(this.camera, this.detector, this.narrator, this.sceneOverlay,
    this.textReader, (text: string) => { this.statusText = text; }, (text: string) => { this.timingText = text; });
  private findFeature: FindFeature = new FindFeature(this.services);
  private features: Feature[] = [
    new DescribeFeature(this.services),
    new ReadFeature(this.services),
    new LightFeature(this.services),
    new ColorFeature(this.services),
    this.findFeature
  ];
  private activeFeature?: Feature;
  private surfaceId: string = '';
  private cameraStarted: boolean = false;
  private cameraStarting: boolean = false;

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear(): Promise<void> {
    this.textReader.add(new SystemTextRecognizer());
    this.textReader.add(new PaddleTextRecognizer(this.ctx()));
    this.textReader.prepare();
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
    this.stopActive();
    this.camera.stop();
    this.textReader.release();
    this.narrator.release();
  }

  private async requestCamera(): Promise<void> {
    const permissions: Permissions[] = ['ohos.permission.CAMERA'];
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.ctx(), permissions);
      if (result.authResults[0] !== 0) {
        this.statusText = 'Camera permission is required.';
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

  private stopActive(): void {
    const feature = this.activeFeature;
    this.activeFeature = undefined;
    this.activeId = '';
    if (feature !== undefined) {
      feature.stop();
    }
  }

  private onFeatureTap(feature: Feature): void {
    if (this.activeId === feature.id) {
      if (feature.continuous) {
        this.stopActive();
      }
      return;
    }
    if (feature.id === this.findFeature.id) {
      this.stopActive();
      this.pickerOpen = true;
      this.narrator.announce('What do you want to find?', true);
      return;
    }
    this.activate(feature);
  }

  private async activate(feature: Feature): Promise<void> {
    this.stopActive();
    if (!this.detector.isReady() || !this.cameraStarted) {
      this.narrator.announce('Not ready yet', true);
      return;
    }
    this.activeFeature = feature;
    this.activeId = feature.id;
    await feature.start();
    if (!feature.continuous && this.activeFeature === feature) {
      this.activeFeature = undefined;
      this.activeId = '';
    }
  }

  private chooseTarget(label: string): void {
    this.pickerOpen = false;
    this.findFeature.setTarget(label);
    this.activate(this.findFeature);
  }

  private buttonColor(feature: Feature): string {
    if (this.activeId !== feature.id) {
      return IDLE_COLOR;
    }
    return feature.continuous ? ACTIVE_COLOR : BUSY_COLOR;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          XComponent({ type: XComponentType.SURFACE, controller: this.xController })
            .onLoad(() => {
              this.surfaceId = this.xController.getXComponentSurfaceId();
              this.startCamera();
            })
            .onAreaChange((oldArea: Area, newArea: Area) => {
              const widthPx = Math.round(this.getUIContext().vp2px(Number(newArea.width)));
              const surfaceHeight = Math.round(widthPx / PREVIEW_ASPECT);
              this.xController.setXComponentSurfaceRect({
                offsetX: 0,
                offsetY: -Math.round((surfaceHeight - widthPx) / 2),
                surfaceWidth: widthPx,
                surfaceHeight: surfaceHeight
              });
            })
            .width('100%')
            .aspectRatio(1)
            .accessibilityLevel('no')
          Canvas(this.canvas)
            .width('100%')
            .height('100%')
            .accessibilityLevel('no')
            .onAreaChange((oldArea: Area, newArea: Area) => {
              this.sceneOverlay.setSize(Number(newArea.width), Number(newArea.height));
            })
        }
        .width('100%')
        .aspectRatio(1)

        Column({ space: 4 }) {
          Text(this.statusText)
            .fontSize(22)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .maxLines(MAX_SHOWN_LINES)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .accessibilityText(this.statusText)
          Text(this.timingText)
            .fontSize(12)
            .fontColor('#B0BEC5')
            .accessibilityLevel('no')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 6 })
        .constraintSize({ minHeight: 96 })

        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.features, (feature: Feature) => {
              Button(this.activeId === feature.id ? feature.activeTitle : feature.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .height(BUTTON_HEIGHT)
                .backgroundColor(this.buttonColor(feature))
                .accessibilityText(this.activeId === feature.id ? feature.activeTitle : feature.title)
                .accessibilityDescription(feature.hint)
                .onClick(() => {
                  this.onFeatureTap(feature);
                })
            }, (feature: Feature) => `${feature.id}-${this.activeId === feature.id}`)
          }
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')

      if (this.pickerOpen) {
        Column({ space: 8 }) {
          Text('What do you want to find?')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ top: 56, bottom: 8 })
            .accessibilityText('What do you want to find?')
          Scroll() {
            Column({ space: 8 }) {
              ForEach(FIND_TARGETS, (label: string) => {
                Button(label)
                  .fontSize(20)
                  .width('100%')
                  .height(BUTTON_HEIGHT)
                  .backgroundColor(IDLE_COLOR)
                  .accessibilityText(`Find ${label}`)
                  .onClick(() => {
                    this.chooseTarget(label);
                  })
              }, (label: string) => label)
            }
          }
          .layoutWeight(1)
          Button('Cancel')
            .fontSize(20)
            .width('100%')
            .height(BUTTON_HEIGHT)
            .backgroundColor(BUSY_COLOR)
            .accessibilityText('Cancel')
            .onClick(() => {
              this.pickerOpen = false;
              this.narrator.announce('Cancelled', true);
            })
        }
        .padding({ left: 16, right: 16, bottom: 24 })
        .width('100%')
        .height('100%')
        .backgroundColor('#F2000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
