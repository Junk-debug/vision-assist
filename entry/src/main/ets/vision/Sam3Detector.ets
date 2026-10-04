import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { Detection, DetectionResult } from './DetectionTypes';
import { describeError, log } from '../common/Logger';

const KEY_FILE: string = 'sam3.json';
const ENDPOINT: string = 'https://serverless.roboflow.com/sam3/concept_segment';
const JPEG_QUALITY: number = 80;
const TIMEOUT_MS: number = 4000;

interface KeyFile {
  roboflowApiKey?: string;
}

interface Sam3Image {
  type: string;
  value: string;
}

interface Sam3Prompt {
  type: string;
  text: string;
}

interface Sam3Request {
  image: Sam3Image;
  prompts: Sam3Prompt[];
  output_prob_thresh: number;
  format: string;
}

interface Sam3Prediction {
  masks?: number[][][];
  confidence?: number;
}

interface Sam3PromptResult {
  predictions?: Sam3Prediction[];
}

interface Sam3Response {
  prompt_results?: Sam3PromptResult[];
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

// Experimental cloud detector: SAM 3 text-prompt segmentation on Roboflow Serverless.
// Find uses it through FindEngine when the phone is online and rawfile/sam3.json holds a key.
// detect() throws when the request fails so the caller can fall back to the on-device model.
export class Sam3Detector {
  private apiKey: string = '';

  async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const bytes = await context.resourceManager.getRawFileContent(KEY_FILE);
      const parsed = JSON.parse(new util.TextDecoder('utf-8').decodeToString(bytes)) as KeyFile;
      this.apiKey = (parsed.roboflowApiKey ?? '').trim();
      log(`sam3 key ${this.apiKey === '' ? 'empty' : 'loaded'}`);
    } catch (error) {
      log(`sam3 key file missing ${describeError(error)}`);
    }
  }

  isReady(): boolean {
    return this.apiKey !== '';
  }

  async detect(frame: image.PixelMap, label: string, scoreThreshold: number): Promise<DetectionResult> {
    const t0 = Date.now();
    const info = await frame.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    const packer = image.createImagePacker();
    const jpeg = await packer.packToData(frame, { format: 'image/jpeg', quality: JPEG_QUALITY });
    packer.release();
    const payload: Sam3Request = {
      image: { type: 'base64', value: new util.Base64Helper().encodeToStringSync(new Uint8Array(jpeg)) },
      prompts: [{ type: 'text', text: label.toLowerCase() }],
      output_prob_thresh: scoreThreshold,
      format: 'polygon'
    };
    const body = JSON.stringify(payload);
    const t1 = Date.now();
    const request = http.createHttp();
    let text = '';
    let failure = '';
    try {
      const response = await request.request(ENDPOINT, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.apiKey}` },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS
      });
      text = response.result as string;
      if (response.responseCode !== 200) {
        failure = `http ${response.responseCode} ${text.substring(0, 200)}`;
      }
    } catch (error) {
      failure = describeError(error);
    } finally {
      request.destroy();
    }
    if (failure !== '') {
      log(`sam3 request failed ${failure}`);
      throw new Error(failure);
    }
    const t2 = Date.now();
    const detections = this.parse(text, label, width, height);
    return { detections: detections, preprocessMs: t1 - t0, inferenceMs: t2 - t1, postprocessMs: Date.now() - t2 };
  }

  private parse(text: string, label: string, width: number, height: number): Detection[] {
    const parsed = JSON.parse(text) as Sam3Response;
    const detections: Detection[] = [];
    for (const result of parsed.prompt_results ?? []) {
      for (const prediction of result.predictions ?? []) {
        let minX = Number.MAX_VALUE;
        let minY = Number.MAX_VALUE;
        let maxX = -1;
        let maxY = -1;
        for (const polygon of prediction.masks ?? []) {
          for (const point of polygon) {
            minX = Math.min(minX, point[0]);
            minY = Math.min(minY, point[1]);
            maxX = Math.max(maxX, point[0]);
            maxY = Math.max(maxY, point[1]);
          }
        }
        if (maxX < 0) {
          continue;
        }
        detections.push({
          classId: -1,
          label: label,
          score: prediction.confidence ?? 0,
          x1: clamp01(minX / width),
          y1: clamp01(minY / height),
          x2: clamp01(maxX / width),
          y2: clamp01(maxY / height)
        });
      }
    }
    detections.sort((a: Detection, b: Detection) => b.score - a.score);
    return detections;
  }
}
