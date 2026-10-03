import { common } from '@kit.AbilityKit';
import { appServices } from '../app/AppServices';
import { Palette } from '../ui/theme/Theme';
import { FeaturePage } from './FeaturePage';
import { HomePage } from './HomePage';

const FEATURE_ROUTE: string = 'feature';

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    appServices.init(this.getUIContext().getHostContext() as common.UIAbilityContext);
  }

  aboutToDisappear(): void {
    appServices.release();
  }

  @Builder
  routes(name: string, param: Object) {
    if (name === FEATURE_ROUTE) {
      FeaturePage({ featureId: param as string })
    }
  }

  build() {
    Navigation(this.pathStack) {
      HomePage({
        onOpen: (id: string) => {
          this.pathStack.pushPathByName(FEATURE_ROUTE, id);
        }
      })
    }
    .navDestination(this.routes)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .backgroundColor(Palette.page)
  }
}
