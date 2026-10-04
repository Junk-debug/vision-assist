import { ElementIds } from '../../accessibility/ElementIds';
import { haptics } from '../../haptics/Haptics';
import { FeatureInfo } from '../FeatureCatalog';
import { FontSize, IconSize, Motion, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

@Component
export struct FeatureTile {
  info?: FeatureInfo;
  wide: boolean = false;
  @Prop contentMinHeight: number = 0;
  onContentHeight: (height: number) => void = (height: number) => {};
  @State pressed: boolean = false;
  onOpen: (id: string) => void = (id: string) => {};

  @Builder
  iconChip(info: FeatureInfo) {
    Stack() {
      SymbolGlyph(info.icon)
        .fontSize(IconSize.tile)
        .fontColor([info.accent])
    }
    .width(Sizes.iconChip)
    .height(Sizes.iconChip)
    .borderRadius(Radius.chip)
    .backgroundColor(info.tint)
    .accessibilityLevel('no')
  }

  @Builder
  texts(info: FeatureInfo) {
    Column({ space: Spacing.xs }) {
      Text(info.name)
        .fontSize(FontSize.tileTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.textPrimary)
      Text(info.description)
        .fontSize(FontSize.tileBody)
        .fontColor(Palette.textSecondary)
    }
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.info !== undefined) {
      Column() {
        if (this.wide) {
          Row({ space: Spacing.lg }) {
            this.iconChip(this.info)
            Column() {
              this.texts(this.info)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.onContentHeight(Number(newArea.height));
          })
        } else {
          Column({ space: Spacing.md }) {
            this.iconChip(this.info)
            this.texts(this.info)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.onContentHeight(Number(newArea.height));
          })
        }
      }
      .width('100%')
      .constraintSize({ minHeight: this.contentMinHeight + Spacing.lg * 2 })
      .justifyContent(this.wide ? FlexAlign.Center : FlexAlign.Start)
      .padding(Spacing.lg)
      .borderRadius(Radius.card)
      .backgroundColor(this.pressed ? Palette.cardPressed : Palette.card)
      .scale({ x: this.pressed ? Sizes.pressedScale : 1, y: this.pressed ? Sizes.pressedScale : 1 })
      .animation({ duration: Motion.pressMs })
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(this.info.name)
      .accessibilityDescription(this.info.description)
      .id(ElementIds.tile(this.info.id))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      .onClick(() => {
        if (this.info !== undefined) {
          haptics.tap();
          this.onOpen(this.info.id);
        }
      })
    }
  }
}
