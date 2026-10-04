import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { describeError, log } from '../common/Logger';

const CPU_THREADS: number = 4;
const CPU_PRECISION: string = 'preferred_fp16';

function cpuDevice(): mindSporeLite.CpuDevice {
  return { threadNum: CPU_THREADS, precisionMode: CPU_PRECISION };
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

function isUsable(model: mindSporeLite.Model | null | undefined): boolean {
  if (model === null || model === undefined) {
    return false;
  }
  try {
    const inputs = model.getInputs();
    return inputs !== null && inputs !== undefined && inputs.length > 0 &&
      inputs.every((tensor: mindSporeLite.MSTensor) => tensor !== null && tensor !== undefined &&
        tensor.shape !== null && tensor.shape !== undefined && tensor.shape.length > 0);
  } catch (error) {
    return false;
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
    if (!isUsable(model)) {
      log(`model ${fileName} loaded on NNRt accelerator ${accelerator.deviceName()} without usable inputs, using CPU`);
      return undefined;
    }
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
  log(`model ${fileName} on CPU (${CPU_PRECISION})`);
  return model;
}
