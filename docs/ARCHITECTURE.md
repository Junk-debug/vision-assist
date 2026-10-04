# Architecture and implementation

Vision Assist is a native HarmonyOS app (ArkTS, ArkUI, API 20 minimum, built against API 24) that helps blind and low-vision people with the phone camera. Recognition runs on the phone by default. The one exception is Find an object, which uses SAM 3 in the cloud while the phone is online and a Roboflow key is present, and falls back to the on-device model otherwise.

This document describes the code as committed. The app was tested on a Kirin 9000S HarmonyOS phone (`docs/DEVICE.md`) and on the DevEco emulator; statements checked only on the emulator are marked as such.

## Components

```
                         +---------------------------+
                         |  pages/Index.ets          |  navigation
                         |  pages/HomePage.ets       |  three feature tiles (no camera)
                         |  pages/FeaturePage.ets    |  camera, status, action button, picker, engine chip
                         +-------------+-------------+
                                       |
                         creates one Feature via FeatureFactory
                                       |
     +---------------------------------+---------------------------------+
     |                                 |                                 |
 Describe surroundings           Find an object                     Find a word
 (objects, colours, text,        (continuous)                       (continuous)
  light status)                        |                                 |
     |                                 +--- FindStateMachine ------------+
     |                                 |    + GuidanceCoach (speech)     |
     v                                 v                                 v
 SceneTracker, TextHint,          FindEngine:                        WordMatcher
 LightMeter                       Sam3Detector (cloud) or
                                  YoloDetector (on device)
     \_________________________________|_________________________________/
                                       |
                           FeatureServices (app/AppServices.ets, shared by all screens)
     +-------------+---------------+----------------+-----------------+----------------+
     | FrameSource | YoloDetector  | TextReader     | Narrator        | Overlay        |
     | Camera Kit  | MindSpore Lite| System OCR ->  | Accessibility / | Canvas boxes,  |
     | + Image Kit | YOLOv8s .ms   | PaddleOCR .ms  | Core Speech Kit | mirrored front |
     +-------------+---------------+----------------+-----------------+----------------+
```

`FeatureServices` (`features/Feature.ets`) is the only thing a feature receives: camera, detector, cloud detector, find engine, text reader, narrator, overlay and callbacks to update the status and timing lines. Features do not know about pages, and pages do not know about models.

## Data flow

```
Camera Kit session (preview surface + second preview output to an ImageReceiver)
   |  frame handler with minimum interval and a busy flag (no overlapping runs)
   v
NV21 -> PixelMap (RGBA) at half resolution (YUV_DOWNSCALE = 2 in camera/CameraSource.ets)
   |
FrameNormalizer      crop black borders, rotate upright (per camera position),
   |                 return the content rectangle in preview coordinates
   v
+--------------------------+-----------------------------+
| YoloDetector             | TextReader                  |
| letterbox 640x640        | first ready engine, timed:  |
| MindSpore Lite predict   |   system (Core Vision Kit)  |
| decode + class-wise NMS  |   on-device (PaddleOCR)     |
| (Find online: SAM 3)     |                             |
+------------+-------------+--------------+--------------+
             |                            |
   SceneTracker / FindStateMachine  WordMatcher / FindStateMachine
             |                            |
             +-------------+--------------+
                           |
                  +--------+--------+
                  |                 |
           Overlay (Canvas)    Narrator
           boxes + labels      screen reader announcement
                               or Core Speech TTS
```

Frame intervals (`common/Config.ets`): Describe 250 ms, Find an object 150 ms on device and 300 ms with cloud search, Find a word 700 ms. Because a new frame is only taken when the previous one has finished, the real rate is limited by inference time.

## Feature modules

All features implement `Feature` (`id`, `continuous`, `start()`, `stop()`). `FeatureFactory` maps the tile id to a class. Continuous modes register a frame handler; one-shot actions (Describe now) take a single frame with `camera.nextFrame()`. `camera` is a `FrameSource` (`camera/FrameSource.ets`): `CameraSource` in normal builds; in the debug-only `frames` build `FrameSourceSwitch` uses `InjectedFrameSource` (`entry/src/frames`) when the Mac frame server answers, see `docs/EMULATOR.md`.

| Feature | Class | What it does |
|---|---|---|
| Describe surroundings | `DescribeFeature` | Runs the detector at threshold 0.35 and names at most 3 objects ranked by size, confidence and centredness, with their colour, skipping low-value classes (`SceneTracker`). Text from the same frame goes through `TextReader`: short text is spoken in the description, longer text is read aloud in chunks after it. The light status from `LightMeter` (ambient light sensor, camera brightness as fallback) is added at the end. Live description announces only changes, at most every 3 s. |
| Find an object | `FindFeature` | The user picks one of 19 targets (`FIND_TARGETS`, Keys first) or types or dictates any name. `FindEngine` chooses SAM 3 in the cloud (threshold 0.4, `FIND_CLOUD_TUNING`) or the on-device detector (threshold 0.25, `FIND_OBJECT_TUNING`). The highest-scoring box goes to `FindStateMachine`. |
| Find a word | `FindWordFeature` | The user picks a preset (EXIT, WC, PUSH, PULL, OPEN, CLOSED, PHARMACY, STOP) or types a word. OCR every 700 ms, `WordMatcher` finds the word (case and punctuation ignored, one-letter OCR error tolerated for targets of 4+ letters, exact match for shorter ones, multi-word targets must be consecutive). The match box goes to the same state machine as Find an object, with `FIND_WORD_TUNING`. |

`LightFeature` and `ColorFeature` are still in `features/` but are not in the menu (`ui/FeatureCatalog.ets` lists only `describe`, `find` and `findword`).

### Find an object: cloud or on-device

`vision/FindEngine.ets` picks the detector for every frame:

- Cloud (`vision/Sam3Detector.ets`) when the mode is Auto, a key was loaded from `rawfile/sam3.json` (`{"roboflowApiKey": "..."}`, git-ignored), the phone has a validated internet connection (Network Kit `connection`, `NET_CAPABILITY_VALIDATED`) and no cloud request failed in the last 20 s. The frame is sent as JPEG (quality 80) to `POST https://serverless.roboflow.com/sam3/concept_segment` with the target name as text prompt; connect and read timeouts are 4 s. Masks are turned into boxes.
- On-device otherwise. A target the on-device classes do not contain (case-insensitive match against the 194 labels) cannot be found offline; the app says "<X> can only be found with cloud search. Connect to the internet."

The switch happens mid-search without a restart: the state machine keeps its state, only the tuning, frame interval and threshold change, and the new engine is announced ("Online. Using cloud search.", "Offline. Using the on-device model.", "Cloud not responding. Using the on-device model."). A chip under the status card shows the engine and the mode ("Cloud search · Auto", "On-device · offline", "cloud unreachable" or "chosen"); double tap toggles between Auto and on-device only. The chip is hidden when there is no key.

### Spoken guidance

A single phone camera cannot measure absolute distance, so guidance uses image cues (`features/FindGuidance.ets`): how far the box centre is from the frame centre, the larger side of the box relative to the frame, and how much it has grown since it was first seen. `closeness = 0.55 * centre + 0.45 * size` is shown on the status card as a percentage.

`features/FindStateMachine.ets` turns this into speech; `GuidanceCoach` sends it to the narrator:

- Searching: "Searching for bottle. Turn slowly." at most every 4 s.
- Acquired (seen in 2 of the last 3 frames on device, 1 of 2 with cloud search): "Bottle in view, on the left", once.
- Guiding: a direction ("turn left", "tilt up") at most every 2.5 s and the same one at most every 5 s, using a dead zone of 15 % around the centre; "Hold steady." once when centred; "Move the phone closer slowly." at most every 4 s and 3 times.
- Arrived (centred and large enough, or grown enough, for 2 frames in a row): "Bottle is right in front of you, within reach", then quiet.
- Lost (missing for more than 1 s on device, 4 s with cloud search, 2.2 s for words): "Lost bottle. Move back slowly."

The thresholds are in `FIND_OBJECT_TUNING`, `FIND_CLOUD_TUNING` and `FIND_WORD_TUNING` in `common/Config.ets`. The `slowestPulseMs`, `fastestPulseMs` and `pulseSteps` values set the guidance update rate. `haptics/` holds short haptic cues that `GuidanceCoach` and the buttons also trigger; they are not relied on, the guidance is spoken.

## Text recognition providers

`TextReader` holds a list of `TextRecognizer` implementations (`vision/text/TextTypes.ets`): `prepare()`, `isReady()`, `recognize()`, `release()`. `AppServices` registers them in order:

1. `SystemTextRecognizer`: Core Vision Kit `textRecognition`. `prepare()` calls `textRecognition.init()`.
2. `PaddleTextRecognizer`: PP-OCRv4 mobile text detector and English recognizer converted to MindSpore Lite (`ocr_det.ms`, `ocr_rec.ms`, `ocr_dict.txt`), with DB post-processing (`DbPostProcessor.ets`), rotated boxes (`RotatedBox.ets`), strip splitting for long lines and greedy CTC decoding (`CtcDecoder.ets`) written in ArkTS.

### OCR post-processing (on-device engine)

1. The detector's probability map (640 x 640) is thresholded at 0.3 and split into 4-connected components. During the flood fill each component records the first and last column of every row.
2. Those row ends give the convex hull of the component's pixel squares (monotone chain). Rotating calipers over the hull edges give the minimum-area rectangle, with its angle folded into (-45, 45] degrees. A rectangle that is taller than wide counts as upright.
3. If the angle is below 2 degrees the box is the old axis-aligned box (same unclip, same rounding), so horizontal text reads exactly as before. Otherwise the rectangle is unclipped along its own axes (DB offset = area x 1.6 / perimeter) and scaled to frame pixels.
4. Line grouping works in the page frame: the page angle is the width-weighted median of the box angles (0 below 2 degrees), each box is projected onto that frame, and boxes whose vertical spans overlap by more than half join one line, ordered left to right along the text direction.
5. A rotated box is cut out with an affine bilinear crop (`rotatedCrop` in `ImageOps.ets`) into an upright strip 48 px high; an upright box keeps `resizeRgb`. Strip splitting and CTC decoding are unchanged.
6. Word and line boxes handed to the app stay axis-aligned, normalised bounding boxes of the rotated rectangles, so Find a word and the overlays need no change.

Cost: the flood fill does two extra comparisons per text pixel, and each component builds a hull of at most two points per row with an O(h^2) caliper pass (h is a few dozen vertices). In the hypium host runtime a 640 x 640 map with 10 text lines took about 110 to 150 ms against 90 to 125 ms for the old code (about +15 %, interpreter, no AOT). The rotated crop samples as many pixels as the old resize and costs the same. On a phone this adds a few milliseconds to a Find a word cycle of 700 ms.

Both are prepared in parallel at start-up. The choice depends only on what the device can do at runtime. There is no "is this an emulator" check anywhere in the code. The engine name (`system` or `on-device`) and its time are shown in the timing line, so the jury can see which one ran.

Engine selection is split into a pure policy and a runner:

- `EnginePolicy.ets` (no I/O) keeps a state per engine: `pending`, `ready`, `unavailable` or `disabled`, the count of consecutive failures and whether a call is still running. `order()` returns the ready, idle engines in registration order, so the system engine is preferred whenever it is ready.
- `EngineRunner.ets` runs `prepare()` and `recognize()` under per-engine timeouts (`withTimeout` with an injectable `Timer`) and reports the outcome to the policy. `TextReader` is the runner for `PixelMap` frames with the system timer and the app logger.
- Limits are in `TextEngineConfig.ets`: system prepare 6 s and recognize 2.5 s, on-device prepare 20 s and recognize 15 s, and an engine is disabled after 2 consecutive failures or timeouts.

Rules:

1. Reads never wait for a prepare. An engine is used as soon as it is ready; a slow engine does not block one that is already ready. If the system engine becomes ready later (also after its prepare timed out), the next read uses it.
2. A recognize that fails or times out falls through to the next engine in the same read, so a hanging system engine costs at most its recognize timeout. While a timed-out call is still running, that engine is skipped.
3. After 2 consecutive failures the engine is disabled for the rest of the session (log line `text engine system disabled for this session after 2 failures`). A success resets the count. The last engine still in play is never disabled, so reading keeps being tried.
4. If no engine produces a result, `read()` returns `undefined` (log line `text read failed: no engine produced a result`) and the feature says "Text could not be read.". If no engine is ready, `isAvailable()` is false and the feature says "Text reading is not available on this device yet.".
5. The engine actually used is logged when it changes (`text engine in use: on-device`) and is returned in `TextReadResult.engine`.

Unit tests with fake engines are in `entry/src/test/TextEngines.test.ets`.

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
| Runtime | `mindSporeLite.loadModelFromBuffer`, fp16 on the CPU (NNRt accelerators are tried first; on the Kirin 9000S they return a model without inputs, so the CPU is used) |
| Post-processing | best class per anchor above threshold, class-wise NMS at IoU 0.45, at most 20 boxes |
| Time | about 55 to 190 ms per frame for inference on a Kirin 9000S phone in fp16 (119 ms in fp32; the live Describe screen showed 187 ms with the camera running); about 220 to 310 ms per frame in total on the emulator. Pruning the class head cut post-processing on the emulator from about 255 ms to about 60 ms. A 416x416 model was tried for speed and reverted because it missed a bottle on a table. |

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
| Sensor Service Kit | Ambient light sensor, used inside Describe for the light status |
| Network Kit | `connection` to watch for a validated internet connection, `http` for the SAM 3 request in Find an object |
| ArkUI accessibility attributes | `accessibilityText`, `accessibilityDescription`, `accessibilityRole`, `accessibilityGroup`, `accessibilityLevel` on every control |

## Privacy

- Permissions requested (`entry/src/main/module.json5`): `ohos.permission.CAMERA` (in use only), `ohos.permission.VIBRATE`, `ohos.permission.INTERNET` and `ohos.permission.GET_NETWORK_INFO`. The network permissions exist for cloud search in Find an object.
- Only Find an object sends anything, and only with a key in `rawfile/sam3.json`, in Auto mode and while online: the current frame as JPEG and the target name go to Roboflow. Describe and Find a word never use the network. Without the key file, or with the chip set to on-device only, nothing leaves the phone. The published release `.hap` has no key.
- The frame HTTP client of the debug-only `frames` product lives in `entry/src/frames` and is not compiled into the `default` product; the build refuses `frames` in release mode.
- Camera frames live only in memory: each PixelMap is released after processing. No frame, text or detection result is written to storage or logged as an image.
- No account, no analytics.

## Error handling

| Situation | Behaviour |
|---|---|
| Camera permission denied or camera fails to start | Status and announcement "The camera could not be started." |
| Model file fails to load | Detector features say "The recognition model could not be loaded." instead of crashing |
| No OCR engine ready | "Text reading is not available on this device yet." |
| OCR engine throws or times out | Next engine is tried in the same read; after 2 consecutive failures the engine is disabled for the session; if none succeeds, "Text could not be read." |
| No text in the frame | "No text found. Move closer and try again." |
| Light sensor missing, silent for 1.5 s, or reading near 0 lux while the camera sees a bright frame | Falls back to the camera brightness estimate |
| Cloud request fails or times out (4 s) | Find switches to the on-device model for 20 s and says "Cloud not responding. Using the on-device model." |
| Phone goes offline during Find | Switches to the on-device model and says "Offline. Using the on-device model." |
| `en-US` voice not installed | Uses the `zh-CN` voice; with the screen reader on, the screen reader's own voice is used |
| Slow inference | Frames are dropped while a frame is being processed; a `running` flag discards results that arrive after Stop |
| Camera switch fails | "The camera could not be switched" |

## Testing

Local unit tests (Hypium) in `entry/src/test` cover the pure logic:

| Suite | Cases | What is checked |
|---|---|---|
| `FindStateMachine.test.ets` | 21 | Searching, acquiring after 2 of 3 frames, directions not repeated too often, hold steady and move closer, lost and reacquired, arrival rules for tall, small and wide targets, word tuning |
| `RotatedBox.test.ets` | 16 | Convex hull, minimum-area rectangle, angles, rotated crop, box extraction, line grouping |
| `ColorNamer.test.ets` | 15 | Coarse colours, neutrals, light and dark, white-balance correction, highlights, mixed colours |
| `Messages.test.ets` | 14 | Sentence building for describe, find, text and timings; every failure says what to do next |
| `FrameSource.test.ets` | 13 | Frame gate interval and busy skip, square frames, camera or injected frame source |
| `SceneTracker.test.ets` | 13 | At most 3 objects by relevance, merged people labels, counting, skipped classes, live changes and rate limit |
| `TextEngines.test.ets` | 11 | Engine order, disabling after failures, timeouts, slow prepare, no engine ready |
| `WordMatcher.test.ets` | 10 | Splitting and normalising words, one-edit tolerance, exact match for short targets, substrings, best score, consecutive multi-word targets |
| `Haptics.test.ets` | 9 | Haptic cue plans and fallback patterns in `haptics/` |
| `FindGuidance.test.ets` | 8 | Box measurement, directions outside the dead zone, position names, within-reach rules, word tuning, update rate |
| `ReadAloud.test.ets` | 8 | Chunking text and reading chunks one after another, stopping |
| `PhotoMath.test.ets` | 5 | Photo size cap, EXIF orientation, letterboxing |
| `ObjectColor.test.ets` | 4 | Colour of a detection box, no colour for people |
| `TextSummary.test.ets` | 4 | Line splitting and previews |
| `Accessibility.test.ets` | 3 | Focus chain, announcement rate limit |
| `LocalUnit.test.ets` | 1 | Template test |

155 cases in 16 suites; `List.test.ets` only registers the suites.

Run them:

```sh
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

Results are in `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.

Not covered by automated tests: camera handling, YOLO tensor decoding, the CTC decoder, the SAM 3 request, `FindEngine` and the UI. These were checked by running the app on the Kirin 9000S phone and on the emulator with the Mac webcam and reading the logs (`hilog`, tag `VisionAssist`). The on-device OCR pipeline was first validated in Python against onnxruntime on 8 synthetic samples (character accuracy 0.886 overall) before it was ported to ArkTS.

## Known limits

- The on-device detector has no key or wallet class and is weak on small items; keys and other unknown names need cloud search. Reliable on-device targets: person, bottle, mug, laptop, mobile phone, watch, chair, door.
- Cloud search needs a Roboflow key inside the app package; a production version would call the cloud through its own backend.
- Not documented as verified on the phone: which OCR engine runs (Core Vision Kit or the on-device fallback), the `en-US` voice, and a full walkthrough with the screen reader switched on (the accessibility tree was checked on the emulator).
- The NPU is not used: both NNRt drivers on the Kirin 9000S reject the float32 graphs, so inference runs in fp16 on the CPU.
- The on-device OCR reads text rotated up to about 15 degrees (tested in Python on synthetic samples, not yet on a phone); vertical text, curved text and perspective are not handled. It confuses similar glyphs (l/1, o/0) and highlights a whole box when the word is inside a longer line.
- If the system OCR reports ready but then fails on every call, each read pays for that failure before the fallback runs; the engine is not demoted for the session.
- Speech and the interface are English only.
- Distance is relative (box size and position), not metric.
