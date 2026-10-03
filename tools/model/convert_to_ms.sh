#!/bin/sh
set -e

if [ "$#" -lt 2 ]; then
  echo "usage: convert_to_ms.sh <model.onnx> <output-name-without-extension>" >&2
  exit 1
fi

MODEL=$1
OUTPUT=$2
shift 2

CONVERTER_ROOT=/w/msl/mindspore-lite-2.7.0-linux-x64/tools/converter
LIB_PATH=$CONVERTER_ROOT/lib

docker run --rm --platform linux/arm64 -v "$PWD":/w -w /w ubuntu:24.04 sh -c "
  apt-get update -qq >/dev/null &&
  apt-get install -y -qq qemu-user >/dev/null 2>&1 &&
  export QEMU_LD_PREFIX=/w/amd64root &&
  export LD_LIBRARY_PATH=$LIB_PATH &&
  qemu-x86_64 -cpu max -L /w/amd64root -E LD_LIBRARY_PATH=$LIB_PATH \
    $CONVERTER_ROOT/converter/converter_lite --fmk=ONNX --modelFile=/w/$MODEL --outputFile=/w/$OUTPUT $*
"
