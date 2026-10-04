import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ElementIds } from '../accessibility/ElementIds';
import { nextInChain } from '../accessibility/FocusChain';
import { appServices } from '../app/AppServices';
import { FullTextParams, Routes } from '../app/Routes';
import { FOCUS_AFTER_TRANSITION_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { FeatureServices } from '../features/Feature';
import { createFeature, FeatureBinding } from '../features/FeatureFactory';
import { haptics } from '../haptics/Haptics';
import { analyzePhotoUri } from '../photo/PhotoAnalysis';
import { pickPhoto } from '../photo/PhotoPicker';
import { Priority } from '../speech/Narrator';
import { ReadingListener } from '../speech/ReadAloud';
import { splitIntoChunks } from '../speech/TextChunks';
import { FEATURE_CATALOG, FeatureInfo, findFeatureInfo, PickerKind } from '../ui/FeatureCatalog';
import { Overlay } from '../ui/Overlay';
import { BigButton, ButtonTone } from '../ui/components/BigButton';
import { CameraPreview } from '../ui/components/CameraPreview';
import { RoundIconButton } from '../ui/components/RoundIconButton';
import { ScreenFrame } from '../ui/components/ScreenFrame';
import { StatusCard } from '../ui/components/StatusCard';
import { TargetSheet } from '../ui/components/TargetSheet';
import { FontSize, Palette, Radius, Sizes, Spacing } from '../ui/theme/Theme';

const TEXT_PREVIEW_WIDTH: string = '55%';
const TEXT_PANEL_MIN_HEIGHT: number = 96;

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
  @State snapshot: image.PixelMap | undefined = undefined;
  @State readingIndex: number = -1;
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
      }, (text: string) => {
        this.resultText = text;
      });
    services.setSnapshotSink((frame: image.PixelMap) => {
      this.showSnapshot(frame);
    });
    this.binding = createFeature(this.info.id, services);
    appServices.narrator.reader.addListener(this.readingListener);
    this.sceneOverlay.setStyle(this.info.accent, false);
    this.status = this.needsTarget() ? this.info.targetPrompt : Messages.STARTING_CAMERA;
    appServices.narrator.announceScreen(this.needsTarget() ? Messages.screenWithPrompt(this.info.name, this.info.targetPrompt) :
      this.info.name);
  }

  aboutToDisappear(): void {
    appServices.narrator.reader.removeListener(this.readingListener);
    appServices.narrator.stopReading();
    this.releaseSnapshot();
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

  private showSnapshot(frame: image.PixelMap): void {
    this.releaseSnapshot();
    this.snapshot = frame;
    this.sceneOverlay.clear();
    this.sceneOverlay.useFullViewport();
    this.sceneOverlay.setStyle(this.info.accent, false);
  }

  private releaseSnapshot(): void {
    const old = this.snapshot;
    this.snapshot = undefined;
    old?.release();
  }

  private closeSnapshot(): void {
    appServices.narrator.stopReading();
    this.releaseSnapshot();
    this.sceneOverlay.clear();
    this.resultText = '';
    this.detail = '';
    this.syncCamera();
    this.status = this.info.readyText;
    appServices.narrator.screenReader.focus(ElementIds.FEATURE_PRIMARY, FOCUS_AFTER_TRANSITION_MS);
  }

  private stopReading(): void {
    appServices.narrator.stopReading();
    appServices.narrator.announce(Messages.READING_STOPPED, Priority.URGENT);
  }

  private readAgain(): void {
    if (this.resultText !== '') {
      appServices.narrator.readText(this.resultText);
    }
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
    this.releaseSnapshot();
    this.resultText = '';
    this.detail = '';
    this.sceneOverlay.clear();
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
    if (this.resultText !== '') {
      this.openFullText(true);
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
    if (this.snapshot !== undefined && !this.busy) {
      return Messages.READ_NEW_TEXT;
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
    if (this.snapshot !== undefined) {
      return Messages.READ_NEW_TEXT_HINT;
    }
    return Messages.targetHint(this.info.actionHint, this.target);
  }

  private focusChain(): string[] {
    const chain: string[] = [ElementIds.FEATURE_TITLE, ElementIds.FEATURE_STATUS, ElementIds.FEATURE_PRIMARY];
    if (this.showLive()) {
      chain.push(ElementIds.FEATURE_LIVE);
    }
    if (this.snapshot !== undefined && this.resultText !== '') {
      chain.push(ElementIds.SNAPSHOT_READ_AGAIN);
    }
    if (this.snapshot !== undefined) {
      chain.push(ElementIds.SNAPSHOT_BACK);
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
      allowTyping: this.info.picker === PickerKind.WORD,
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
              snapshot: this.snapshot,
              badge: this.snapshot !== undefined ? Messages.SNAPSHOT : '',
              onSurface: (surfaceId: string) => {
                this.onSurface(surfaceId);
              }
            })
          }
          .width(this.resultText !== '' ? TEXT_PREVIEW_WIDTH : '100%')
          .flexShrink(1)
        }
        StatusCard({
          status: this.status,
          detail: this.detail,
          elementId: ElementIds.FEATURE_STATUS,
          nextFocusId: this.nextOf(ElementIds.FEATURE_STATUS)
        })
        if (this.resultText !== '') {
          this.textPanel()
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
      if (this.snapshot !== undefined) {
        Row({ space: Spacing.md }) {
          if (this.resultText !== '') {
            BigButton({
              label: Messages.READ_AGAIN,
              hint: Messages.SNAPSHOT_READ_AGAIN_HINT,
              tone: ButtonTone.SECONDARY,
              elementId: ElementIds.SNAPSHOT_READ_AGAIN,
              nextFocusId: this.nextOf(ElementIds.SNAPSHOT_READ_AGAIN),
              onTap: () => {
                this.readAgain();
              }
            })
            .layoutWeight(1)
          }
          BigButton({
            label: Messages.SNAPSHOT_BACK,
            hint: Messages.SNAPSHOT_BACK_HINT,
            tone: ButtonTone.SECONDARY,
            elementId: ElementIds.SNAPSHOT_BACK,
            nextFocusId: this.nextOf(ElementIds.SNAPSHOT_BACK),
            onTap: () => {
              this.closeSnapshot();
            }
          })
          .layoutWeight(1)
        }
        .width('100%')
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
  textPanel() {
    Scroll() {
      Column({ space: Spacing.sm }) {
        ForEach(splitIntoChunks(this.resultText), (chunk: string, index: number) => {
          Text(chunk)
            .fontSize(FontSize.subtitle)
            .lineHeight(Sizes.fullTextLineHeight - Spacing.md)
            .fontColor(Palette.textPrimary)
            .width('100%')
            .padding(Spacing.xs)
            .borderRadius(Radius.chip)
            .backgroundColor(index === this.readingIndex ? Palette.inputFill : Palette.card)
        }, (chunk: string, index: number) => `${index}:${chunk}`)
      }
      .width('100%')
      .padding(Spacing.md)
    }
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ minHeight: TEXT_PANEL_MIN_HEIGHT })
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
    .borderRadius(Radius.card)
    .backgroundColor(Palette.card)
    .accessibilityLevel('no-hide-descendants')
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
      this.stopFeature();
      this.closeCamera();
    })
  }
}
