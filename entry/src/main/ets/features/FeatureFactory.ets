import { ColorFeature } from './ColorFeature';
import { DescribeFeature } from './DescribeFeature';
import { Feature, FeatureServices } from './Feature';
import { FindFeature } from './FindFeature';
import { FindWordFeature } from './FindWordFeature';
import { LightFeature } from './LightFeature';
import { ReadFeature } from './ReadFeature';

export interface FeatureBinding {
  feature: Feature;
  setTarget: (target: string) => void;
}

function plain(feature: Feature): FeatureBinding {
  return { feature: feature, setTarget: (target: string): void => {} };
}

export function createFeature(id: string, services: FeatureServices): FeatureBinding {
  if (id === 'find') {
    const find = new FindFeature(services);
    return { feature: find, setTarget: (target: string): void => find.setTarget(target) };
  }
  if (id === 'findword') {
    const findWord = new FindWordFeature(services);
    return { feature: findWord, setTarget: (target: string): void => findWord.setTarget(target) };
  }
  if (id === 'read') {
    return plain(new ReadFeature(services));
  }
  if (id === 'light') {
    return plain(new LightFeature(services));
  }
  if (id === 'color') {
    return plain(new ColorFeature(services));
  }
  return plain(new DescribeFeature(services));
}
