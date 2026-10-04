import { common } from '@kit.AbilityKit';
import { appServices } from '../app/AppServices';
import { Palette } from '../ui/theme/Theme';
import { FullTextParams, Routes } from '../app/Routes';
import { FeaturePage } from './FeaturePage';
import { FullTextPage } from './FullTextPage';
import { HomePage } from './HomePage';

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
    if (name === Routes.FEATURE) {
      FeaturePage({ featureId: param as string })
    } else if (name === Routes.FULL_TEXT) {
      FullTextPage({ params: param as FullTextParams })
    }
  }

  build() {
    Navigation(this.pathStack) {
      HomePage({
        onOpen: (id: string) => {
          this.pathStack.pushPathByName(Routes.FEATURE, id);
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
