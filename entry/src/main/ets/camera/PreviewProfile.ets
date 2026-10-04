import { camera } from '@kit.CameraKit';

const TARGET_WIDTH: number = 1280;
const TARGET_HEIGHT: number = 720;

function distance(profile: camera.Profile): number {
  const longSide = Math.max(profile.size.width, profile.size.height);
  const shortSide = Math.min(profile.size.width, profile.size.height);
  return Math.abs(longSide - TARGET_WIDTH) + Math.abs(shortSide - TARGET_HEIGHT);
}

function closest(profiles: camera.Profile[]): camera.Profile | undefined {
  let best: camera.Profile | undefined = undefined;
  for (const profile of profiles) {
    if (best === undefined || distance(profile) < distance(best)) {
      best = profile;
    }
  }
  return best;
}

export function choosePreviewProfile(profiles: camera.Profile[]): camera.Profile {
  const rgba = closest(profiles.filter((p: camera.Profile) => p.format === camera.CameraFormat.CAMERA_FORMAT_RGBA_8888));
  if (rgba !== undefined) {
    return rgba;
  }
  const yuv = closest(profiles.filter((p: camera.Profile) => p.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP));
  if (yuv !== undefined) {
    return yuv;
  }
  return closest(profiles) ?? profiles[0];
}

export function isYuv(profile: camera.Profile): boolean {
  return profile.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP;
}
