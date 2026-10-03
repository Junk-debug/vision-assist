import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';

const CPU_THREADS: number = 4;

export async function loadModel(context: common.UIAbilityContext, fileName: string): Promise<mindSporeLite.Model> {
  const bytes = await context.resourceManager.getRawFileContent(fileName);
  const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  const cpu: mindSporeLite.CpuDevice = { threadNum: CPU_THREADS };
  const modelContext: mindSporeLite.Context = { target: ['cpu'], cpu: cpu };
  return await mindSporeLite.loadModelFromBuffer(buffer, modelContext);
}
