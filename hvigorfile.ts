import { appTasks, OhosAppContext, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { getNode, hvigor, HvigorNode } from '@ohos/hvigor';

const FRAMES_PRODUCT: string = 'frames';
const FRAMES_MODULE: string = 'entry';
const DEBUG_MODE: string = 'debug';
const INTERNET_PERMISSION: string = 'ohos.permission.INTERNET';

hvigor.nodesEvaluated(() => {
  const appNode: HvigorNode = getNode(__filename);
  const appContext = appNode.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
  if (appContext.getCurrentProduct().getProductName() !== FRAMES_PRODUCT) {
    return;
  }
  if (appContext.getBuildMode() !== DEBUG_MODE) {
    throw new Error(`The ${FRAMES_PRODUCT} product feeds camera frames over the network and is debug only. Build it with buildMode ${DEBUG_MODE}.`);
  }
  appNode.subNodes((node: HvigorNode) => {
    const hapContext = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext | undefined;
    if (hapContext === undefined || hapContext.getModuleName() !== FRAMES_MODULE) {
      return;
    }
    const moduleJson = hapContext.getModuleJsonOpt();
    const permissions = moduleJson.module.requestPermissions ?? [];
    if (!permissions.some((permission) => permission.name === INTERNET_PERMISSION)) {
      permissions.push({ name: INTERNET_PERMISSION });
    }
    moduleJson.module.requestPermissions = permissions;
    hapContext.setModuleJsonOpt(moduleJson);
  });
});

export default {
  system: appTasks,
  plugins: []
}
