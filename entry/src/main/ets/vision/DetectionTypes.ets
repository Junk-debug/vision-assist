export interface NormalizedBox {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

export interface Detection extends NormalizedBox {
  classId: number;
  label: string;
  score: number;
}

export interface DetectionResult {
  detections: Detection[];
  preprocessMs: number;
  inferenceMs: number;
  postprocessMs: number;
}

export interface ContentRect {
  left: number;
  top: number;
  width: number;
  height: number;
}
