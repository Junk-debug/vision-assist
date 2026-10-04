import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ElementIds } from '../accessibility/ElementIds';
import { nextInChain } from '../accessibility/FocusChain';
import { appServices } from '../app/AppServices';
import { FullTextParams, Routes } from '../app/Routes';
import { FOCUS_AFTER_TRANSITION_MS } from '../common/Config';
import { DebugState } from '../common/DebugState';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { FeatureServices } from '../features/Feature';
import { createFeature, FeatureBinding } from '../features/FeatureFactory';
import { haptics } from '../haptics/Haptics';
import { analyzePhotoUri } from '../photo/PhotoAnalysis';
import { pickPhoto } from '../photo/PhotoPicker';
import { Priority } from '../speech/Narrator';
import { ReadingListener } from '../speech/ReadAloud';
import { FEATURE_CATALOG, FeatureInfo, findFeatureInfo, PickerKind } from '../ui/FeatureCatalog';
import { Overlay } from '../ui/Overlay';
import { BigButton, ButtonTone } from '../ui/components/BigButton';
import { CameraPreview } from '../ui/components/CameraPreview';
import { RoundIconButton } from '../ui/components/RoundIconButton';
import { ScreenFrame } from '../ui/components/ScreenFrame';
import { StatusCard } from '../ui/components/StatusCard';
import { TargetSheet } from '../ui/components/TargetSheet';
import { FontSize, Palette, Radius, Sizes, Spacing } from '../ui/theme/Theme';
import { EngineKind, EngineListener, EngineMode } from '../vision/FindEngine';

@Component
export struct FeaturePage {
  featureId: string = '';
  @State status: string = '';
  @State detail: string = '';
  @State running: boolean = false;
  @State liveOn: boolean = false;
  @State busy: boolean = false;
  @State target: string = '';
  @State front: boolean = false;
  @State canSwitch: boolean = false;
  @State resultText: string = '';
  @State photoUri: string = '';
  @State sheetShown: boolean = false;
  @State permissionDenied: boolean = false;
  @State injectedFrame: image.PixelMap | undefined = undefined;
  @State readingIndex: number = -1;
  @State debugOn: boolean = DebugState.enabled;
  @State debugText: string = '';
  @State engineCloud: boolean = false;
  @State engineLabel: string = '';
  @State engineAuto: boolean = true;
  private info: FeatureInfo = FEATURE_CATALOG[0];
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private sceneOverlay: Overlay = new Overlay(this.canvas);
  private binding?: FeatureBinding;
  private pathStack?: NavPathStack;
  private surfaceId: string = '';
  private cameraOpen: boolean = false;
  private visible: boolean = true;
  private switching: boolean = false;
  private firstShow: boolean = true;
  private sheetOpenerId: string = '';
  private resumeAfterSheet: boolean = false;
  private pickedInSheet: boolean = false;
  private returnFocusId: string = '';
  private readingListener: ReadingListener = (index: number) => {
    this.readingIndex = index;
  };
  private engineListener: EngineListener = () => {
    this.refreshEngine();
  };

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.info = findFeatureInfo(this.featureId);
    const services = new FeatureServices(appServices.camera, appServices.detector, appServices.cloudDetector, appServices.findEngine,
      appServices.narrator, this.sceneOverlay,
      appServices.textReader, (text: string) => {
        this.status = text;
      }, (text: string) => {
        this.detail = text;
      }, (text: string) => {
        this.resultText = text;
      });
    services.setDebugSink((text: string) => {
      this.debugText = text;
    });
    this.binding = createFeature(this.info.id, services);
    appServices.narrator.reader.addListener(this.readingListener);
    appServices.findEngine.addListener(this.engineListener);
    this.refreshEngine();
    this.sceneOverlay.setStyle(this.info.accent, false);
    this.status = this.needsTarget() ? this.info.targetPrompt : Messages.STARTING_CAMERA;
    appServices.narrator.announceScreen(this.needsTarget() ? Messages.screenWithPrompt(this.info.name, this.info.targetPrompt) :
      this.info.name);
  }

  aboutToDisappear(): void {
    appServices.narrator.reader.removeListener(this.readingListener);
    appServices.findEngine.removeListener(this.engineListener);
    appServices.narrator.stopReading();
    this.stopFeature();
    this.closeCamera();
    appServices.camera.setPreviewListener(undefined);
    appServices.narrator.announceScreen(Messages.FEATURE_LIST);
    appServices.narrator.screenReader.focus(ElementIds.tile(this.info.id), FOCUS_AFTER_TRANSITION_MS);
  }

  private continuous(): boolean {
    return this.binding !== undefined && this.binding.feature.continuous;
  }

  private needsTarget(): boolean {
    return this.info.picker !== PickerKind.NONE && this.target === '';
  }

  private photoMode(): boolean {
    return this.photoUri !== '';
  }

  private showLive(): boolean {
    return this.binding?.live !== undefined && !this.needsTarget() && !this.photoMode() && !this.permissionDenied;
  }

  private showSwitch(): boolean {
    return this.canSwitch && !this.needsTarget() && !this.photoMode();
  }

  private report(message: string, priority: Priority = Priority.RESULT): void {
    this.status = message;
    appServices.narrator.announce(message, priority);
  }

  private reportFailure(message: string, priority: Priority = Priority.RESULT): void {
    haptics.error();
    this.report(message, priority);
  }

  private reading(): boolean {
    return this.readingIndex >= 0;
  }

  private hasDebug(): boolean {
    return this.info.id === 'find' || this.info.id === 'findword';
  }

  private toggleDebug(): void {
    DebugState.enabled = !DebugState.enabled;
    this.debugOn = DebugState.enabled;
    if (!this.debugOn) {
      this.debugText = '';
    }
  }

  private showEngine(): boolean {
    return this.info.id === 'find' && !this.needsTarget() && appServices.findEngine.hasCloud();
  }

  private refreshEngine(): void {
    const now = Date.now();
    this.engineCloud = appServices.findEngine.current(now) === EngineKind.CLOUD;
    this.engineLabel = appServices.findEngine.label(now);
    this.engineAuto = appServices.findEngine.getMode() === EngineMode.AUTO;
  }

  private toggleEngine(): void {
    appServices.findEngine.toggleMode();
    const auto = appServices.findEngine.getMode() === EngineMode.AUTO;
    if (!this.running) {
      appServices.narrator.announce(auto ? Messages.ENGINE_AUTO : Messages.ENGINE_DEVICE_CHOSEN);
    }
  }

  private stopReading(): void {
    appServices.narrator.stopReading();
    appServices.narrator.announce(Messages.READING_STOPPED, Priority.URGENT);
  }

  private onSurface(surfaceId: string): void {
    this.surfaceId = surfaceId;
    this.openCamera();
  }

  private async openCamera(): Promise<void> {
    if (this.surfaceId === '' || this.cameraOpen || !this.visible || this.photoMode() || this.needsTarget()) {
      return;
    }
    this.cameraOpen = true;
    const context = this.ctx();
    if (!await appServices.ensureCameraPermission(context)) {
      this.cameraOpen = false;
      this.permissionDenied = true;
      this.reportFailure(Messages.CAMERA_PERMISSION_NEEDED, Priority.URGENT);
      return;
    }
    this.permissionDenied = false;
    await appServices.init(context);
    appServices.camera.setPreviewListener((frame: image.PixelMap | undefined) => {
      this.injectedFrame = frame;
    });
    if (!await appServices.camera.start(context, this.surfaceId)) {
      this.cameraOpen = false;
      this.reportFailure(Messages.CAMERA_START_FAILED, Priority.URGENT);
      return;
    }
    this.syncCamera();
    if (this.info.needsDetector && !appServices.detector.isReady()) {
      this.reportFailure(Messages.MODEL_LOAD_FAILED, Priority.URGENT);
      return;
    }
    if (this.continuous()) {
      await this.startFeature(true);
    } else if (this.resultText === '') {
      this.status = this.info.readyText;
    }
  }

  private closeCamera(): void {
    this.cameraOpen = false;
    appServices.camera.stop();
    this.injectedFrame = undefined;
  }

  private syncCamera(): void {
    this.front = appServices.camera.isFront();
    this.canSwitch = appServices.camera.canSwitch();
    if (appServices.camera.previewOnSurface()) {
      this.sceneOverlay.useCameraViewport();
    } else {
      this.sceneOverlay.useFullViewport();
    }
    this.sceneOverlay.setStyle(this.info.accent, appServices.camera.previewMirrored());
  }

  private async startFeature(announce: boolean): Promise<void> {
    if (this.binding === undefined || this.running) {
      return;
    }
    this.running = true;
    await this.binding.feature.start();
    if (announce) {
      appServices.narrator.announce(this.binding.feature.startedMessage());
    }
  }

  private stopFeature(announce: boolean = false): void {
    this.stopLive(false);
    if (this.binding !== undefined && this.running) {
      this.running = false;
      this.binding.feature.stop();
      if (announce) {
        this.status = Messages.STOPPED;
        appServices.narrator.announce(this.binding.feature.stoppedMessage());
      }
    }
  }

  private async onPrimary(): Promise<void> {
    if (this.permissionDenied) {
      await this.allowCamera();
      return;
    }
    if (this.needsTarget()) {
      this.openSheet(ElementIds.FEATURE_PRIMARY);
      return;
    }
    if (this.reading()) {
      this.stopReading();
      return;
    }
    if (this.photoMode()) {
      this.backToCamera();
      return;
    }
    if (!this.cameraOpen || this.binding === undefined) {
      this.report(Messages.CAMERA_NOT_READY);
      return;
    }
    if (this.info.needsDetector && !appServices.detector.isReady()) {
      this.report(Messages.MODEL_LOADING);
      return;
    }
    if (this.continuous()) {
      if (this.running) {
        this.stopFeature(true);
      } else {
        await this.startFeature(true);
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

  private async toggleLive(): Promise<void> {
    const live = this.binding?.live;
    if (live === undefined) {
      return;
    }
    if (this.liveOn) {
      this.stopLive(true);
      return;
    }
    if (!this.cameraOpen) {
      this.report(Messages.CAMERA_NOT_READY);
      return;
    }
    if (this.info.needsDetector && !appServices.detector.isReady()) {
      this.report(Messages.MODEL_LOADING);
      return;
    }
    appServices.narrator.stopReading();
    this.liveOn = true;
    await live.startLive();
    appServices.narrator.announce(Messages.LIVE_STARTED);
  }

  private stopLive(announce: boolean): void {
    if (!this.liveOn) {
      return;
    }
    this.liveOn = false;
    this.binding?.live?.stopLive();
    if (announce) {
      this.status = Messages.LIVE_STOPPED;
      appServices.narrator.announce(Messages.LIVE_STOPPED);
    }
  }

  private async allowCamera(): Promise<void> {
    if (await appServices.requestCameraInSettings(this.ctx())) {
      this.permissionDenied = false;
      this.status = Messages.STARTING_CAMERA;
      await this.openCamera();
      return;
    }
    this.reportFailure(Messages.CAMERA_PERMISSION_NEEDED);
  }

  private openSheet(openerId: string): void {
    this.resumeAfterSheet = this.running;
    this.pickedInSheet = false;
    this.stopFeature();
    this.sheetOpenerId = openerId;
    this.sheetShown = true;
  }

  private onSheetClosed(): void {
    appServices.narrator.screenReader.focus(this.pickedInSheet ? ElementIds.FEATURE_PRIMARY : this.sheetOpenerId,
      FOCUS_AFTER_TRANSITION_MS);
    if (!this.pickedInSheet && this.resumeAfterSheet && this.cameraOpen) {
      this.startFeature(false);
    }
    this.resumeAfterSheet = false;
  }

  private onPick(picked: string): void {
    const trimmed = picked.trim();
    if (trimmed.length === 0) {
      appServices.narrator.announce(Messages.TYPE_A_WORD_FIRST, Priority.URGENT);
      return;
    }
    if (this.info.picker === PickerKind.WORD && !appServices.textReader.isAvailable()) {
      this.reportFailure(Messages.TEXT_READER_UNAVAILABLE, Priority.URGENT);
      return;
    }
    this.binding?.setTarget(trimmed);
    this.pickedInSheet = true;
    this.sheetShown = false;
    const hadTarget = this.target !== '';
    this.target = trimmed;
    if (hadTarget && this.cameraOpen) {
      this.startFeature(true);
    } else {
      this.status = Messages.STARTING_CAMERA;
    }
  }

  private async usePhoto(): Promise<void> {
    const analyzer = this.binding?.photo;
    if (analyzer === undefined || this.busy) {
      return;
    }
    const wasRunning = this.running;
    this.stopFeature();
    appServices.narrator.stopReading();
    let uri = '';
    try {
      uri = await pickPhoto();
    } catch (error) {
      log(`photo picker failed ${describeError(error)}`);
      this.reportFailure(Messages.PICKER_OPEN_FAILED);
      return;
    }
    appServices.narrator.screenReader.focus(ElementIds.FEATURE_PHOTO, FOCUS_AFTER_TRANSITION_MS);
    if (uri === '') {
      appServices.narrator.announce(Messages.NO_PHOTO_CHOSEN);
      if (wasRunning && this.cameraOpen) {
        this.startFeature(false);
      }
      return;
    }
    this.closeCamera();

    this.sceneOverlay.useFullViewport();
    this.sceneOverlay.setStyle(this.info.accent, false);
    this.photoUri = uri;
    this.busy = true;
    this.status = Messages.ANALYSING_PHOTO;
    const analysed = await analyzePhotoUri(uri, analyzer);
    this.busy = false;
    if (!analysed) {
      this.reportFailure(Messages.PHOTO_OPEN_FAILED);
      return;
    }
  }

  private backToCamera(): void {
    appServices.narrator.stopReading();
    this.sceneOverlay.clear();
    this.sceneOverlay.useCameraViewport();
    this.resultText = '';
    this.detail = '';
    this.surfaceId = '';
    this.photoUri = '';
    this.status = Messages.STARTING_CAMERA;
  }

  private openFullText(spoken: boolean): void {
    if (!spoken) {
      appServices.narrator.stopReading();
    }
    const params: FullTextParams = { text: this.resultText, spoken: spoken };
    this.returnFocusId = ElementIds.FEATURE_FULL_TEXT;
    this.pathStack?.pushPathByName(Routes.FULL_TEXT, params);
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
      haptics.error();
    }
    appServices.narrator.announce(switched ? (this.front ? Messages.FRONT_CAMERA_ON : Messages.BACK_CAMERA_ON) :
      Messages.CAMERA_SWITCH_FAILED);
  }

  private goBack(): void {
    this.pathStack?.pop();
  }

  private primaryLabel(): string {
    if (this.permissionDenied) {
      return Messages.CAMERA_PERMISSION_LABEL;
    }
    if (this.needsTarget()) {
      return this.info.chooseTargetLabel;
    }
    if (this.reading()) {
      return Messages.STOP_READING;
    }
    if (this.photoMode()) {
      return Messages.BACK_TO_CAMERA;
    }
    if (this.continuous()) {
      return this.running ? this.info.stopLabel : this.info.startLabel;
    }
    return this.busy ? this.info.busyLabel : this.info.startLabel;
  }

  private primaryHint(): string {
    if (this.permissionDenied) {
      return Messages.CAMERA_PERMISSION_HINT;
    }
    if (this.needsTarget()) {
      return this.info.targetPrompt;
    }
    if (this.reading()) {
      return Messages.STOP_READING_HINT;
    }
    if (this.photoMode()) {
      return Messages.BACK_TO_CAMERA_HINT;
    }
    return Messages.targetHint(this.info.actionHint, this.target);
  }

  private focusChain(): string[] {
    const chain: string[] = [ElementIds.FEATURE_TITLE, ElementIds.FEATURE_STATUS, ElementIds.FEATURE_PRIMARY];
    if (this.showLive()) {
      chain.push(ElementIds.FEATURE_LIVE);
    }
    if (this.resultText !== '') {
      chain.push(ElementIds.FEATURE_FULL_TEXT);
    }
    if (this.info.photoInput) {
      chain.push(ElementIds.FEATURE_PHOTO);
    }
    if (this.info.picker !== PickerKind.NONE && this.target !== '') {
      chain.push(ElementIds.FEATURE_TARGET);
    }
    if (this.showSwitch()) {
      chain.push(ElementIds.FEATURE_SWITCH);
    }
    chain.push(ElementIds.FEATURE_BACK);
    return chain;
  }

  private nextOf(id: string): string {
    return nextInChain(this.focusChain(), id);
  }

  @Builder
  sheetContent() {
    TargetSheet({
      prompt: this.info.targetPrompt,
      targets: this.info.targets,
      allowTyping: this.info.picker !== PickerKind.NONE,
      fieldPlaceholder: this.info.picker === PickerKind.OBJECT ? Messages.TYPE_AN_OBJECT : Messages.TYPE_A_WORD,
      fieldLabel: this.info.picker === PickerKind.OBJECT ? Messages.OBJECT_FIELD_LABEL : Messages.WORD_FIELD_LABEL,
      fieldHint: this.info.picker === PickerKind.OBJECT ? Messages.OBJECT_FIELD_HINT : Messages.WORD_FIELD_HINT,
      startHint: this.info.picker === PickerKind.OBJECT ? Messages.START_TYPED_OBJECT_HINT : Messages.START_TYPED_HINT,
      onPick: (picked: string) => {
        this.onPick(picked);
      },
      onCancel: () => {
        this.sheetShown = false;
      }
    })
  }

  @Builder
  body() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        if (!this.needsTarget()) {
          Column() {
            CameraPreview({
              canvas: this.canvas,
              sceneOverlay: this.sceneOverlay,
              photoUri: this.photoUri,
              injectedFrame: this.injectedFrame,
              onSurface: (surfaceId: string) => {
                this.onSurface(surfaceId);
              }
            })
          }
          .width('100%')
          .flexShrink(1)
        }
        StatusCard({
          status: this.status,
          detail: this.detail,
          elementId: ElementIds.FEATURE_STATUS,
          nextFocusId: this.nextOf(ElementIds.FEATURE_STATUS)
        })
        if (this.showEngine()) {
          Row({ space: Spacing.sm }) {
            Circle()
              .width(10)
              .height(10)
              .fill(this.engineCloud ? Palette.overlayTarget : Palette.disabled)
            Text(this.engineLabel)
              .fontSize(FontSize.caption)
              .fontColor(Palette.textPrimary)
            Text(this.engineAuto ? 'Auto' : 'Manual')
              .fontSize(FontSize.caption)
              .fontColor(Palette.textSecondary)
          }
          .backgroundColor(Palette.card)
          .borderRadius(Radius.chip)
          .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.xs, bottom: Spacing.xs })
          .accessibilityGroup(true)
          .accessibilityText(`${this.engineLabel}. ` + (this.engineAuto ?
            'Automatic: cloud when online, on-device when offline' : 'On-device model only'))
          .accessibilityDescription(this.engineAuto ?
            'Double tap to always use the on-device model' : 'Double tap to use the cloud when online')
          .onClick(() => {
            this.toggleEngine();
          })
        }
        if (this.hasDebug() && !this.needsTarget()) {
          Text(this.debugOn ? 'Debug on' : 'Debug')
            .fontSize(FontSize.caption)
            .fontColor(Palette.onPrimary)
            .backgroundColor(Palette.scrim)
            .borderRadius(Radius.chip)
            .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.xs, bottom: Spacing.xs })
            .accessibilityLevel('no')
            .onClick(() => {
              this.toggleDebug();
            })
          if (this.debugOn && this.debugText !== '') {
            Text(this.debugText)
              .fontSize(FontSize.caption)
              .fontColor(Palette.onPrimary)
              .backgroundColor(Palette.scrim)
              .borderRadius(Radius.chip)
              .padding(Spacing.sm)
              .width('100%')
              .accessibilityLevel('no')
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Start)
      BigButton({
        label: this.primaryLabel(),
        hint: this.primaryHint(),
        tone: this.running || this.reading() ? ButtonTone.STOP : ButtonTone.PRIMARY,
        elementId: ElementIds.FEATURE_PRIMARY,
        nextFocusId: this.nextOf(ElementIds.FEATURE_PRIMARY),
        onTap: () => {
          this.onPrimary();
        }
      })
      if (this.showLive()) {
        BigButton({
          label: this.liveOn ? Messages.STOP_LIVE_DESCRIPTION : Messages.LIVE_DESCRIPTION,
          hint: Messages.LIVE_DESCRIPTION_HINT,
          tone: this.liveOn ? ButtonTone.STOP : ButtonTone.SECONDARY,
          elementId: ElementIds.FEATURE_LIVE,
          nextFocusId: this.nextOf(ElementIds.FEATURE_LIVE),
          onTap: () => {
            this.toggleLive();
          }
        })
      }
      if (this.resultText !== '') {
        BigButton({
          label: Messages.SHOW_FULL_TEXT,
          hint: Messages.SHOW_FULL_TEXT_HINT,
          tone: ButtonTone.SECONDARY,
          elementId: ElementIds.FEATURE_FULL_TEXT,
          nextFocusId: this.nextOf(ElementIds.FEATURE_FULL_TEXT),
          onTap: () => {
            this.openFullText(false);
          }
        })
      }
      if (this.info.photoInput) {
        BigButton({
          label: this.photoMode() ? Messages.USE_ANOTHER_PHOTO : Messages.USE_PHOTO,
          hint: Messages.USE_PHOTO_HINT,
          tone: ButtonTone.SECONDARY,
          elementId: ElementIds.FEATURE_PHOTO,
          nextFocusId: this.nextOf(ElementIds.FEATURE_PHOTO),
          onTap: () => {
            this.usePhoto();
          }
        })
      }
      if (this.info.picker !== PickerKind.NONE && this.target !== '') {
        BigButton({
          label: this.info.changeTargetLabel,
          hint: Messages.changeTargetHint(this.target),
          tone: ButtonTone.SECONDARY,
          elementId: ElementIds.FEATURE_TARGET,
          nextFocusId: this.nextOf(ElementIds.FEATURE_TARGET),
          onTap: () => {
            this.openSheet(ElementIds.FEATURE_TARGET);
          }
        })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: Spacing.page, right: Spacing.page, bottom: Spacing.lg })
  }

  @Builder
  switchButton() {
    if (this.showSwitch()) {
      RoundIconButton({
        icon: $r('sys.symbol.switch_camera'),
        label: this.front ? Messages.SWITCH_TO_BACK : Messages.SWITCH_TO_FRONT,
        hint: Messages.SWITCH_HINT,
        elementId: ElementIds.FEATURE_SWITCH,
        nextFocusId: ElementIds.FEATURE_BACK,
        onTap: () => {
          this.switchCamera();
        }
      })
    }
  }

  build() {
    NavDestination() {
      ScreenFrame({
        title: this.info.name,
        titleId: ElementIds.FEATURE_TITLE,
        titleNextId: this.nextOf(ElementIds.FEATURE_TITLE),
        backId: ElementIds.FEATURE_BACK,
        onBack: () => {
          this.goBack();
        },
        content: () => {
          this.body();
        },
        trailing: () => {
          this.switchButton();
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(Palette.page)
    .bindSheet($$this.sheetShown, this.sheetContent(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: Palette.card,
      onAppear: () => {
        appServices.narrator.screenReader.focus(ElementIds.SHEET_TITLE, FOCUS_AFTER_TRANSITION_MS);
      },
      onDisappear: () => {
        this.onSheetClosed();
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onShown(() => {
      this.visible = true;
      if (this.firstShow) {
        this.firstShow = false;
        if (this.needsTarget() && !appServices.narrator.screenReader.isOn()) {
          this.openSheet(ElementIds.FEATURE_PRIMARY);
        }
      } else if (this.returnFocusId !== '') {
        appServices.narrator.screenReader.focus(this.returnFocusId, FOCUS_AFTER_TRANSITION_MS);
        this.returnFocusId = '';
      }
      this.openCamera();
    })
    .onHidden(() => {
      this.visible = false;
      appServices.narrator.stopReading();
      this.stopFeature();
      this.closeCamera();
    })
  }
}
