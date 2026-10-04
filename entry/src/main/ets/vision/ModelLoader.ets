import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { describeError, log } from '../common/Logger';

const CPU_THREADS: number = 4;

function cpuDevice(): mindSporeLite.CpuDevice {
  return { threadNum: CPU_THREADS };
}

function findAccelerator(): mindSporeLite.NNRTDeviceDescription | undefined {
  try {
    const devices = mindSporeLite.getAllNNRTDeviceDescriptions();
    if (devices === null || devices === undefined) {
      return undefined;
    }
    return devices.find((device: mindSporeLite.NNRTDeviceDescription) =>
      device.deviceType() === mindSporeLite.NNRTDeviceType.NNRTDEVICE_ACCELERATOR);
  } catch (error) {
    log(`NNRt device query failed ${describeError(error)}`);
    return undefined;
  }
}

async function loadOnAccelerator(buffer: ArrayBuffer, fileName: string): Promise<mindSporeLite.Model | undefined> {
  const accelerator = findAccelerator();
  if (accelerator === undefined) {
    return undefined;
  }
  const nnrt: mindSporeLite.NNRTDevice = {
    deviceID: accelerator.deviceID(),
    performanceMode: mindSporeLite.PerformanceMode.PERFORMANCE_HIGH
  };
  const modelContext: mindSporeLite.Context = { target: ['nnrt', 'cpu'], nnrt: nnrt, cpu: cpuDevice() };
  try {
    const model = await mindSporeLite.loadModelFromBuffer(buffer, modelContext);
    log(`model ${fileName} on NNRt accelerator ${accelerator.deviceName()} with CPU fallback`);
    return model;
  } catch (error) {
    log(`model ${fileName} could not use NNRt accelerator ${accelerator.deviceName()}, using CPU ${describeError(error)}`);
    return undefined;
  }
}

export async function loadModel(context: common.UIAbilityContext, fileName: string): Promise<mindSporeLite.Model> {
  const bytes = await context.resourceManager.getRawFileContent(fileName);
  const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  const accelerated = await loadOnAccelerator(buffer, fileName);
  if (accelerated !== undefined) {
    return accelerated;
  }
  const modelContext: mindSporeLite.Context = { target: ['cpu'], cpu: cpuDevice() };
  const model = await mindSporeLite.loadModelFromBuffer(buffer, modelContext);
  log(`model ${fileName} on CPU`);
  return model;
}
