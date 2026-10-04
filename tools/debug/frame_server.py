#!/usr/bin/env python3
import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 8766
HOST = "127.0.0.1"
CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
}
DESCRIPTION = (
    "Serve still images or image sequences as camera frames for the debug 'frames' build. "
    "The device reads GET /frame through `hdc rport tcp:8766 tcp:8766`."
)
EDGE_POSITIONS = {"left": (0.1, 0.5), "right": (0.9, 0.5), "top": (0.5, 0.1), "bottom": (0.5, 0.9)}


def is_image(path):
    return os.path.splitext(path)[1].lower() in CONTENT_TYPES


def expand_paths(paths):
    files = []
    for path in paths:
        path = os.path.abspath(os.path.expanduser(path))
        if os.path.isdir(path):
            files.extend(os.path.join(path, name) for name in sorted(os.listdir(path)) if is_image(name))
        elif os.path.isfile(path) and is_image(path):
            files.append(path)
        else:
            raise ValueError(f"not an image or folder of images: {path}")
    if not files:
        raise ValueError("no images found")
    return files


class Sequence:
    def __init__(self, files, fps=1.0, loop=True, started_at=0.0):
        if not files:
            raise ValueError("a sequence needs at least one image")
        if fps <= 0:
            raise ValueError("fps must be positive")
        self.files = list(files)
        self.fps = float(fps)
        self.loop = bool(loop)
        self.started_at = float(started_at)

    def index_at(self, now):
        if len(self.files) == 1:
            return 0
        step = max(0, int(math.floor((now - self.started_at) * self.fps + 1e-9)))
        if self.loop:
            return step % len(self.files)
        return min(step, len(self.files) - 1)

    def file_at(self, now):
        return self.files[self.index_at(now)]

    def describe(self, now):
        index = self.index_at(now)
        return {
            "frames": len(self.files),
            "index": index,
            "file": self.files[index],
            "fps": self.fps,
            "loop": self.loop,
        }


class FrameState:
    def __init__(self, sequence=None):
        self.lock = threading.Lock()
        self.sequence = sequence
        self.served = 0

    def set(self, sequence):
        with self.lock:
            self.sequence = sequence

    def count_served(self):
        with self.lock:
            self.served += 1

    def current(self, now):
        with self.lock:
            if self.sequence is None:
                return None
            return self.sequence.describe(now)


def pan_windows(width, height, steps, start, start_zoom, end_zoom):
    if steps < 2:
        raise ValueError("steps must be at least 2")
    start_x, start_y = EDGE_POSITIONS[start]
    centre_x = width / 2.0
    centre_y = height / 2.0
    windows = []
    for step in range(steps):
        t = step / (steps - 1)
        zoom = start_zoom + (end_zoom - start_zoom) * t
        crop_w = max(1, int(round(width * zoom)))
        crop_h = max(1, int(round(height * zoom)))
        rel_x = start_x + (0.5 - start_x) * t
        rel_y = start_y + (0.5 - start_y) * t
        left = int(round(min(max(centre_x - rel_x * crop_w, 0), width - crop_w)))
        top = int(round(min(max(centre_y - rel_y * crop_h, 0), height - crop_h)))
        windows.append((left, top, crop_w, crop_h))
    return windows


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            if self.path != "/frame":
                sys.stderr.write("%s\n" % (fmt % args))

        def send_json(self, code, body):
            data = json.dumps(body).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def read_json(self):
            length = int(self.headers.get("Content-Length", "0"))
            return json.loads(self.rfile.read(length) or b"{}")

        def do_GET(self):
            if self.path == "/frame":
                self.send_frame()
            elif self.path == "/status":
                self.send_json(200, {"current": state.current(time.time()), "served": state.served})
            else:
                self.send_json(404, {"error": "unknown path"})

        def send_frame(self):
            current = state.current(time.time())
            if current is None:
                self.send_json(404, {"error": "no frame set"})
                return
            path = current["file"]
            try:
                with open(path, "rb") as source:
                    data = source.read()
            except OSError as error:
                self.send_json(404, {"error": str(error)})
                return
            state.count_served()
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPES[os.path.splitext(path)[1].lower()])
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Frame-Index", str(current["index"]))
            self.send_header("X-Frame-Name", os.path.basename(path))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            try:
                body = self.read_json()
                if self.path == "/show":
                    files = expand_paths([body["path"]])[:1]
                    state.set(Sequence(files))
                elif self.path == "/play":
                    files = expand_paths(body["paths"])
                    state.set(Sequence(files, body.get("fps", 1.0), body.get("loop", True), time.time()))
                else:
                    self.send_json(404, {"error": "unknown path"})
                    return
            except (KeyError, ValueError, json.JSONDecodeError) as error:
                self.send_json(400, {"error": str(error)})
                return
            self.send_json(200, {"current": state.current(time.time())})

    return Handler


def control(port, path, body=None):
    url = f"http://{HOST}:{port}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, method="GET" if body is None else "POST")
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            print(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        print(error.read().decode("utf-8"), file=sys.stderr)
        return 1
    except urllib.error.URLError as error:
        print(f"frame server not reachable on port {port}: {error.reason}", file=sys.stderr)
        return 1
    return 0


def image_size(path):
    try:
        from PIL import Image
        with Image.open(path) as picture:
            return picture.size
    except ImportError:
        pass
    output = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
                            check=True, capture_output=True, text=True).stdout
    values = {}
    for line in output.splitlines():
        parts = line.strip().split(":")
        if len(parts) == 2 and parts[0] in ("pixelWidth", "pixelHeight"):
            values[parts[0]] = int(parts[1])
    return values["pixelWidth"], values["pixelHeight"]


def crop_to(path, window, max_side, out_path):
    left, top, crop_w, crop_h = window
    try:
        from PIL import Image
        with Image.open(path) as picture:
            frame = picture.convert("RGB").crop((left, top, left + crop_w, top + crop_h))
            frame.thumbnail((max_side, max_side))
            frame.save(out_path, "JPEG", quality=90)
        return
    except ImportError:
        pass
    if shutil.which("sips") is None:
        raise RuntimeError("pan needs Pillow (pip install Pillow) or macOS sips")
    subprocess.run(["sips", "-s", "format", "jpeg", "-c", str(crop_h), str(crop_w),
                    "--cropOffset", str(top), str(left), "-Z", str(max_side), path, "--out", out_path],
                   check=True, capture_output=True)


def command_serve(args):
    state = FrameState()
    if args.paths:
        state.set(Sequence(expand_paths(args.paths), args.fps, not args.once, time.time()))
    server = ThreadingHTTPServer((HOST, args.port), make_handler(state))
    current = state.current(time.time())
    print(f"frame server on http://{HOST}:{args.port}/frame, "
          f"{current['frames'] if current else 0} frame(s); device side: "
          f"hdc -t 127.0.0.1:5555 rport tcp:{DEFAULT_PORT} tcp:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


def command_pan(args):
    width, height = image_size(args.image)
    os.makedirs(args.out, exist_ok=True)
    windows = pan_windows(width, height, args.steps, args.start, args.zoom, args.end_zoom)
    for index, window in enumerate(windows):
        crop_to(args.image, window, args.max_side, os.path.join(args.out, f"frame_{index:03d}.jpg"))
    print(f"wrote {len(windows)} frames to {args.out}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    commands = parser.add_subparsers(dest="command", required=True)

    serve = commands.add_parser("serve", help="run the frame server (images or folders, played in order)")
    serve.add_argument("paths", nargs="*")
    serve.add_argument("--fps", type=float, default=1.0)
    serve.add_argument("--once", action="store_true", help="stop on the last frame instead of looping")

    show = commands.add_parser("show", help="show one image on a running server")
    show.add_argument("path")

    play = commands.add_parser("play", help="play images or folders in order on a running server")
    play.add_argument("paths", nargs="+")
    play.add_argument("--fps", type=float, default=1.0)
    play.add_argument("--once", action="store_true", help="stop on the last frame instead of looping")

    commands.add_parser("status", help="print the current frame of a running server")

    pan = commands.add_parser("pan", help="write a sequence that moves the centre of an image from an edge to the middle")
    pan.add_argument("image", help="photo with the object in its centre")
    pan.add_argument("--out", required=True)
    pan.add_argument("--steps", type=int, default=12)
    pan.add_argument("--start", choices=sorted(EDGE_POSITIONS), default="left")
    pan.add_argument("--zoom", type=float, default=0.5, help="crop size as a share of the image at the start")
    pan.add_argument("--end-zoom", type=float, default=0.35, help="crop size at the end; smaller means closer")
    pan.add_argument("--max-side", type=int, default=960)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if args.command == "serve":
            return command_serve(args)
        if args.command == "pan":
            return command_pan(args)
        if args.command == "show":
            return control(args.port, "/show", {"path": os.path.abspath(os.path.expanduser(args.path))})
        if args.command == "play":
            paths = [os.path.abspath(os.path.expanduser(path)) for path in args.paths]
            return control(args.port, "/play", {"paths": paths, "fps": args.fps, "loop": not args.once})
        return control(args.port, "/status")
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
