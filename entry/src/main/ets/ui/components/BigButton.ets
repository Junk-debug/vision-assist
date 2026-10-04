import { FontSize, Motion, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

export enum ButtonTone {
  PRIMARY,
  STOP,
  SECONDARY
}

@Component
export struct BigButton {
  @Prop label: string = '';
  @Prop hint: string = '';
  @Prop tone: ButtonTone = ButtonTone.PRIMARY;
  @Prop disabled: boolean = false;
  @Prop elementId: string = '';
  @Prop nextFocusId: string = '';
  @State pressed: boolean = false;
  onTap: () => void = () => {};

  private fillColor(): string {
    if (this.disabled) {
      return Palette.disabled;
    }
    if (this.tone === ButtonTone.STOP) {
      return this.pressed ? Palette.stopPressed : Palette.stop;
    }
    if (this.tone === ButtonTone.SECONDARY) {
      return this.pressed ? Palette.cardPressed : Palette.card;
    }
    return this.pressed ? Palette.primaryPressed : Palette.primary;
  }

  private inkColor(): string {
    return this.tone === ButtonTone.SECONDARY && !this.disabled ? Palette.primary : Palette.onPrimary;
  }

  build() {
    Row() {
      Text(this.label)
        .fontSize(FontSize.button)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.inkColor())
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: Sizes.primaryButton })
    .padding({ left: Spacing.xl, right: Spacing.xl, top: Spacing.md, bottom: Spacing.md })
    .borderRadius(Radius.button)
    .backgroundColor(this.fillColor())
    .border({ width: this.tone === ButtonTone.SECONDARY && !this.disabled ? Sizes.secondaryBorder : 0, color: Palette.primary })
    .scale({ x: this.pressed ? Sizes.pressedScale : 1, y: this.pressed ? Sizes.pressedScale : 1 })
    .animation({ duration: Motion.pressMs })
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.label)
    .accessibilityDescription(this.hint)
    .accessibilityNextFocusId(this.nextFocusId)
    .id(this.elementId)
    .enabled(!this.disabled)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
