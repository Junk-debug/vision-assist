import { FontSize, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

@Component
export struct StatusCard {
  @Prop status: string = '';
  @Prop detail: string = '';

  build() {
    Column({ space: Spacing.xs }) {
      Scroll() {
        Text(this.status)
          .fontSize(FontSize.status)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.textPrimary)
          .width('100%')
          .accessibilityText(this.status)
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Auto)
      if (this.detail !== '') {
        Text(this.detail)
          .fontSize(FontSize.caption)
          .fontColor(Palette.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .accessibilityLevel('no')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ minHeight: Sizes.listRow })
    .padding(Spacing.lg)
    .borderRadius(Radius.card)
    .backgroundColor(Palette.card)
  }
}
