import { image } from '@kit.ImageKit';
import { Overlay } from '../Overlay';
import { FontSize, Palette, Radius, Spacing } from '../theme/Theme';

const SURFACE_ASPECT: number = 9 / 16;

@Component
export struct CameraPreview {
  canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  sceneOverlay?: Overlay;
  @Prop photoUri: string = '';
  @Prop injectedFrame: image.PixelMap | undefined = undefined;
  @Prop snapshot: image.PixelMap | undefined = undefined;
  @Prop badge: string = '';
  onSurface: (surfaceId: string) => void = (surfaceId: string) => {};
  private xController: XComponentController = new XComponentController();

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.photoUri !== '') {
        Image(this.photoUri)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .accessibilityLevel('no')
      } else {
        XComponent({ type: XComponentType.SURFACE, controller: this.xController })
          .onLoad(() => {
            this.onSurface(this.xController.getXComponentSurfaceId());
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            const widthPx = Math.round(this.getUIContext().vp2px(Number(newArea.width)));
            const surfaceHeight = Math.round(widthPx / SURFACE_ASPECT);
            this.xController.setXComponentSurfaceRect({
              offsetX: 0,
              offsetY: -Math.round((surfaceHeight - widthPx) / 2),
              surfaceWidth: widthPx,
              surfaceHeight: surfaceHeight
            });
          })
          .width('100%')
          .height('100%')
          .accessibilityLevel('no')
        if (this.injectedFrame !== undefined) {
          Image(this.injectedFrame)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
            .backgroundColor(Palette.previewBackground)
            .accessibilityLevel('no')
        }
      }
      if (this.snapshot !== undefined) {
        Image(this.snapshot)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .backgroundColor(Palette.previewBackground)
          .accessibilityLevel('no')
      }
      Canvas(this.canvas)
        .width('100%')
        .height('100%')
        .accessibilityLevel('no')
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.sceneOverlay?.setSize(Number(newArea.width), Number(newArea.height));
        })
      if (this.badge !== '') {
        Text(this.badge)
          .fontSize(FontSize.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.onPrimary)
          .backgroundColor(Palette.scrim)
          .borderRadius(Radius.chip)
          .padding({ left: Spacing.sm, right: Spacing.sm, top: Spacing.xs, bottom: Spacing.xs })
          .position({ x: Spacing.sm, y: Spacing.sm })
          .accessibilityLevel('no')
      }
    }
    .width('100%')
    .aspectRatio(1)
    .borderRadius(Radius.card)
    .clip(true)
    .backgroundColor(Palette.previewBackground)
    .accessibilityLevel('no-hide-descendants')
  }
}
