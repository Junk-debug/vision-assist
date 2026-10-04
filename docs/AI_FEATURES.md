# AI features

This document covers every AI model and service inside Vision Assist: what runs, where it runs, what data it sees, how it fails and how we checked it. How AI tools were used to build the app is in [`AI_WORKFLOW.md`](../AI_WORKFLOW.md).

## Summary

| Feature | Model or service | Where it runs | Network |
|---|---|---|---|
| Describe surroundings, Find an object (offline) | YOLOv8s trained on Open Images V7, class head pruned to 194 classes, MindSpore Lite `.ms` (45 MB, input 640x640) | Phone, MindSpore Lite on the CPU in fp16 | None |
| Find an object (online) | SAM 3 (Meta, Segment Anything Model 3), text-prompt concept segmentation on Roboflow Serverless | Roboflow cloud | HTTPS, only when online and a key is configured |
| Text in Describe, Find a word | Core Vision Kit `textRecognition` when the device has it; otherwise PaddleOCR PP-OCRv4 mobile detector + English recognizer in MindSpore Lite | Phone | None |
| Speech | Core Speech Kit offline text-to-speech, or the system screen reader | Phone | None |

There is no LLM and no speech recognition model in the app. Voice entry of an object name uses the system keyboard's dictation, which the app does not control.

## On-device detector

- **Model.** Ultralytics `yolov8s-oiv7.pt`, exported to ONNX at 640x640 with the class head pruned from 601 to 194 everyday classes (`tools/model/keep_indices.json`), converted with the MindSpore Lite 2.7.0 converter. Pruning keeps scores bit-identical and cut post-processing from about 255 ms to about 60 ms on the emulator.
- **Why this model.** We benchmarked YOLO-World (s, m, l), YOLOE (v8s, v8m, 11s, 11m) and OWLv2 on web photos, emulator frames and our own photos. None found keys. The Open Images model was the only one that found watches (0.89 to 0.95) and coins (0.61 to 0.86), and it is good on phones, glasses and bottles. See `docs/DECISIONS.md` section 4.
- **Runtime.** MindSpore Lite Kit. The app first tries the NNRt accelerators; on the tested Kirin 9000S both NPU drivers return a model without usable inputs for our float32 graph, so it runs on the CPU with `preferred_fp16`: about 55 to 190 ms per frame (119 ms in fp32), measured in `hilog` on the phone.
- **Input size.** We tried a 416x416 export for speed. On the phone it missed a bottle standing in the middle of a table, while chairs and people were still found; at 416 and half-resolution camera frames the bottle was only about 8x25 pixels. We went back to 640 (commit `b30d91b`). Inference at 416 was not faster in practice (75 ms vs 55 ms logged).

## Cloud detector: SAM 3

Added so that Find an object can look for anything the user names, including keys, which the on-device model has no class for.

- **Service.** `POST https://serverless.roboflow.com/sam3/concept_segment`, Bearer API key, JSON body with the image as base64 and one text prompt. Code: `entry/src/main/ets/vision/Sam3Detector.ets`.
- **Prompt.** The target name in lower case, for example `bottle`, `keys` or `red cup`.
- **Output.** Polygons with a confidence per instance. The app turns each polygon set into a bounding box normalised to the frame and keeps instances at or above 0.4 (`CLOUD_FIND_THRESHOLD`).
- **Cost.** Billed per image by Roboflow. The free plan includes 10 credits a month. We have not confirmed the per-image price for SAM 3 on Roboflow's own pages.

### When the cloud is used

`entry/src/main/ets/vision/FindEngine.ets` picks the detector for every frame:

1. Mode is Auto (the default), and
2. a key is present in `entry/src/main/resources/rawfile/sam3.json`, and
3. the system reports a default network with both `NET_CAPABILITY_INTERNET` and `NET_CAPABILITY_VALIDATED`, and
4. no cloud request has failed in the last 20 seconds.

Otherwise the on-device model runs. The engine listens to `netCapabilitiesChange`, `netLost` and `netUnavailable`, so a dropped connection switches back without restarting the search. The user can also choose "on-device only" with the engine chip on the Find screen.

### Inference flow (online)

1. Camera frame (half-resolution RGBA, about 640x360 before rotation).
2. JPEG at quality 80, base64.
3. HTTPS request with a 4 s connect and read timeout.
4. Polygons → boxes → best match for the target.
5. Same guidance state machine as offline, with cloud timings (`FIND_CLOUD_TUNING` in `common/Config.ets`): one frame every 300 ms at most, acquired on one hit, lost after 4 s, arrival needs the box to be 55 % of the frame, or 4x growth and at least 35 %, on 2 frames in a row.

### Failure handling

| What goes wrong | What the app does |
|---|---|
| No key file or empty key | Cloud is never used; the engine chip is hidden |
| Phone offline or network not validated | On-device model; the chip shows "On-device · offline"; spoken once if it changes during a search |
| HTTP error, timeout, invalid JSON | The same frame is re-run on the device; the cloud is skipped for 20 s; spoken: "Cloud not responding. Using the on-device model." |
| Target unknown to the on-device model while offline (keys, free text) | Status and speech: "Keys can only be found with cloud search. Connect to the internet." |
| Wrong or missing detections | The guidance needs consistent boxes over several frames before it says "in view" or "within reach"; it cannot remove consistent false positives |

## Data handling and privacy

- **Offline (default without a key, and whenever offline).** Frames are processed in memory and released. Nothing is saved, uploaded or logged as an image. No account, analytics or identifiers.
- **Online cloud search.** While Find an object runs in cloud mode, camera frames (JPEG, about 640x360) and the target word are sent over HTTPS to Roboflow. Describe surroundings and Find a word never use the network. We do not store the frames or the responses. Roboflow's retention of request data is governed by its terms; we have not verified it.
- **Who decides.** The engine chip on the Find screen shows and speaks which engine is active, and one double tap switches to "on-device only".
- **Permissions.** `CAMERA`, `VIBRATE`, `INTERNET` and `GET_NETWORK_INFO`. The last two exist only for cloud search.
- **The key.** `sam3.json` is git-ignored and is not in the repository or its history. A key bundled into a `.hap` can be extracted from the package, so the published release `.hap` is built without a key and runs offline only. A production version would call SAM 3 through our own backend instead of shipping a key.

## Limitations

- On-device: 194 classes, no keys or wallet class, weak on small items far away.
- Cloud: needs a connection and a key; latency depends on the network (not yet measured on the phone); frames leave the device.
- Distance is relative (box size and growth), not in centimetres.
- The cloud arrival thresholds were raised after SAM 3 said "right in front of you" at about 70 cm; the new values are not yet checked on the phone.
- Text recognition on the device is English only and horizontal text only.
- The app speaks English; without the `en-US` voice installed it falls back to the Chinese voice.

## Validation

| What | How | Result |
|---|---|---|
| Detector choice | Benchmarks of six detector families (YOLO-World, YOLOE, OWLv2, LW-DETR, YOLOv8 COCO, YOLOv8 Open Images V7) on web photos, emulator frames and our own photos | Open Images model chosen; numbers in `docs/DECISIONS.md` section 4 |
| Model conversion | Converted `.ms` outputs compared with onnxruntime | Pruned YOLO scores bit-identical; OCR recognizer 0.0018 % mean bias; OCR detector cosine similarity 0.99982 |
| OCR pipeline | Python reference on 8 samples before the ArkTS port | Character accuracy 0.886 |
| 640 vs 416 input | Same scene on the Kirin 9000S phone, debug overlay and logs | 416 missed the bottle; 640 restored |
| SAM 3 integration | Bottle search on the phone with the cloud engine | Found and guided to the bottle; arrival fired too early (fixed, not re-checked) |
| Logic around the models | Hypium unit tests (`entry/src/test`, 16 suites, 155 test cases): guidance state machine, word matching, scene sentences, frame geometry, accessibility helpers | `hvigorw test` passes |
| Engine switching | Manual: start Find online, turn Wi-Fi off and on | To be recorded; no unit test for `FindEngine` yet |
