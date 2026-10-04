# Third-party notices

| Component | Use | License |
|---|---|---|
| Ultralytics YOLOv8 (`yolov8s-oiv7.pt` weights, export code) | The detector in `entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms` is a pruned and converted copy of the Ultralytics YOLOv8s Open Images V7 model. | AGPL-3.0 |
| Open Images V7 | Training data and class names of that model. | Annotations CC BY 4.0, images CC BY 2.0 |
| MindSpore Lite 2.7.0 | Runtime (HarmonyOS `@kit.MindSporeLiteKit`) and offline converter used to build the `.ms` file. | Apache-2.0 |
| PaddleOCR PP-OCRv4 mobile text detector (`ch_PP-OCRv4_det_mobile`) | `entry/src/main/resources/rawfile/ocr_det.ms`, converted from the RapidOCR ONNX export to MindSpore Lite with static 640x640 input. | Apache-2.0 |
| PaddleOCR PP-OCRv4 English recognizer (`en_PP-OCRv4_rec_mobile`) and its dictionary | `entry/src/main/resources/rawfile/ocr_rec.ms` (HardSwish rewritten as `x * clip(x + 3, 0, 6) / 6` for the converter, numerically equivalent) and `ocr_dict.txt`. | Apache-2.0 |
| RapidOCR ONNX exports | Source of both OCR models: `https://www.modelscope.cn/models/RapidAI/RapidOCR` (`onnx/PP-OCRv4/det/ch_PP-OCRv4_det_mobile.onnx`, `onnx/PP-OCRv4/rec/en_PP-OCRv4_rec_mobile.onnx`, `paddle/PP-OCRv4/rec/en_PP-OCRv4_rec_mobile/en_dict.txt`). | Apache-2.0 |
| HarmonyOS SDK kits | Camera Kit, Core Vision Kit, Core Speech Kit, Accessibility Kit, Sensor Service Kit, Media Library Kit, Image Kit, MindSpore Lite Kit, ArkUI. | Huawei HarmonyOS SDK license |

The application source code is MIT licensed (see `LICENSE`). The bundled detector model file is a derivative of AGPL-3.0 weights and stays under AGPL-3.0; its complete source (export and conversion scripts) is in `tools/model/`.

The OCR model files are derivatives of Apache-2.0 models and stay under Apache-2.0.
