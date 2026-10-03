import { BigButton } from './BigButton';
import { FontSize, Palette, Radius, Sizes, Spacing } from '../theme/Theme';

const WORD_MAX_LENGTH: number = 24;

@Component
export struct TargetSheet {
  @Prop prompt: string = '';
  @Prop targets: string[] = [];
  @Prop allowTyping: boolean = false;
  @State typed: string = '';
  onPick: (target: string) => void = (target: string) => {};

  @Builder
  row(label: string, last: boolean) {
    Column() {
      Row() {
        Text(label)
          .fontSize(FontSize.tileTitle)
          .fontColor(Palette.textPrimary)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(FontSize.body)
          .fontColor([Palette.textSecondary])
          .accessibilityLevel('no')
      }
      .width('100%')
      .constraintSize({ minHeight: Sizes.listRow })
      .padding({ top: Spacing.sm, bottom: Spacing.sm })
      if (!last) {
        Divider().color(Palette.divider).strokeWidth(1)
      }
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(label)
    .accessibilityDescription(`Start looking for ${label}`)
    .onClick(() => {
      this.onPick(label);
    })
  }

  build() {
    Column({ space: Spacing.md }) {
      Text(this.prompt)
        .fontSize(FontSize.title)
        .fontWeight(FontWeight.Medium)
        .fontColor(Palette.textPrimary)
        .width('100%')
        .padding({ top: Spacing.xl })
      if (this.allowTyping) {
        TextInput({ text: this.typed, placeholder: 'Type a word' })
          .fontSize(FontSize.tileTitle)
          .fontColor(Palette.textPrimary)
          .placeholderColor(Palette.textSecondary)
          .backgroundColor(Palette.inputFill)
          .borderRadius(Radius.input)
          .constraintSize({ minHeight: Sizes.primaryButton })
          .padding({ left: Spacing.lg, right: Spacing.lg })
          .maxLength(WORD_MAX_LENGTH)
          .enterKeyType(EnterKeyType.Go)
          .accessibilityText('Word to find')
          .accessibilityDescription('Type the word you want to find, then press Start')
          .onChange((value: string) => {
            this.typed = value;
          })
          .onSubmit(() => {
            this.onPick(this.typed);
          })
        BigButton({
          label: 'Start',
          hint: 'Start looking for the typed word',
          onTap: () => {
            this.onPick(this.typed);
          }
        })
        Text('Or choose one')
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
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: Spacing.xl, right: Spacing.xl, bottom: Spacing.lg })
    .backgroundColor(Palette.card)
    .borderRadius({ topLeft: Radius.sheet, topRight: Radius.sheet })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
