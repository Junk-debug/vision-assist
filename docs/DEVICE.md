# Installing on a physical HarmonyOS phone

## 1. Check the phone first

The app is a native HarmonyOS app (`.hap`, ArkTS, API 20 or later). It runs only on **HarmonyOS 5 / HarmonyOS NEXT or later** (API 20+). Phones on HarmonyOS 4.x or EMUI are Android-based and cannot install a `.hap`. Check in Settings, About phone.

## 2. Enable developer mode and USB debugging on the phone

1. Settings, About phone: tap the build number seven times until developer mode turns on.
2. Settings, System (or Developer options): turn on **USB debugging**. Optionally turn on **Wireless debugging**.
3. Connect the phone with a USB cable that carries data and accept the debugging prompt on the phone.
4. Check that the computer sees it:

   ```sh
   HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
   $HDC list targets
   ```

   or `devecocli device list`. The phone appears with its serial number.

## 3. Sign the app for that phone

The offline OpenHarmony sample keys described in the README only work on the emulator. A commercial HarmonyOS phone needs a debug certificate and profile issued by Huawei for your account and that phone.

1. In DevEco Studio open this project, File, Project Structure, Project, **Signing Configs**.
2. Tick **Automatically generate signature** and sign in with a Huawei ID when asked. With the phone connected, DevEco registers it and writes the generated certificate, profile and keystore into the project's `signingConfigs`.
3. Click OK. `build-profile.json5` now points at the generated files. Do not commit them.

If sign-in fails or DevEco reports a region problem: the emulator setup switched DevEco to the China region (`docs/EMULATOR.md`). Switch the region in `country.region.xml` back to the country of your Huawei ID, restart DevEco Studio and try again. You can switch back to `CN` afterwards for the emulator.

## 4. Build, install, run

From DevEco Studio: pick the phone in the device list and press Run.

From the command line:

```sh
devecocli build
devecocli run --device <serial-from-list-targets>
```

If the install fails with `9568332 install sign info inconsistent`, an older build signed with other keys is on the phone. Uninstall it first:

```sh
$HDC -t <serial> uninstall com.hackyeah.visionassist
```

Allow camera access on first launch.

## 5. Things to check on a real phone

These could not be verified on the emulator:

| What | How to check | If it is wrong |
|---|---|---|
| Frame rotation | Start "Describe surroundings": boxes must sit on the objects | Change the rotation per camera position in `entry/src/main/ets/common/Config.ets` (usually 90 for the back camera, 270 for the front) |
| Front camera | Switch camera, boxes still on objects | Same setting, plus mirroring for the front camera |
| System OCR | "Read text" status line shows the engine; on a phone it should be `system` | If it says `on-device`, Core Vision OCR is not available and the fallback is used |
| Vibration | "Find an object", target "Person", point at someone | Guidance must still vibrate with touch feedback off (usage `notification`); it stops only in silent mode. Button taps, results and errors give short cues only while touch feedback is on |
| English voice | Any feature that speaks | The `en-US` voice may need a download over the network the first time; until then the app uses the Chinese voice |
| Screen reader | Settings, Accessibility, ScreenReader, then navigate with swipes and double tap | Report which element is read wrongly |
