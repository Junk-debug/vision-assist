import { photoAccessHelper } from '@kit.MediaLibraryKit';

export async function pickPhoto(): Promise<string> {
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 1;
  const picker = new photoAccessHelper.PhotoViewPicker();
  const result = await picker.select(options);
  return result.photoUris.length > 0 ? result.photoUris[0] : '';
}
