import { RoundIconButton } from './RoundIconButton';
import { FontSize, Palette, Sizes, Spacing } from '../theme/Theme';

@Component
export struct TopBar {
  @Prop title: string = '';
  @Prop showSwitch: boolean = false;
  @Prop switchLabel: string = '';
  onBack: () => void = () => {};
  onSwitch: () => void = () => {};

  build() {
    Row({ space: Spacing.sm }) {
      RoundIconButton({
        icon: $r('sys.symbol.arrow_left'),
        label: 'Back',
        hint: 'Return to the list of features',
        onTap: () => {
          this.onBack();
        }
      })
      Text(this.title)
        .fontSize(FontSize.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.textPrimary)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .accessibilityText(this.title)
      if (this.showSwitch) {
        RoundIconButton({
          icon: $r('sys.symbol.switch_camera'),
          label: this.switchLabel,
          hint: 'Use the other camera',
          onTap: () => {
            this.onSwitch();
          }
        })
      } else {
        Blank()
          .width(Sizes.topBarButton)
          .accessibilityLevel('no')
      }
    }
    .width('100%')
    .padding({ top: Spacing.sm, bottom: Spacing.sm })
  }
}
