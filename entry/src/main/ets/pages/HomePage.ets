import { FEATURE_CATALOG, FeatureInfo } from '../ui/FeatureCatalog';
import { FeatureTile } from '../ui/components/FeatureTile';
import { FontSize, Palette, Sizes, Spacing, TileLayout } from '../ui/theme/Theme';

const APP_NAME: string = 'Vision Assist';
const TAGLINE: string = 'Offline help for what\'s around you';

class TileRow {
  readonly key: string;
  readonly tiles: FeatureInfo[];
  readonly first: number;

  constructor(tiles: FeatureInfo[], first: number) {
    this.tiles = tiles;
    this.first = first;
    this.key = tiles.map((info: FeatureInfo) => info.id).join('+');
  }
}

function layoutRows(items: FeatureInfo[]): TileRow[] {
  const rows: TileRow[] = [];
  let index = 0;
  if (TileLayout.firstTileWide && items.length > 0) {
    rows.push(new TileRow([items[0]], 0));
    index = 1;
  }
  while (index < items.length) {
    const remaining = items.length - index;
    const count = remaining < TileLayout.columns && TileLayout.lastOddTileWide ? 1 :
      Math.min(TileLayout.columns, remaining);
    rows.push(new TileRow(items.slice(index, index + count), index));
    index += count;
  }
  return rows;
}

@Component
export struct HomePage {
  onOpen: (id: string) => void = (id: string) => {};
  @State contentHeights: number[] = FEATURE_CATALOG.map((info: FeatureInfo) => 0);
  private rows: TileRow[] = layoutRows(FEATURE_CATALOG);

  private rowContentHeight(row: TileRow): number {
    return Math.max(...this.contentHeights.slice(row.first, row.first + row.tiles.length));
  }

  private reportHeight(index: number, height: number): void {
    if (this.contentHeights[index] !== height) {
      this.contentHeights[index] = height;
    }
  }

  build() {
    Scroll() {
      Column({ space: Spacing.md }) {
        Column({ space: Spacing.xs }) {
          Text(APP_NAME)
            .fontSize(FontSize.display)
            .fontWeight(FontWeight.Medium)
            .fontColor(Palette.textPrimary)
            .accessibilityText(APP_NAME)
          Text(TAGLINE)
            .fontSize(FontSize.body)
            .fontColor(Palette.textSecondary)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: Spacing.xxl, bottom: Spacing.lg })

        ForEach(this.rows, (row: TileRow) => {
          Row({ space: Spacing.md }) {
            ForEach(row.tiles, (info: FeatureInfo, position: number) => {
              Column() {
                FeatureTile({
                  info: info,
                  wide: row.tiles.length === 1,
                  contentMinHeight: this.rowContentHeight(row),
                  onContentHeight: (height: number) => {
                    this.reportHeight(row.first + position, height);
                  },
                  onOpen: this.onOpen
                })
              }
              .layoutWeight(1)
            }, (info: FeatureInfo) => info.id)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (row: TileRow) => row.key)
      }
      .width('100%')
      .constraintSize({ maxWidth: Sizes.maxContentWidth })
      .padding({ left: Spacing.page, right: Spacing.page, bottom: Spacing.xxl })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(Palette.page)
  }
}
