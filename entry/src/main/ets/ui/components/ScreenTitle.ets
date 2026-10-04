import { Messages } from '../../common/Messages';
import { FontSize, Palette } from '../theme/Theme';

@Component
export struct ScreenTitle {
  @Prop text: string = '';
  @Prop elementId: string = '';
  @Prop nextFocusId: string = '';
  @Prop fontSize: number = FontSize.title;
  @Prop centered: boolean = true;

  build() {
    Text(this.text)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(Palette.textPrimary)
      .textAlign(this.centered ? TextAlign.Center : TextAlign.Start)
      .width('100%')
      .id(this.elementId)
      .accessibilityLevel('yes')
      .accessibilityText(this.text)
      .accessibilityDescription(Messages.HEADING)
      .accessibilityDefaultFocus(true)
      .accessibilityNextFocusId(this.nextFocusId)
  }
}
