import { ElementIds } from '../accessibility/ElementIds';
import { appServices } from '../app/AppServices';
import { FullTextParams } from '../app/Routes';
import { Messages } from '../common/Messages';
import { Priority } from '../speech/Narrator';
import { ReadingListener } from '../speech/ReadAloud';
import { BigButton, ButtonTone } from '../ui/components/BigButton';
import { ScreenFrame } from '../ui/components/ScreenFrame';
import { FontSize, Palette, Radius, Sizes, Spacing } from '../ui/theme/Theme';
import { splitLines } from '../vision/text/TextSummary';

@Component
export struct FullTextPage {
  params?: FullTextParams;
  private lines: string[] = [];
  private text: string = '';
  private pathStack?: NavPathStack;
  @State reading: boolean = false;
  private readingListener: ReadingListener = (index: number) => {
    this.reading = index >= 0;
  };

  aboutToAppear(): void {
    this.text = this.params !== undefined ? this.params.text : '';
    this.lines = splitLines(this.text);
    this.reading = appServices.narrator.isReading();
    appServices.narrator.reader.addListener(this.readingListener);
    if (this.params === undefined || !this.params.spoken) {
      appServices.narrator.announceScreen(Messages.FULL_TEXT_TITLE);
    }
  }

  aboutToDisappear(): void {
    appServices.narrator.reader.removeListener(this.readingListener);
    appServices.narrator.stopSpeaking();
  }

  @Builder
  body() {
    Column({ space: Spacing.md }) {
      Scroll() {
        Column({ space: Spacing.md }) {
          ForEach(this.lines, (line: string, index: number) => {
            Text(line)
              .fontSize(FontSize.fullText)
              .lineHeight(Sizes.fullTextLineHeight)
              .fontColor(Palette.textPrimary)
              .copyOption(CopyOptions.LocalDevice)
              .width('100%')
              .id(ElementIds.fullTextLine(index))
              .accessibilityLevel('yes')
              .accessibilityText(line)
          }, (line: string, index: number) => `${index}:${line}`)
        }
        .width('100%')
        .padding(Spacing.lg)
        .borderRadius(Radius.card)
        .backgroundColor(Palette.card)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      BigButton({
        label: this.reading ? Messages.STOP_READING : Messages.READ_AGAIN,
        hint: this.reading ? Messages.STOP_READING_HINT : Messages.READ_AGAIN_HINT,
        tone: this.reading ? ButtonTone.STOP : ButtonTone.PRIMARY,
        elementId: ElementIds.FULL_TEXT_READ_AGAIN,
        nextFocusId: ElementIds.FULL_TEXT_BACK,
        onTap: () => {
          if (this.reading) {
            appServices.narrator.stopReading();
            appServices.narrator.announce(Messages.READING_STOPPED, Priority.URGENT);
          } else {
            appServices.narrator.readText(this.text);
          }
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: Spacing.page, right: Spacing.page, bottom: Spacing.lg })
  }

  build() {
    NavDestination() {
      ScreenFrame({
        title: Messages.FULL_TEXT_TITLE,
        titleId: ElementIds.FULL_TEXT_TITLE,
        titleNextId: this.lines.length > 0 ? ElementIds.FULL_TEXT_FIRST_LINE : ElementIds.FULL_TEXT_READ_AGAIN,
        backId: ElementIds.FULL_TEXT_BACK,
        onBack: () => {
          this.pathStack?.pop();
        },
        content: () => {
          this.body();
        }
      })
    }
    .hideTitleBar(true)
    .backgroundColor(Palette.page)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
