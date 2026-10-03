# Vision Assist

An offline assistive feature for blind and low-vision users on HarmonyOS. Point the phone, and it tells you what is in front of you, with boxes drawn on the live camera view. All recognition runs on the device: no cloud, no account, no camera frame leaves the phone.

Built for the HackYeah 2026 Huawei challenge "Imagine What's Next" (Human-Centric Technology, Intelligent Experiences).

## Status

| Feature | State |
|---|---|
| Live describe (camera, on-device detection, boxes, spoken summary) | Working on the emulator |
| Screen reader support | Implemented, not yet verified on a running screen reader |
| Find an object with "warmer / colder" vibration | Planned |
| Read printed text | Planned (Core Vision OCR does not run on the emulator) |

Known limits: the detector knows 194 everyday classes. It is weak on small items such as keys and has no wallet class. See `tools/model/README.md`.

## How it works

```
Camera Kit (preview + ImageReceiver)
        |  RGBA frame, about 4 per second
        v
FrameNormalizer   crop black borders, rotate upright
        |
        v
YoloDetector      letterbox 640x640, MindSpore Lite predict, class-wise NMS
        |
        v
SceneTracker      merge people labels, debounce, build "cup on the left, person ahead"
        |
        +--> Canvas overlay (boxes + labels)
        +--> Narrator: system screen reader announcement if it is on, otherwise Core Speech Kit
```

Source layout (`entry/src/main/ets`):

| Path | Responsibility |
|---|---|
| `pages/Index.ets` | Screen, start/stop button, overlay drawing |
| `camera/CameraSource.ets` | Camera session, frame delivery with throttling |
| `vision/FrameNormalizer.ets` | Frame cleanup and mapping to the preview |
| `vision/YoloDetector.ets` | Model loading, preprocessing, decoding, NMS |
| `vision/SceneTracker.ets` | Which objects to announce and when |
| `speech/Narrator.ets` | Text to speech and accessibility announcements |

Accessibility: large 80 vp button spanning the width, `accessibilityText` and description on controls, the decorative camera view is hidden from the screen reader, and results are announced with `announceForAccessibility` when a screen reader is active.

Platform capabilities used: Camera Kit, MindSpore Lite Kit (on-device inference), Core Speech Kit (offline TTS), Accessibility Kit.

## Requirements

- DevEco Studio 6.1.1 or later (macOS arm64 or Windows). The project targets HarmonyOS API 24 (`6.1.1(24)`) and declares API 20 (`6.0.0(20)`) as the minimum.
- A HarmonyOS emulator (Huawei phone image, API 24) or a physical HarmonyOS device. The emulator image needs the DevEco region set to China; see `docs/EMULATOR.md`.

## Build and run

1. Open this folder in DevEco Studio.
2. Create signing material: File, Project Structure, Signing Configs, "Automatically generate signature" (needs a Huawei ID), or use the repository's offline path below.
3. Start an emulator from DevEco Studio's Device Manager (not from the command line, see `docs/EMULATOR.md`).
4. Run the `entry` module. Allow camera access when asked, then press "Start describing".

Command line (with `devecocli`):

```sh
devecocli build
devecocli run --device 127.0.0.1:5555
```

Offline signing for the emulator (no account) with the sample keys that ship in the OpenHarmony SDK:

```sh
SDK=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib
mkdir -p signatures && cp "$SDK/OpenHarmony.p12" "$SDK/OpenHarmonyProfileRelease.pem" signatures/
```

Create a profile for the bundle `com.hackyeah.visionassist` from `$SDK/UnsgnedReleasedProfileTemplate.json` (change `bundle-name`) and sign it with `hap-sign-tool.jar sign-profile` (sample key password is documented by OpenHarmony). Then add a `signingConfigs` entry to `build-profile.json5` pointing at the files in `signatures/`. The `signatures/` folder is git-ignored on purpose.

## Model

`entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms` is committed so the app builds without any model tooling. To rebuild it, follow `tools/model/README.md`.

## License

Application code: MIT. The bundled model is AGPL-3.0, see `NOTICE.md`.
