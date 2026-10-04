import { connection } from '@kit.NetworkKit';
import { describeError, log } from '../common/Logger';
import { Sam3Detector } from './Sam3Detector';

export enum EngineKind {
  CLOUD,
  DEVICE
}

export enum EngineMode {
  AUTO,
  DEVICE_ONLY
}

export type EngineListener = () => void;

// After a failed cloud request Find stays on the device for this long before trying the cloud again.
const CLOUD_RETRY_MS: number = 20000;

function hasValidatedNet(capabilities: connection.NetCapabilities | undefined): boolean {
  const caps = capabilities?.networkCap ?? [];
  return caps.includes(connection.NetCap.NET_CAPABILITY_INTERNET) &&
    caps.includes(connection.NetCap.NET_CAPABILITY_VALIDATED);
}

// Chooses the Find detector: SAM 3 in the cloud when the phone is online and the key is set,
// the on-device model otherwise or right after the cloud failed.
export class FindEngine {
  private readonly cloud: Sam3Detector;
  private mode: EngineMode = EngineMode.AUTO;
  private online: boolean = false;
  private cloudFailedAt: number = -CLOUD_RETRY_MS;
  private netConnection?: connection.NetConnection;
  private listeners: EngineListener[] = [];
  private lastKind: EngineKind = EngineKind.DEVICE;

  constructor(cloud: Sam3Detector) {
    this.cloud = cloud;
  }

  start(): void {
    this.online = this.checkOnline();
    try {
      const net = connection.createNetConnection();
      net.on('netCapabilitiesChange', (data: connection.NetCapabilityInfo) => {
        this.setOnline(hasValidatedNet(data.netCap));
      });
      net.on('netLost', () => {
        this.setOnline(this.checkOnline());
      });
      net.on('netUnavailable', () => {
        this.setOnline(false);
      });
      net.register((error) => {
        if (error) {
          log(`network watch failed ${describeError(error)}`);
        }
      });
      this.netConnection = net;
    } catch (error) {
      log(`network watch failed ${describeError(error)}`);
    }
    log(`find engine online ${this.online}, key ${this.cloud.isReady()}`);
  }

  stop(): void {
    this.netConnection?.unregister(() => {});
    this.netConnection = undefined;
  }

  current(now: number): EngineKind {
    const kind = this.cloudUsable(now) ? EngineKind.CLOUD : EngineKind.DEVICE;
    if (kind !== this.lastKind) {
      this.lastKind = kind;
      this.notify();
    }
    return kind;
  }

  getMode(): EngineMode {
    return this.mode;
  }

  hasCloud(): boolean {
    return this.cloud.isReady();
  }

  toggleMode(): void {
    this.mode = this.mode === EngineMode.AUTO ? EngineMode.DEVICE_ONLY : EngineMode.AUTO;
    this.cloudFailedAt = -CLOUD_RETRY_MS;
    this.notify();
  }

  reportCloudFailure(now: number): void {
    this.cloudFailedAt = now;
    this.notify();
  }

  // Short label for the engine chip, for example "Cloud search" or "On-device · offline".
  label(now: number): string {
    if (this.current(now) === EngineKind.CLOUD) {
      return 'Cloud search';
    }
    return `On-device · ${this.deviceReason(now)}`;
  }

  deviceReason(now: number): string {
    if (this.mode === EngineMode.DEVICE_ONLY) {
      return 'chosen';
    }
    if (!this.cloud.isReady()) {
      return 'no cloud key';
    }
    if (!this.online) {
      return 'offline';
    }
    return now - this.cloudFailedAt < CLOUD_RETRY_MS ? 'cloud unreachable' : 'ready';
  }

  addListener(listener: EngineListener): void {
    this.listeners.push(listener);
  }

  removeListener(listener: EngineListener): void {
    this.listeners = this.listeners.filter((item: EngineListener) => item !== listener);
  }

  private cloudUsable(now: number): boolean {
    return this.mode === EngineMode.AUTO && this.cloud.isReady() && this.online &&
      now - this.cloudFailedAt >= CLOUD_RETRY_MS;
  }

  private checkOnline(): boolean {
    try {
      const handle = connection.getDefaultNetSync();
      if (handle.netId === 0) {
        return false;
      }
      return hasValidatedNet(connection.getNetCapabilitiesSync(handle));
    } catch (error) {
      log(`network check failed ${describeError(error)}`);
      return false;
    }
  }

  private setOnline(online: boolean): void {
    if (online === this.online) {
      return;
    }
    this.online = online;
    if (online) {
      this.cloudFailedAt = -CLOUD_RETRY_MS;
    }
    log(`find engine online ${online}`);
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) {
      listener();
    }
  }
}
