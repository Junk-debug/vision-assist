import { ColorFeature } from './ColorFeature';
import { DescribeFeature } from './DescribeFeature';
import { Feature, FeatureServices, PhotoAnalyzer } from './Feature';
import { FindFeature } from './FindFeature';
import { FindWordFeature } from './FindWordFeature';
import { LightFeature } from './LightFeature';
import { ReadFeature } from './ReadFeature';

export interface FeatureBinding {
  feature: Feature;
  setTarget: (target: string) => void;
  photo?: PhotoAnalyzer;
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
    const read = new ReadFeature(services);
    return { feature: read, setTarget: (target: string): void => {}, photo: read };
  }
  if (id === 'light') {
    return plain(new LightFeature(services));
  }
  if (id === 'color') {
    return plain(new ColorFeature(services));
  }
  const describe = new DescribeFeature(services);
  return { feature: describe, setTarget: (target: string): void => {}, photo: describe };
}
