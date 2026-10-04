import { ContentRect, Detection, NormalizedBox } from '../vision/DetectionTypes';
import { TextLineResult, TextWordResult } from '../vision/text/TextTypes';
import { Palette, Sizes } from './theme/Theme';

const VISIBLE_TOP: number = 0.21875;
const VISIBLE_HEIGHT: number = 0.5625;
const LABEL_FONT: string = '14vp sans-serif';
const LABEL_HEIGHT: number = 22;
const LABEL_PADDING: number = 8;
const MARKER_RADIUS: number = 18;

export class Overlay {
  private readonly canvas: CanvasRenderingContext2D;
  private width: number = 0;
  private height: number = 0;
  private accent: string = Palette.primary;
  private mirrored: boolean = false;
  private visibleTop: number = VISIBLE_TOP;
  private visibleHeight: number = VISIBLE_HEIGHT;

  constructor(canvas: CanvasRenderingContext2D) {
    this.canvas = canvas;
  }

  setSize(width: number, height: number): void {
    this.width = width;
    this.height = height;
  }

  setStyle(accent: string, mirrored: boolean): void {
    this.accent = accent;
    this.mirrored = mirrored;
  }

  useCameraViewport(): void {
    this.visibleTop = VISIBLE_TOP;
    this.visibleHeight = VISIBLE_HEIGHT;
  }

  useFullViewport(): void {
    this.visibleTop = 0;
    this.visibleHeight = 1;
  }

  clear(): void {
    this.canvas.clearRect(0, 0, this.width, this.height);
  }

  private mapX(value: number, content: ContentRect): number {
    const x = (content.left + value * content.width) * this.width;
    return this.mirrored ? this.width - x : x;
  }

  private left(a: number, b: number, content: ContentRect): number {
    return Math.min(this.mapX(a, content), this.mapX(b, content));
  }

  private spanX(a: number, b: number, content: ContentRect): number {
    return Math.abs(this.mapX(b, content) - this.mapX(a, content));
  }

  private pill(x: number, y: number, w: number, h: number, color: string): void {
    const r = h / 2;
    this.canvas.fillStyle = color;
    this.canvas.beginPath();
    this.canvas.moveTo(x + r, y);
    this.canvas.lineTo(x + w - r, y);
    this.canvas.arc(x + w - r, y + r, r, -Math.PI / 2, Math.PI / 2);
    this.canvas.lineTo(x + r, y + h);
    this.canvas.arc(x + r, y + r, r, Math.PI / 2, Math.PI * 1.5);
    this.canvas.closePath();
    this.canvas.fill();
  }

  private mapY(value: number, content: ContentRect): number {
    return ((content.top + value * content.height - this.visibleTop) / this.visibleHeight) * this.height;
  }

  drawDetections(detections: Detection[], content: ContentRect, highlightLabel: string = '',
    colorOf: (detection: Detection) => string = (): string => ''): void {
    this.clear();
    this.canvas.font = LABEL_FONT;
    const isTarget = (detection: Detection): boolean => highlightLabel !== '' && detection.label === highlightLabel;
    const placed: NormalizedBox[] = [];
    const ordered = detections.filter((detection: Detection) => !isTarget(detection))
      .concat(detections.filter((detection: Detection) => isTarget(detection)));
    for (const detection of ordered) {
      const highlighted = isTarget(detection);
      const color = highlighted ? Palette.overlayTarget : this.accent;
      const x = this.left(detection.x1, detection.x2, content);
      const y = this.mapY(detection.y1, content);
      const boxW = this.spanX(detection.x1, detection.x2, content);
      const boxH = this.mapY(detection.y2, content) - y;
      this.canvas.lineWidth = highlighted ? Sizes.overlayTargetStroke : Sizes.overlayStroke;
      this.canvas.strokeStyle = color;
      this.canvas.strokeRect(x, y, boxW, boxH);
      const tint = colorOf(detection);
      const caption = `${tint === '' ? '' : tint + ' '}${detection.label} ${Math.round(detection.score * 100)}%`;
      const captionW = this.canvas.measureText(caption).width + LABEL_PADDING * 2;
      const captionX = Math.max(0, Math.min(x, this.width - captionW));
      const captionY = this.captionTop(captionX, captionW, [y - LABEL_HEIGHT - 2, y + 2, y + boxH + 2], placed);
      placed.push({ x1: captionX, y1: captionY, x2: captionX + captionW, y2: captionY + LABEL_HEIGHT });
      this.pill(captionX, captionY, captionW, LABEL_HEIGHT, color);
      this.canvas.fillStyle = highlighted ? Palette.overlayTargetInk : Palette.overlayInk;
      this.canvas.fillText(caption, captionX + LABEL_PADDING, captionY + LABEL_HEIGHT - 6);
    }
  }

  private captionTop(x: number, w: number, candidates: number[], placed: NormalizedBox[]): number {
    const clamped = candidates.map((top: number) => Math.max(0, Math.min(top, this.height - LABEL_HEIGHT)));
    const free = clamped.find((top: number) => placed.every((other: NormalizedBox) =>
      x + w <= other.x1 || x >= other.x2 || top + LABEL_HEIGHT <= other.y1 || top >= other.y2));
    return free !== undefined ? free : clamped[0];
  }

  drawTextLines(lines: TextLineResult[], content: ContentRect): void {
    this.clear();
    this.canvas.lineWidth = Sizes.overlayStroke;
    this.canvas.strokeStyle = this.accent;
    for (const line of lines) {
      const x = this.left(line.x1, line.x2, content);
      const y = this.mapY(line.y1, content);
      this.canvas.strokeRect(x, y, this.spanX(line.x1, line.x2, content), this.mapY(line.y2, content) - y);
    }
  }

  drawWordMatch(words: TextWordResult[], match: NormalizedBox | undefined, content: ContentRect): void {
    this.clear();
    this.canvas.lineWidth = 2;
    this.canvas.strokeStyle = this.accent;
    for (const word of words) {
      this.strokeBox(word, content);
    }
    if (match !== undefined) {
      this.canvas.lineWidth = Sizes.overlayTargetStroke;
      this.canvas.strokeStyle = Palette.overlayTarget;
      this.strokeBox(match, content);
    }
  }

  private strokeBox(box: NormalizedBox, content: ContentRect): void {
    const x = this.left(box.x1, box.x2, content);
    const y = this.mapY(box.y1, content);
    this.canvas.strokeRect(x, y, this.spanX(box.x1, box.x2, content), this.mapY(box.y2, content) - y);
  }

  drawRegion(box: NormalizedBox, content: ContentRect, color: string): void {
    this.clear();
    this.canvas.lineWidth = 4;
    this.canvas.strokeStyle = color;
    this.strokeBox(box, content);
  }

  drawCenterMarker(content: ContentRect, color: string): void {
    this.clear();
    const x = this.mapX(0.5, content);
    const y = this.mapY(0.5, content);
    this.canvas.lineWidth = 4;
    this.canvas.strokeStyle = color;
    this.canvas.strokeRect(x - MARKER_RADIUS, y - MARKER_RADIUS, MARKER_RADIUS * 2, MARKER_RADIUS * 2);
  }
}
