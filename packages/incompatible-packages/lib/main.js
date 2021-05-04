/** @babel */

import { Disposable, CompositeDisposable } from 'atom';
import VIEW_URI from './view-uri';

let disposables = null;

export function activate() {
  disposables = new CompositeDisposable();

  disposables.add(
    atom.workspace.addOpener(uri => {
      if (uri === VIEW_URI) {
        return deserializeIncompatiblePackagesComponent();
      }
    })
  );

  disposables.add(
    atom.commands.add('atom-workspace', {
      'incompatible-packages:view': () => {
        atom.workspace.open(VIEW_URI);
      }
    })
  );
}

export function deactivate() {
  disposables.dispose();
}

export function consumeStatusBar(statusBar) {
  let incompatibleCount = 0;
  for (let pack of atom.packages.getLoadedPackages()) {
    if (!pack.isCompatible()) incompatibleCount++;
  }

  if (incompatibleCount > 0) {
    let icon = createIcon(incompatibleCount);
    let tile = statusBar.addRightTile({ item: icon, priority: 200 });
    icon.element.addEventListener('click', () => {
      atom.commands.dispatch(icon.element, 'incompatible-packages:view');
    });
    disposables.add(new Disposable(() => tile.destroy()));
  }
}

export function deserializeIncompatiblePackagesComponent() {
  const IncompatiblePackagesComponent = require('./incompatible-packages-component');
  return new IncompatiblePackagesComponent(atom.packages);
}

function createIcon(count) {
  const StatusIconComponent = require('./status-icon-component');
  return new StatusIconComponent({ count });
}
