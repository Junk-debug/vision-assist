import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { PHOTO_MAX_SIDE } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { fitWithin, orientationDegrees } from './PhotoMath';

async function readOrientation(source: image.ImageSource): Promise<number> {
  try {
    return orientationDegrees(await source.getImageProperty(image.PropertyKey.ORIENTATION));
  } catch (error) {
    return 0;
  }
}

export async function loadPhoto(uri: string): Promise<image.PixelMap | undefined> {
  let file: fileIo.File | undefined = undefined;
  let source: image.ImageSource | undefined = undefined;
  try {
    file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    source = image.createImageSource(file.fd);
    const info = await source.getImageInfo();
    const size = fitWithin(info.size.width, info.size.height, PHOTO_MAX_SIDE);
    const rotation = await readOrientation(source);
    const pixels = await source.createPixelMap({
      desiredSize: size,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    if (rotation !== 0) {
      await pixels.rotate(rotation);
    }
    return pixels;
  } catch (error) {
    log(`photo decode failed ${describeError(error)}`);
    return undefined;
  } finally {
    if (source !== undefined) {
      await source.release();
    }
    if (file !== undefined) {
      try {
        await fileIo.close(file);
      } catch (error) {
        log(`photo file close failed ${describeError(error)}`);
      }
    }
  }
}
