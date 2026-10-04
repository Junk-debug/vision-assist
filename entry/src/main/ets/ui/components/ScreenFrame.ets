import { RoundIconButton } from './RoundIconButton';
import { ScreenTitle } from './ScreenTitle';
import { Messages } from '../../common/Messages';
import { Sizes, Spacing } from '../theme/Theme';

@Builder
function noTrailing() {
}

@Component
export struct ScreenFrame {
  @Prop title: string = '';
  @Prop titleId: string = '';
  @Prop titleNextId: string = '';
  @Prop backId: string = '';
  onBack: () => void = () => {};
  @BuilderParam content: () => void = noTrailing;
  @BuilderParam trailing: () => void = noTrailing;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: Spacing.md }) {
        Row() {
          ScreenTitle({ text: this.title, elementId: this.titleId, nextFocusId: this.titleNextId })
        }
        .width('100%')
        .constraintSize({ minHeight: Sizes.topBarButton })
        .padding({ left: Sizes.topBarSide, right: Sizes.topBarSide })
        .margin({ top: Spacing.sm })
        this.content()
      }
      .width('100%')
      .height('100%')
      Row() {
        this.trailing()
      }
      .position({ right: Spacing.page, top: Spacing.sm })
      Row() {
        RoundIconButton({
          icon: $r('sys.symbol.arrow_left'),
          label: Messages.BACK_LABEL,
          hint: Messages.BACK_HINT,
          elementId: this.backId,
          onTap: () => {
            this.onBack();
          }
        })
      }
      .position({ left: Spacing.page, top: Spacing.sm })
    }
    .width('100%')
    .height('100%')
  }
}
