# Model pipeline

The app ships one detector: **YOLOv8s trained on Open Images V7**, pruned to 194 everyday classes and converted to MindSpore Lite (`entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms`, input `[1,640,640,3]` NHWC float32, output `[1,198,8400]` channels first: `cx, cy, w, h` in input pixels followed by 194 sigmoid class scores).

You only need this folder to rebuild the model. The committed `.ms` file is what the app uses.

## Why a pruned model

The full model has 601 classes. Scanning 601 x 8400 scores in ArkTS cost about 255 ms per frame on the emulator. Keeping only the classes that matter for the app (people, personal items, household objects, furniture, clothing, food, street objects) cut the post-processing to about 60 ms. The kept scores are bit-identical to the full model.

The kept class indices are in `keep_indices.json`, their names (same order as the output channels) in `classes_subset.json`. `classes_oiv7_full.json` lists all 601 names.

## Rebuild

Requirements: Python 3.12, Docker (Apple silicon uses qemu because the converter only ships for Linux x86-64).

1. Export to ONNX. The script patches the DFL layer (softmax-sum instead of a conv that the converter cannot infer) and prunes the class head:

   ```sh
   python3.12 -m venv venv && . venv/bin/activate
   pip install ultralytics onnx onnxruntime onnxslim
   python export_subset.py yolov8s-oiv7.pt 640 yolov8s-oiv7-640-sub.onnx keep_indices.json
   ```

   `yolov8s-oiv7.pt` is downloaded by Ultralytics (`YOLO("yolov8s-oiv7.pt")`) or from the Ultralytics assets release.

2. Download the MindSpore Lite 2.7.0 Linux x86-64 release into `msl/` and extract it so that `msl/mindspore-lite-2.7.0-linux-x64/tools/converter` exists:
   `https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.0/MindSporeLite/lite/release/linux/x86_64/mindspore-lite-2.7.0-linux-x64.tar.gz`

3. Export an amd64 root file system for qemu (Rosetta crashes because the converter needs AVX):

   ```sh
   docker create --platform linux/amd64 --name amd64fs ubuntu:22.04
   mkdir amd64root && docker export amd64fs | tar -x -C amd64root
   docker rm amd64fs
   ```

   If `amd64root/usr/lib64/ld-linux-x86-64.so.2` is an absolute symlink, make it relative.

4. Convert:

   ```sh
   ./convert_to_ms.sh yolov8s-oiv7-640-sub.onnx yolov8s_oiv7_640_sub
   ```

5. Copy `yolov8s_oiv7_640_sub.ms` and `classes_subset.json` (as `classes.json`) into `entry/src/main/resources/rawfile/`.

## Findings that shaped the choice

- Open-vocabulary detectors (YOLO-World, YOLOE, OWLv2) did not detect keys at all (0 of 12 web photos, 0 on a real key photo). YOLOE found wallets best (0.77 to 0.88 on a real photo) but missed watches and coins.
- This Open Images model detects phones, watches, coins, glasses, bottles and cups well. It has no key or wallet class.
- The Ultralytics weights are licensed AGPL-3.0, see `NOTICE.md`.
