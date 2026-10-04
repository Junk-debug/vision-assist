import { haptics } from '../../haptics/Haptics';
import { IconSize, Motion, Palette, Sizes } from '../theme/Theme';

@Component
export struct RoundIconButton {
  icon: Resource = $r('sys.symbol.chevron_left');
  @Prop label: string = '';
  @Prop hint: string = '';
  @Prop elementId: string = '';
  @Prop nextFocusId: string = '';
  @State pressed: boolean = false;
  onTap: () => void = () => {};

  build() {
    Stack() {
      SymbolGlyph(this.icon)
        .fontSize(IconSize.topBar)
        .fontColor([Palette.textPrimary])
        .accessibilityLevel('no')
    }
    .width(Sizes.topBarButton)
    .height(Sizes.topBarButton)
    .borderRadius(Sizes.topBarButton / 2)
    .backgroundColor(this.pressed ? Palette.cardPressed : Palette.card)
    .scale({ x: this.pressed ? Sizes.pressedScale : 1, y: this.pressed ? Sizes.pressedScale : 1 })
    .animation({ duration: Motion.pressMs })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.label)
    .accessibilityDescription(this.hint)
    .accessibilityNextFocusId(this.nextFocusId)
    .id(this.elementId)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      haptics.tap();
      this.onTap();
    })
  }
}
