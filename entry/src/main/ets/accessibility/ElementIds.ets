export class ElementIds {
  static readonly HOME_TITLE: string = 'home-title';
  static readonly FEATURE_TITLE: string = 'feature-title';
  static readonly FEATURE_STATUS: string = 'feature-status';
  static readonly FEATURE_PRIMARY: string = 'feature-primary';
  static readonly FEATURE_FULL_TEXT: string = 'feature-full-text';
  static readonly FEATURE_PHOTO: string = 'feature-photo';
  static readonly FEATURE_LIVE: string = 'feature-live';
  static readonly FEATURE_TARGET: string = 'feature-target';
  static readonly FEATURE_SWITCH: string = 'feature-switch';
  static readonly FEATURE_BACK: string = 'feature-back';
  static readonly SHEET_TITLE: string = 'sheet-title';
  static readonly SHEET_CANCEL: string = 'sheet-cancel';
  static readonly FULL_TEXT_TITLE: string = 'full-text-title';
  static readonly FULL_TEXT_FIRST_LINE: string = 'full-text-line-0';
  static readonly FULL_TEXT_READ_AGAIN: string = 'full-text-read-again';
  static readonly FULL_TEXT_BACK: string = 'full-text-back';

  static tile(featureId: string): string {
    return `tile-${featureId}`;
  }

  static fullTextLine(index: number): string {
    return `full-text-line-${index}`;
  }
}
