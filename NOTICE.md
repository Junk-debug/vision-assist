# Third-party notices

| Component | Use | License |
|---|---|---|
| Ultralytics YOLOv8 (`yolov8s-oiv7.pt` weights, export code) | The detector in `entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms` is a pruned and converted copy of the Ultralytics YOLOv8s Open Images V7 model. | AGPL-3.0 |
| Open Images V7 | Training data and class names of that model. | Annotations CC BY 4.0, images CC BY 2.0 |
| MindSpore Lite 2.7.0 | Runtime (HarmonyOS `@kit.MindSporeLiteKit`) and offline converter used to build the `.ms` file. | Apache-2.0 |
| HarmonyOS SDK kits | Camera Kit, Core Speech Kit, Accessibility Kit, ArkUI. | Huawei HarmonyOS SDK license |

The application source code is MIT licensed (see `LICENSE`). The bundled model file is a derivative of AGPL-3.0 weights and stays under AGPL-3.0; its complete source (export and conversion scripts) is in `tools/model/`.
