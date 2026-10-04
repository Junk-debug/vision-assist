import { PhotoAnalyzer } from '../features/Feature';
import { describeError, log } from '../common/Logger';
import { loadPhoto } from './PhotoLoader';
import { containRect } from './PhotoMath';

export async function analyzePhotoUri(uri: string, analyzer: PhotoAnalyzer): Promise<boolean> {
  const photo = await loadPhoto(uri);
  if (photo === undefined) {
    return false;
  }
  try {
    const info = await photo.getImageInfo();
    await analyzer.analyzePhoto(photo, containRect(info.size.width, info.size.height));
    return true;
  } catch (error) {
    log(`photo analysis failed ${describeError(error)}`);
    return false;
  } finally {
    photo.release();
  }
}
