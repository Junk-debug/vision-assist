export class Routes {
  static readonly FEATURE: string = 'feature';
  static readonly FULL_TEXT: string = 'fulltext';
}

export interface FullTextParams {
  text: string;
  spoken: boolean;
}
