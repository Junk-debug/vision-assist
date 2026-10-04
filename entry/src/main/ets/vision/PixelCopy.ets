import { image } from '@kit.ImageKit';

export async function copyPixelMap(source: image.PixelMap): Promise<image.PixelMap> {
  const info = await source.getImageInfo();
  const buffer = new ArrayBuffer(source.getPixelBytesNumber());
  await source.readPixelsToBuffer(buffer);
  const options: image.InitializationOptions = {
    size: { width: info.size.width, height: info.size.height },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    alphaType: image.AlphaType.OPAQUE,
    editable: true
  };
  return image.createPixelMap(buffer, options);
}
