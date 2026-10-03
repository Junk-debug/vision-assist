import { ContentRect, Detection } from '../vision/DetectionTypes';
import { TextLineResult } from '../vision/text/TextTypes';

const VISIBLE_TOP: number = 0.21875;
const VISIBLE_HEIGHT: number = 0.5625;
const BOX_COLOR: string = '#FFD400';
const TARGET_COLOR: string = '#00E676';
const TEXT_BOX_COLOR: string = '#00E5FF';
const LABEL_TEXT_COLOR: string = '#000000';
const LABEL_FONT: string = '14vp sans-serif';
const LABEL_HEIGHT: number = 20;
const MARKER_RADIUS: number = 18;

export class Overlay {
  private readonly canvas: CanvasRenderingContext2D;
  private width: number = 0;
  private height: number = 0;

  constructor(canvas: CanvasRenderingContext2D) {
    this.canvas = canvas;
  }

  setSize(width: number, height: number): void {
    this.width = width;
    this.height = height;
  }

  clear(): void {
    this.canvas.clearRect(0, 0, this.width, this.height);
  }

  private mapX(value: number, content: ContentRect): number {
    return (content.left + value * content.width) * this.width;
  }

  private mapY(value: number, content: ContentRect): number {
    return ((content.top + value * content.height - VISIBLE_TOP) / VISIBLE_HEIGHT) * this.height;
  }

  drawDetections(detections: Detection[], content: ContentRect, highlightLabel: string = ''): void {
    this.clear();
    this.canvas.font = LABEL_FONT;
    for (const detection of detections) {
      const highlighted = highlightLabel !== '' && detection.label === highlightLabel;
      const color = highlighted ? TARGET_COLOR : BOX_COLOR;
      const x = this.mapX(detection.x1, content);
      const y = this.mapY(detection.y1, content);
      const boxW = this.mapX(detection.x2, content) - x;
      const boxH = this.mapY(detection.y2, content) - y;
      this.canvas.lineWidth = highlighted ? 6 : 3;
      this.canvas.strokeStyle = color;
      this.canvas.strokeRect(x, y, boxW, boxH);
      const caption = `${detection.label} ${Math.round(detection.score * 100)}%`;
      const captionW = this.canvas.measureText(caption).width + 8;
      this.canvas.fillStyle = color;
      this.canvas.fillRect(x, Math.max(0, y - LABEL_HEIGHT), captionW, LABEL_HEIGHT);
      this.canvas.fillStyle = LABEL_TEXT_COLOR;
      this.canvas.fillText(caption, x + 4, Math.max(LABEL_HEIGHT - 5, y - 5));
    }
  }

  drawTextLines(lines: TextLineResult[], content: ContentRect): void {
    this.clear();
    this.canvas.lineWidth = 3;
    this.canvas.strokeStyle = TEXT_BOX_COLOR;
    for (const line of lines) {
      const x = this.mapX(line.x1, content);
      const y = this.mapY(line.y1, content);
      this.canvas.strokeRect(x, y, this.mapX(line.x2, content) - x, this.mapY(line.y2, content) - y);
    }
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
