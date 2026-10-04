# Running on the DevEco emulator

Things that cost hours to find out.

1. **Region.** Outside China DevEco Studio only offers watch images. Close DevEco Studio and set `<countryregion name="CN"/>` in `~/Library/Application Support/Huawei/DevEcoStudio6.1/options/country.region.xml` (macOS), then restart it. The phone image (about 2.4 GB) downloads from Device Manager or with `devecocli emulator image download --device-type phone --os-version "HarmonyOS 6.1.1(24)"` after `devecocli emulator license`.
2. **Camera needs a GUI start.** Start the emulator from DevEco Studio's Device Manager and allow DevEco Studio to use the camera in macOS. Starting it with `devecocli emulator start` makes macOS refuse the Mac webcam silently, and the preview stays black.
3. **Sideways frames.** The emulator delivers camera frames rotated by 90 degrees inside a landscape buffer with black borders. `FrameNormalizer` crops the borders and rotates the frame. The emulator has two cameras, `lcam001` (back, orientation 90) and `lcam002` (front, orientation 270), both fed by the Mac webcam. On a physical phone set `BACK_FRAME_ROTATION` and `FRONT_FRAME_ROTATION` in `common/Config.ets` to match the sensor orientation.
4. **Preview size.** Set the XComponent surface rectangle to the component size in pixels, otherwise the preview is drawn at the camera's native size in the middle of the screen.
5. **Core Vision Kit is not available.** `objectDetection` and `textRecognition` fail with "service is abnormal" or time out, which is why detection runs through MindSpore Lite.
6. **English voice.** The `en-US` voice must be downloaded and the download fails in the emulator, so `Narrator` falls back to the Chinese voice. Use a screen reader or a physical device for a proper English voice.
7. **Signing.** For `runtimeOS: "HarmonyOS"` hvigor wants string SDK versions in `build-profile.json5` (`6.1.1(24)`, `6.0.0(20)`).

## Testing with injected frames

The `frames` product replaces the camera with still images or image sequences served from the Mac, so every feature can be tested without holding objects in front of the webcam. It is a debug-only build; the normal `default` product (debug and release) is unchanged. Status: both products build and the unit tests pass; the injected flow has not been run on the emulator yet.

How the two builds differ:

| | `default` product (what ships) | `frames` product (debug only) |
|---|---|---|
| `entry` target | `default`, extra source root `entry/src/default` | `frames`, extra source root `entry/src/frames` |
| `createFrameInjector()` | returns `undefined`, no network code is compiled in | returns `InjectedFrameSource` (HTTP client) |
| `BuildProfile.FRAME_INJECTION` | `false` | `true` |
| `ohos.permission.INTERNET` | requested (`entry/src/main/module.json5`, for cloud search in Find an object) | requested as well; the root `hvigorfile.ts` hook would add it if it were missing |
| Release build mode | allowed | refused: the `hvigorfile.ts` hook fails the build |

The app uses injected frames only when all of these hold: the build is the `frames` product, `BuildProfile.DEBUG` is true, `BuildProfile.FRAME_INJECTION` is true and the frame server answers. Every time a feature screen opens the camera, `FrameSourceSwitch` asks the server for a frame (700 ms timeout). If it answers, the screen shows the injected frames instead of the camera; otherwise the real camera is used. Leaving the screen and opening it again switches source. The log says which source was chosen: `hdc -t 127.0.0.1:5555 hilog | grep "frame source"`.

1. **Start the frame server** on the Mac (Python 3, standard library only):

   ```sh
   python3 tools/debug/frame_server.py serve ~/frames/bottle.jpg
   ```

   It listens on `127.0.0.1:8766` and only on the loopback interface. `GET /frame` returns the current image, `GET /status` tells which file is current.

2. **Forward the port to the emulator** (reverse forward: device port 8766 to Mac port 8766):

   ```sh
   hdc -t 127.0.0.1:5555 rport tcp:8766 tcp:8766
   hdc -t 127.0.0.1:5555 fport ls
   ```

   The forward is lost when the emulator restarts; run it again. Remove it with `hdc -t 127.0.0.1:5555 fport rm "tcp:8766 tcp:8766"`.

3. **Build and install the `frames` product.** It needs the same signing material as `default`: in your local `build-profile.json5`, add `"signingConfig": "default"` to the `frames` product too.

   ```sh
   devecocli build --product frames --modules entry@frames
   hdc -t 127.0.0.1:5555 install -r entry/build/frames/outputs/frames/entry-frames-signed.hap
   ```

   Or `devecocli run --product frames --module entry@frames --device 127.0.0.1:5555`. In DevEco Studio choose the `frames` product and the `entry` `frames` target in the build target selector. The bundle name is the same, so it replaces the installed app; install the `default` product again afterwards.

4. **Open a feature.** The camera permission is still asked (the real camera is the fallback). The square preview shows the injected image; boxes are drawn on it. The camera switch button is hidden while frames are injected.

Feeding frames while the app runs (each command talks to the running server):

```sh
python3 tools/debug/frame_server.py show ~/frames/exit-sign.png
python3 tools/debug/frame_server.py play ~/frames/street/ --fps 2
python3 tools/debug/frame_server.py play a.jpg b.jpg c.jpg --fps 1 --once
python3 tools/debug/frame_server.py status
```

`play` takes files and folders (folders in name order, `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`) and loops unless `--once` is given, in which case it stays on the last frame. The server is the clock: the app polls about every 120 ms and gets whatever frame is current, and continuous features still take frames at their own rate (Describe 250 ms, Find 150 ms, Find a word 700 ms, never overlapping). Images are decoded at most 1024 px on the long side, EXIF rotation is applied, and they are centred on a black square, so the boxes match the preview. Injected frames are not rotated or mirrored.

**Example: guidance with a bottle moving to the centre.** Take a photo with the bottle in the middle, then let the tool cut a sequence where the bottle starts near the left edge and ends in the centre, filling more of the frame towards the end:

```sh
python3 tools/debug/frame_server.py pan ~/frames/bottle.jpg --out ~/frames/bottle-pan --steps 12 --start left --zoom 0.5 --end-zoom 0.3
python3 tools/debug/frame_server.py play ~/frames/bottle-pan --fps 1 --once
```

Open Find an object, choose Bottle: guidance says "Bottle in view, on the left", then "Turn left." and the other spoken directions until "Bottle is right in front of you, within reach". Without `sam3.json`, or with the emulator offline, Find uses the on-device model. `--start` takes `left`, `right`, `top` or `bottom`; keep `--zoom` at 0.55 or below so the bottle can reach the edge. `pan` uses Pillow when it is installed and macOS `sips` otherwise.

Ideas for the other features: Describe surroundings and Find a word with a photo or screenshot of a sign or a page; the light status in Describe with a dark and a bright photo (the emulator light sensor reports 0 lux, so the camera fallback reads the injected image).

Tests for the server: `cd tools/debug && python3 -m unittest test_frame_server`.
