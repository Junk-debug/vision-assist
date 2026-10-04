import { FontSize, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

@Component
export struct StatusCard {
  @Prop status: string = '';
  @Prop detail: string = '';
  @Prop elementId: string = '';
  @Prop nextFocusId: string = '';

  build() {
    Column({ space: Spacing.xs }) {
      Text(this.status)
        .fontSize(FontSize.status)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.textPrimary)
        .maxLines(Sizes.statusMaxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .accessibilityText(this.status)
        .accessibilityNextFocusId(this.nextFocusId)
        .id(this.elementId)
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
    .constraintSize({ minHeight: Sizes.statusMinHeight })
    .justifyContent(FlexAlign.Start)
    .padding(Spacing.lg)
    .borderRadius(Radius.card)
    .backgroundColor(Palette.card)
  }
}
