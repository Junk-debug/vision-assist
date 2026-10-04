# Architecture and implementation

Vision Assist is a native HarmonyOS app (ArkTS, ArkUI, API 20 minimum, built against API 24) that helps blind and low-vision people with the phone camera. Every recognition step runs on the phone. The app has no network permission.

This document describes the code as committed. Statements that have only been checked on the DevEco emulator are marked as such; see "Known limits" for what still needs a real phone.

## Components

```
                         +---------------------------+
                         |  pages/Index.ets          |  navigation
                         |  pages/HomePage.ets       |  feature tiles (no camera)
                         |  pages/FeaturePage.ets    |  camera, status, action button, picker
                         +-------------+-------------+
                                       |
                         creates one Feature via FeatureFactory
                                       |
     +------------------+--------------+--------------+------------------+-----------------+
     |                  |              |              |                  |                 |
 Describe            Find           Find word       Read             Light             Color
 (continuous)     (continuous)    (continuous)    (one shot)       (one shot)        (one shot)
     |                  |              |              |                  |                 |
     |                  +----- GuidanceCoach ---------+                  |                 |
     |                  |      (pulse + speech)       |                  |                 |
     v                  v                             v                  v                 v
 SceneTracker     FindGuidance                  WordMatcher         sensor +          ColorNamer
                                                                    camera luma
     \__________________|_____________________________|__________________|_________________/
                                       |
                           FeatureServices (app/AppServices.ets, shared by all screens)
     +-------------+---------------+----------------+-----------------+----------------+
     | CameraSource| YoloDetector  | TextReader     | Narrator        | Overlay        |
     | Camera Kit  | MindSpore Lite| System OCR ->  | Accessibility / | Canvas boxes,  |
     | + Image Kit | YOLOv8s .ms   | PaddleOCR .ms  | Core Speech Kit | mirrored front |
     +-------------+---------------+----------------+-----------------+----------------+
                                                     Haptics (Sensor Service Kit vibrator)
```

`FeatureServices` (`features/Feature.ets`) is the only thing a feature receives: camera, detector, text reader, narrator, overlay and two callbacks to update the status and timing lines. Features do not know about pages, and pages do not know about models.

## Data flow

```
Camera Kit session (preview surface + second preview output to an ImageReceiver)
   |  frame handler with minimum interval and a busy flag (no overlapping runs)
   v
PixelMap (RGBA)
   |
FrameNormalizer      crop black borders, rotate upright (per camera position),
   |                 return the content rectangle in preview coordinates
   v
+--------------------------+-----------------------------+
| YoloDetector             | TextReader                  |
| letterbox 640x640        | first ready recognizer:     |
| MindSpore Lite predict   |   system (Core Vision Kit)  |
| decode + class-wise NMS  |   on-device (PaddleOCR)     |
+------------+-------------+--------------+--------------+
             |                            |
   SceneTracker / FindGuidance      WordMatcher / FindGuidance
             |                            |
             +-------------+--------------+
                           |
          +----------------+----------------+
          |                |                |
   Overlay (Canvas)   Narrator          Haptics (GuidanceCoach)
   boxes + labels     screen reader     pulse period from closeness,
                      announcement or   long pulse on arrival
                      Core Speech TTS
```

Frame intervals (`common/Config.ets`): Describe 250 ms, Find an object 150 ms, Find a word 700 ms. Because a new frame is only taken when the previous one has finished, the real rate is limited by inference time.

## Feature modules

All features implement `Feature` (`id`, `continuous`, `start()`, `stop()`). `FeatureFactory` maps the tile id to a class. Continuous features register a frame handler; one-shot features take a single frame with `camera.nextFrame()`.

| Feature | Class | What it does |
|---|---|---|
| Describe surroundings | `DescribeFeature` | Runs the detector at threshold 0.35. `SceneTracker` announces an object only after it is seen in 2 consecutive frames, drops it after 4 missing frames, merges person, man, woman, boy, girl and human face into "person", ignores clothing, says at most 4 objects with a position (left, ahead, right) and waits at least 2.5 s between sentences. Example output: "bottle on the left, chair ahead". |
| Find an object | `FindFeature` | The user picks one of 18 targets (`FIND_TARGETS`). Threshold 0.25. The highest-scoring box of that class goes to `computeGuidance`. |
| Find a word | `FindWordFeature` | The user picks a preset (EXIT, WC, PUSH, PULL, OPEN, CLOSED, PHARMACY, STOP) or types a word. OCR every 700 ms, `WordMatcher` finds the word (case and punctuation ignored, one-letter OCR error tolerated for targets of 4+ letters, exact match for shorter ones, multi-word targets must be consecutive). The match box goes to the same guidance as Find an object. |
| Read text | `ReadFeature` | One frame through `TextReader`, line boxes on the overlay, text read aloud (up to 1200 characters). |
| Light check | `LightFeature` | Reads the ambient light sensor (1.5 s timeout) and the average luma of one camera frame. Uses lux when the sensor answers and does not contradict the camera; otherwise uses the camera estimate. |
| What color is this? | `ColorFeature` | Averages a square in the middle of the frame and names it with `ColorNamer` (hue bands plus value and saturation rules for black, white, gray, brown, light and dark shades). |

### Warmer / colder guidance

A single phone camera cannot measure absolute distance, so guidance uses two image cues (`features/FindGuidance.ets`):

- centre score: 1 minus the distance of the box centre from the frame centre, scaled to 0..1;
- size score: the square root of the box area relative to a "full size" side (0.5 of the frame for objects, 0.25 for words).

`closeness = 0.55 * centre + 0.45 * size`. The vibration period goes from 1000 ms (far) to 110 ms (close) on a curve. "Arrived" means closeness at least 0.8 and size score at least 0.6, which gives one long 600 ms vibration and "Bottle is right in front of you". Direction hints ("turn left", "tilt up", "move closer") use a dead zone of 15 % around the centre. `GuidanceCoach` says "Warmer" or "Colder" when closeness changes by more than 0.08 and speaks at most every 3 s. For words the last guidance is held for 1.5 s, so the pulse continues between OCR runs.

## Text recognition providers

`TextReader` holds a list of `TextRecognizer` implementations (`vision/text/TextTypes.ets`): `prepare()`, `isReady()`, `recognize()`, `release()`. `AppServices` registers them in order:

1. `SystemTextRecognizer`: Core Vision Kit `textRecognition`. `prepare()` calls `textRecognition.init()`.
2. `PaddleTextRecognizer`: PP-OCRv4 mobile text detector and English recognizer converted to MindSpore Lite (`ocr_det.ms`, `ocr_rec.ms`, `ocr_dict.txt`), with DB post-processing (`DbPostProcessor.ets`), strip splitting for long lines and greedy CTC decoding (`CtcDecoder.ets`) written in ArkTS.

Both are prepared in parallel at start-up. `read()` uses the first recognizer that reports ready; if it throws, the next one is tried. The choice depends only on what the device can do at runtime. There is no "is this an emulator" check anywhere in the code. The engine name (`system` or `on-device`) and its time are shown in the timing line, so the jury can see which one ran.

## Model pipeline

| Item | Value |
|---|---|
| Detector | Ultralytics YOLOv8s trained on Open Images V7 (601 classes) |
| Pruning | Class head cut to 194 everyday classes (`tools/model/keep_indices.json`); kept scores are bit-identical to the full model |
| Export | ONNX via `tools/model/export_subset.py`, with the DFL layer rewritten as softmax-sum because the converter could not infer the original conv |
| Conversion | MindSpore Lite 2.7.0 `converter_lite` (Linux x86-64) run under qemu in Docker on Apple silicon, `tools/model/convert_to_ms.sh` |
| File | `entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms`, 45 MB |
| Input | `[1,640,640,3]` float32 NHWC (as MindSpore Lite reports it; the ONNX source is NCHW `1x3x640x640`). `YoloDetector` reads the input shape at load time and fills the tensor in either layout. |
| Output | `[1,198,8400]` channels first: `cx, cy, w, h` in input pixels, then 194 sigmoid scores |
| Runtime | `mindSporeLite.loadModelFromBuffer`, CPU, 4 threads |
| Post-processing | best class per anchor above threshold, class-wise NMS at IoU 0.45, at most 20 boxes |
| Time on the emulator | about 220 to 310 ms per frame in total (pre-processing, inference and post-processing are shown separately on the Describe screen). Pruning the class head cut post-processing from about 255 ms to about 60 ms. |

The OCR models come from RapidOCR's ONNX exports of PaddleOCR PP-OCRv4 mobile (Apache-2.0). Both take NHWC input as converted (`[1,640,640,3]` detector, `[1,48,320,3]` recognizer, output `[1,40,97]`). The recognizer needed its 28 HardSwish nodes rewritten as `x * Clip(x + 3, 0, 6) / 6` before the converter produced a working model.

Rebuild steps for the detector are in `tools/model/README.md`.

## Platform capabilities used

| Kit | Use |
|---|---|
| Camera Kit (`@kit.CameraKit`) | Photo session with a preview output for the screen and a second preview output into an `ImageReceiver` for analysis; front and back camera switching with a per-position frame rotation (`BACK_FRAME_ROTATION`, `FRONT_FRAME_ROTATION`) |
| Image Kit | PixelMap crop, rotate and pixel access |
| MindSpore Lite Kit | On-device inference of the detector and the fallback OCR models |
| Core Vision Kit | System text recognition, preferred when available |
| Core Speech Kit | Offline text-to-speech; tries the `en-US` voice first and falls back to `zh-CN` |
| Accessibility Kit | Detects whether the screen reader is on and sends `announceForAccessibility` events instead of using TTS, so speech does not compete with the screen reader |
| Sensor Service Kit | Vibrator for the warmer/colder pulse; ambient light sensor for the light check |
| ArkUI accessibility attributes | `accessibilityText`, `accessibilityDescription`, `accessibilityRole`, `accessibilityGroup`, `accessibilityLevel` on every control |

## Privacy

- Permissions requested: `ohos.permission.CAMERA` (in use only) and `ohos.permission.VIBRATE`. There is no `ohos.permission.INTERNET`, so the app cannot send anything.
- Camera frames live only in memory: each PixelMap is released after processing. No frame, text or detection result is written to storage or logged as an image.
- No account, no analytics, no cloud model.

## Error handling

| Situation | Behaviour |
|---|---|
| Camera permission denied or camera fails to start | Status and announcement "The camera could not be started." |
| Model file fails to load | Detector features say "The recognition model could not be loaded." instead of crashing |
| No OCR engine ready | "Text reading is not available on this device yet." |
| OCR engine throws | Next engine is tried; if none succeeds, "Text could not be read." |
| No text in the frame | "No text found. Move closer and try again." |
| Light sensor missing, silent for 1.5 s, or reading near 0 lux while the camera sees a bright frame | Falls back to the camera brightness estimate |
| Vibrator fails | Error is logged, guidance continues by speech |
| `en-US` voice not installed | Uses the `zh-CN` voice; with the screen reader on, the screen reader's own voice is used |
| Slow inference | Frames are dropped while a frame is being processed; a `running` flag discards results that arrive after Stop |
| Camera switch fails | "The camera could not be switched" |

## Testing

Local unit tests (Hypium) in `entry/src/test` cover the pure logic:

| Suite | Cases | What is checked |
|---|---|---|
| `WordMatcher.test.ets` | 10 | Splitting and normalising words, one-edit tolerance, exact match for short targets, substrings for long targets, words inside a longer box, best score wins, consecutive multi-word targets, empty input |
| `FindGuidance.test.ets` | 7 | Arrival on a large centred box, left/right/up hints, "move closer", faster pulse when closer, smaller full-size side for words |
| `SceneTracker.test.ets` | 5 | Two-frame debounce, no repeated sentence, merged people labels, counting, ignored clothing |
| `ColorNamer.test.ets` | 3 | Primary colours, neutrals, brown and shades |

Run them:

```sh
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Results are in `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.

Not covered by automated tests: camera handling, YOLO tensor decoding, the OCR post-processing (`DbPostProcessor`, `CtcDecoder`), and the UI. These were checked by running the app on the emulator with the Mac webcam and reading the logs (`hilog`, tag `VisionAssist`). The on-device OCR pipeline was first validated in Python against onnxruntime on 8 synthetic samples (character accuracy 0.886 overall) before it was ported to ArkTS.

## Known limits

- The detector has no key or wallet class and is weak on small items. Reliable demo targets: person, bottle, mug, laptop, mobile phone, watch, chair, door.
- Not yet verified on a real phone: vibration (the emulator vibrator reports "Device operation failed"), Core Vision OCR, frame rotation for the real sensor, the `en-US` voice, and a full walkthrough with the screen reader switched on. The accessibility tree was checked on the emulator.
- Timings are emulator CPU numbers; a phone may be faster or slower and the NPU is not used.
- The on-device OCR handles horizontal text only (5 degree rotation already breaks it), confuses similar glyphs (l/1, o/0) and highlights a whole box when the word is inside a longer line.
- If the system OCR reports ready but then fails on every call, each read pays for that failure before the fallback runs; the engine is not demoted for the session.
- Speech and the interface are English only.
- Distance is relative (box size and position), not metric.
