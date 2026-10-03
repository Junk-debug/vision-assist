import { common } from '@kit.AbilityKit';
import { appServices } from '../app/AppServices';
import { FeatureServices } from '../features/Feature';
import { createFeature, FeatureBinding } from '../features/FeatureFactory';
import { FEATURE_CATALOG, FeatureInfo, findFeatureInfo, PickerKind } from '../ui/FeatureCatalog';
import { Overlay } from '../ui/Overlay';
import { BigButton, ButtonTone } from '../ui/components/BigButton';
import { CameraPreview } from '../ui/components/CameraPreview';
import { StatusCard } from '../ui/components/StatusCard';
import { TargetSheet } from '../ui/components/TargetSheet';
import { TopBar } from '../ui/components/TopBar';
import { Palette, Sizes, Spacing } from '../ui/theme/Theme';

@Component
export struct FeaturePage {
  featureId: string = '';
  @State status: string = '';
  @State detail: string = '';
  @State running: boolean = false;
  @State busy: boolean = false;
  @State target: string = '';
  @State front: boolean = false;
  @State canSwitch: boolean = false;
  private info: FeatureInfo = FEATURE_CATALOG[0];
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private sceneOverlay: Overlay = new Overlay(this.canvas);
  private binding?: FeatureBinding;
  private pathStack?: NavPathStack;
  private surfaceId: string = '';
  private cameraOpen: boolean = false;
  private visible: boolean = true;
  private switching: boolean = false;

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.info = findFeatureInfo(this.featureId);
    const services = new FeatureServices(appServices.camera, appServices.detector, appServices.narrator, this.sceneOverlay,
      appServices.textReader, (text: string) => {
        this.status = text;
      }, (text: string) => {
        this.detail = text;
      });
    this.binding = createFeature(this.info.id, services);
    this.sceneOverlay.setStyle(this.info.accent, false);
    if (this.needsTarget()) {
      this.status = this.info.targetPrompt;
      appServices.narrator.announce(`${this.info.name}. ${this.info.targetPrompt}`, true);
    } else {
      this.status = 'Starting the camera.';
      appServices.narrator.announce(this.info.name, true);
    }
  }

  aboutToDisappear(): void {
    this.stopFeature();
    this.closeCamera();
    appServices.narrator.announce('Feature list', true);
  }

  private needsTarget(): boolean {
    return this.info.picker !== PickerKind.NONE && this.target === '';
  }

  private report(message: string): void {
    this.status = message;
    appServices.narrator.announce(message, true);
  }

  private onSurface(surfaceId: string): void {
    this.surfaceId = surfaceId;
    this.openCamera();
  }

  private async openCamera(): Promise<void> {
    if (this.surfaceId === '' || this.cameraOpen || !this.visible) {
      return;
    }
    this.cameraOpen = true;
    const context = this.ctx();
    if (!await appServices.ensureCameraPermission(context)) {
      this.cameraOpen = false;
      this.report('Camera access is needed. Allow it in Settings, then open this feature again.');
      return;
    }
    await appServices.init(context);
    if (!await appServices.camera.start(context, this.surfaceId)) {
      this.cameraOpen = false;
      this.report('The camera could not be started.');
      return;
    }
    this.syncCamera();
    if (this.info.needsDetector && !appServices.detector.isReady()) {
      this.report('The recognition model could not be loaded.');
      return;
    }
    if (this.info.continuous) {
      await this.startFeature();
    } else {
      this.status = this.info.readyText;
    }
  }

  private closeCamera(): void {
    this.cameraOpen = false;
    appServices.camera.stop();
  }

  private syncCamera(): void {
    this.front = appServices.camera.isFront();
    this.canSwitch = appServices.camera.canSwitch();
    this.sceneOverlay.setStyle(this.info.accent, appServices.camera.previewMirrored());
  }

  private async startFeature(): Promise<void> {
    if (this.binding === undefined || this.running) {
      return;
    }
    this.running = true;
    await this.binding.feature.start();
  }

  private stopFeature(): void {
    if (this.binding !== undefined && this.running) {
      this.running = false;
      this.binding.feature.stop();
    }
  }

  private async onPrimary(): Promise<void> {
    if (!this.cameraOpen || this.binding === undefined) {
      this.report('The camera is not ready yet.');
      return;
    }
    if (this.info.needsDetector && !appServices.detector.isReady()) {
      this.report('The recognition model is still loading.');
      return;
    }
    if (this.info.continuous) {
      if (this.running) {
        this.stopFeature();
      } else {
        await this.startFeature();
      }
      return;
    }
    if (this.busy) {
      return;
    }
    this.busy = true;
    await this.binding.feature.start();
    this.busy = false;
  }

  private onPick(target: string): void {
    const trimmed = target.trim();
    if (trimmed.length === 0) {
      appServices.narrator.announce('Type a word first', true);
      return;
    }
    if (this.info.picker === PickerKind.WORD && !appServices.textReader.isAvailable()) {
      this.report('Text reading is not available on this device yet.');
      return;
    }
    this.binding?.setTarget(trimmed);
    this.status = 'Starting the camera.';
    this.target = trimmed;
  }

  private changeTarget(): void {
    this.stopFeature();
    this.closeCamera();
    this.surfaceId = '';
    this.target = '';
    this.status = this.info.targetPrompt;
    appServices.narrator.announce(this.info.targetPrompt, true);
  }

  private async switchCamera(): Promise<void> {
    if (!this.cameraOpen || this.switching) {
      return;
    }
    this.switching = true;
    this.sceneOverlay.clear();
    const switched = await appServices.camera.switchPosition(this.ctx(), this.surfaceId);
    this.syncCamera();
    this.switching = false;
    if (!switched) {
      appServices.narrator.announce('The camera could not be switched', true);
      return;
    }
    appServices.narrator.announce(this.front ? 'Front camera' : 'Back camera', true);
  }

  private goBack(): void {
    this.pathStack?.pop();
  }

  private primaryLabel(): string {
    if (this.info.continuous) {
      return this.running ? this.info.stopLabel : this.info.startLabel;
    }
    return this.busy ? this.info.busyLabel : this.info.startLabel;
  }

  private primaryHint(): string {
    if (this.target !== '') {
      return `${this.info.actionHint}. Looking for ${this.target}`;
    }
    return this.info.actionHint;
  }

  build() {
    NavDestination() {
      Column({ space: Spacing.md }) {
        TopBar({
          title: this.info.name,
          showSwitch: this.canSwitch && !this.needsTarget(),
          switchLabel: this.front ? 'Switch to back camera' : 'Switch to front camera',
          onBack: () => {
            this.goBack();
          },
          onSwitch: () => {
            this.switchCamera();
          }
        })
        .padding({ left: Spacing.page, right: Spacing.page })

        if (this.needsTarget()) {
          TargetSheet({
            prompt: this.info.targetPrompt,
            targets: this.info.targets,
            allowTyping: this.info.picker === PickerKind.WORD,
            onPick: (target: string) => {
              this.onPick(target);
            }
          })
        } else {
          Column({ space: Spacing.md }) {
            CameraPreview({
              canvas: this.canvas,
              sceneOverlay: this.sceneOverlay,
              onSurface: (surfaceId: string) => {
                this.onSurface(surfaceId);
              }
            })
            .constraintSize({ maxWidth: Sizes.maxContentWidth })
            StatusCard({ status: this.status, detail: this.detail })
            BigButton({
              label: this.primaryLabel(),
              hint: this.primaryHint(),
              tone: this.running ? ButtonTone.STOP : ButtonTone.PRIMARY,
              onTap: () => {
                this.onPrimary();
              }
            })
            if (this.info.picker !== PickerKind.NONE) {
              BigButton({
                label: this.info.changeTargetLabel,
                hint: `Currently looking for ${this.target}`,
                tone: ButtonTone.SECONDARY,
                onTap: () => {
                  this.changeTarget();
                }
              })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: Spacing.page, right: Spacing.page, bottom: Spacing.lg })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Palette.page)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onShown(() => {
      this.visible = true;
      this.openCamera();
    })
    .onHidden(() => {
      this.visible = false;
      this.stopFeature();
      this.closeCamera();
    })
  }
}
