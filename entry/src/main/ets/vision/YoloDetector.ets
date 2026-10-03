import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Detection, DetectionResult } from './DetectionTypes';
import { log } from '../common/Logger';

const MODEL_FILE: string = 'yolov8s_oiv7_640_sub.ms';
const CLASSES_FILE: string = 'classes.json';
const PAD_VALUE: number = 114 / 255;
const NMS_IOU: number = 0.45;
const MAX_DETECTIONS: number = 20;
const BOX_CHANNELS: number = 4;
const CPU_THREADS: number = 4;

function overlap(a: Detection, b: Detection): number {
  const interW = Math.max(0, Math.min(a.x2, b.x2) - Math.max(a.x1, b.x1));
  const interH = Math.max(0, Math.min(a.y2, b.y2) - Math.max(a.y1, b.y1));
  const inter = interW * interH;
  const union = (a.x2 - a.x1) * (a.y2 - a.y1) + (b.x2 - b.x1) * (b.y2 - b.y1) - inter;
  return union <= 0 ? 0 : inter / union;
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

export class YoloDetector {
  private model?: mindSporeLite.Model;
  private labels: string[] = [];
  private inputSize: number = 640;
  private channelsFirst: boolean = true;
  private tensor: Float32Array = new Float32Array(0);
  private outputLogged: boolean = false;

  async load(context: common.UIAbilityContext): Promise<void> {
    const start = Date.now();
    const modelBytes = await context.resourceManager.getRawFileContent(MODEL_FILE);
    const modelBuffer = modelBytes.buffer.slice(modelBytes.byteOffset, modelBytes.byteOffset + modelBytes.byteLength) as ArrayBuffer;
    const cpu: mindSporeLite.CpuDevice = { threadNum: CPU_THREADS };
    const modelContext: mindSporeLite.Context = { target: ['cpu'], cpu: cpu };
    this.model = await mindSporeLite.loadModelFromBuffer(modelBuffer, modelContext);
    const input = this.model.getInputs()[0];
    this.channelsFirst = input.shape[1] === 3;
    this.inputSize = this.channelsFirst ? input.shape[2] : input.shape[1];
    this.tensor = new Float32Array(3 * this.inputSize * this.inputSize);
    const classBytes = await context.resourceManager.getRawFileContent(CLASSES_FILE);
    this.labels = JSON.parse(new util.TextDecoder('utf-8').decodeToString(classBytes)) as string[];
    log(`model ${MODEL_FILE} loaded in ${Date.now() - start} ms, input ${JSON.stringify(input.shape)}, ${this.labels.length} labels`);
  }

  isReady(): boolean {
    return this.model !== undefined;
  }

  private labelFor(classId: number): string {
    return classId < this.labels.length ? this.labels[classId] : `object ${classId}`;
  }

  async detect(frame: image.PixelMap, scoreThreshold: number): Promise<DetectionResult> {
    const model = this.model as mindSporeLite.Model;
    const t0 = Date.now();
    const info = await frame.getImageInfo();
    const srcW = info.size.width;
    const srcH = info.size.height;
    const bytes = new ArrayBuffer(frame.getPixelBytesNumber());
    await frame.readPixelsToBuffer(bytes);
    const pixels = new Uint8Array(bytes);
    const rowBytes = pixels.length / srcH;
    const size = this.inputSize;
    const scale = Math.min(size / srcW, size / srcH);
    const newW = Math.round(srcW * scale);
    const newH = Math.round(srcH * scale);
    const offX = Math.floor((size - newW) / 2);
    const offY = Math.floor((size - newH) / 2);
    const plane = size * size;
    const tensor = this.tensor;
    tensor.fill(PAD_VALUE);
    const srcColumn = new Int32Array(newW);
    for (let x = 0; x < newW; x++) {
      srcColumn[x] = Math.min(srcW - 1, Math.floor(x / scale)) * 4;
    }
    for (let y = 0; y < newH; y++) {
      const rowStart = Math.min(srcH - 1, Math.floor(y / scale)) * rowBytes;
      const dstRow = (y + offY) * size + offX;
      if (this.channelsFirst) {
        for (let x = 0; x < newW; x++) {
          const o = rowStart + srcColumn[x];
          const i = dstRow + x;
          tensor[i] = pixels[o] / 255;
          tensor[plane + i] = pixels[o + 1] / 255;
          tensor[2 * plane + i] = pixels[o + 2] / 255;
        }
      } else {
        for (let x = 0; x < newW; x++) {
          const o = rowStart + srcColumn[x];
          const i = (dstRow + x) * 3;
          tensor[i] = pixels[o] / 255;
          tensor[i + 1] = pixels[o + 1] / 255;
          tensor[i + 2] = pixels[o + 2] / 255;
        }
      }
    }
    const input = model.getInputs()[0];
    input.setData(tensor.buffer as ArrayBuffer);
    const t1 = Date.now();
    const outputs = await model.predict([input]);
    const t2 = Date.now();
    const output = outputs[0];
    if (!this.outputLogged) {
      this.outputLogged = true;
      log(`model output shape ${JSON.stringify(output.shape)}`);
    }
    const data = new Float32Array(output.getData());
    const anchors = output.shape[2];
    const classCount = output.shape[1] - BOX_CHANNELS;
    const bestScore = new Float32Array(anchors).fill(scoreThreshold);
    const bestClass = new Int16Array(anchors).fill(-1);
    for (let c = 0; c < classCount; c++) {
      const row = (BOX_CHANNELS + c) * anchors;
      for (let i = 0; i < anchors; i++) {
        const value = data[row + i];
        if (value > bestScore[i]) {
          bestScore[i] = value;
          bestClass[i] = c;
        }
      }
    }
    const candidates: Detection[] = [];
    for (let i = 0; i < anchors; i++) {
      const classId = bestClass[i];
      if (classId < 0) {
        continue;
      }
      const cx = data[i];
      const cy = data[anchors + i];
      const w = data[2 * anchors + i];
      const h = data[3 * anchors + i];
      candidates.push({
        classId: classId,
        label: this.labelFor(classId),
        score: bestScore[i],
        x1: clamp01((cx - w / 2 - offX) / newW),
        y1: clamp01((cy - h / 2 - offY) / newH),
        x2: clamp01((cx + w / 2 - offX) / newW),
        y2: clamp01((cy + h / 2 - offY) / newH)
      });
    }
    candidates.sort((a: Detection, b: Detection) => b.score - a.score);
    const kept: Detection[] = [];
    for (const candidate of candidates) {
      let suppressed = false;
      for (const other of kept) {
        if (other.classId === candidate.classId && overlap(other, candidate) > NMS_IOU) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        kept.push(candidate);
        if (kept.length >= MAX_DETECTIONS) {
          break;
        }
      }
    }
    const t3 = Date.now();
    return { detections: kept, preprocessMs: t1 - t0, inferenceMs: t2 - t1, postprocessMs: t3 - t2 };
  }
}
