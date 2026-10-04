import { BigButton, ButtonTone } from './BigButton';
import { ScreenTitle } from './ScreenTitle';
import { ElementIds } from '../../accessibility/ElementIds';
import { Messages } from '../../common/Messages';
import { FontSize, IconSize, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

const WORD_MAX_LENGTH: number = 24;

@Component
export struct TargetSheet {
  @Prop prompt: string = '';
  @Prop targets: string[] = [];
  @Prop allowTyping: boolean = false;
  @State typed: string = '';
  onPick: (target: string) => void = (target: string) => {};
  onCancel: () => void = () => {};

  @Builder
  row(label: string, last: boolean) {
    Column() {
      Row() {
        Text(label)
          .fontSize(FontSize.tileTitle)
          .fontColor(Palette.textPrimary)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(IconSize.chevron)
          .fontColor([Palette.textSecondary])
          .accessibilityLevel('no')
      }
      .width('100%')
      .constraintSize({ minHeight: Sizes.listRow })
      .padding({ top: Spacing.sm, bottom: Spacing.sm })
      if (!last) {
        Divider().color(Palette.divider).strokeWidth(1).accessibilityLevel('no')
      }
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .accessibilityDescription(Messages.pickTargetHint(label))
    .onClick(() => {
      this.onPick(label);
    })
  }

  build() {
    Column({ space: Spacing.md }) {
      ScreenTitle({ text: this.prompt, elementId: ElementIds.SHEET_TITLE, centered: false })
        .padding({ top: Spacing.sm })
      if (this.allowTyping) {
        TextInput({ text: this.typed, placeholder: Messages.TYPE_A_WORD })
          .fontSize(FontSize.tileTitle)
          .fontColor(Palette.textPrimary)
          .placeholderColor(Palette.textSecondary)
          .placeholderFont({ size: FontSize.tileTitle })
          .backgroundColor(Palette.inputFill)
          .borderRadius(Radius.input)
          .constraintSize({ minHeight: Sizes.primaryButton })
          .padding({ left: Spacing.lg, right: Spacing.lg })
          .maxLength(WORD_MAX_LENGTH)
          .enterKeyType(EnterKeyType.Go)
          .accessibilityText(Messages.WORD_FIELD_LABEL)
          .accessibilityDescription(Messages.WORD_FIELD_HINT)
          .onChange((value: string) => {
            this.typed = value;
          })
          .onSubmit(() => {
            this.onPick(this.typed);
          })
        BigButton({
          label: Messages.START,
          hint: Messages.START_TYPED_HINT,
          onTap: () => {
            this.onPick(this.typed);
          }
        })
        Text(Messages.OR_CHOOSE_ONE)
          .fontSize(FontSize.body)
          .fontColor(Palette.textSecondary)
          .width('100%')
          .padding({ top: Spacing.sm })
      }
      List() {
        ForEach(this.targets, (label: string, index: number) => {
          ListItem() {
            this.row(label, index === this.targets.length - 1)
          }
        }, (label: string) => label)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      BigButton({
        label: Messages.CANCEL,
        hint: Messages.CANCEL_PICKER_HINT,
        tone: ButtonTone.SECONDARY,
        elementId: ElementIds.SHEET_CANCEL,
        onTap: () => {
          this.onCancel();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Spacing.xl, right: Spacing.xl, top: Spacing.md, bottom: Spacing.lg })
    .backgroundColor(Palette.card)
  }
}
