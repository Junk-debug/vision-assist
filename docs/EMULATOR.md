# Running on the DevEco emulator

Things that cost hours to find out.

1. **Region.** Outside China DevEco Studio only offers watch images. Close DevEco Studio and set `<countryregion name="CN"/>` in `~/Library/Application Support/Huawei/DevEcoStudio6.1/options/country.region.xml` (macOS), then restart it. The phone image (about 2.4 GB) downloads from Device Manager or with `devecocli emulator image download --device-type phone --os-version "HarmonyOS 6.1.1(24)"` after `devecocli emulator license`.
2. **Camera needs a GUI start.** Start the emulator from DevEco Studio's Device Manager and allow DevEco Studio to use the camera in macOS. Starting it with `devecocli emulator start` makes macOS refuse the Mac webcam silently, and the preview stays black.
3. **Sideways frames.** The emulator delivers camera frames rotated by 90 degrees inside a landscape buffer with black borders. `FrameNormalizer` crops the borders and rotates the frame. The emulator has two cameras, `lcam001` (back, orientation 90) and `lcam002` (front, orientation 270), both fed by the Mac webcam. On a physical phone set `BACK_FRAME_ROTATION` and `FRONT_FRAME_ROTATION` in `common/Config.ets` to match the sensor orientation.
4. **Preview size.** Set the XComponent surface rectangle to the component size in pixels, otherwise the preview is drawn at the camera's native size in the middle of the screen.
5. **Core Vision Kit is not available.** `objectDetection` and `textRecognition` fail with "service is abnormal" or time out, which is why detection runs through MindSpore Lite.
6. **English voice.** The `en-US` voice must be downloaded and the download fails in the emulator, so `Narrator` falls back to the Chinese voice. Use a screen reader or a physical device for a proper English voice.
7. **Signing.** For `runtimeOS: "HarmonyOS"` hvigor wants string SDK versions in `build-profile.json5` (`6.1.1(24)`, `6.0.0(20)`).
