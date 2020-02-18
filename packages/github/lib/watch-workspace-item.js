import {CompositeDisposable} from 'atom';

import URIPattern from './atom/uri-pattern';

class ItemWatcher {
  constructor(workspace, pattern, component, stateKey) {
    this.workspace = workspace;
    this.pattern = pattern instanceof URIPattern ? pattern : new URIPattern(pattern);
    this.component = component;
    this.stateKey = stateKey;

    this.activeItem = this.isActiveItem();
    this.subs = new CompositeDisposable();
  }

  isActiveItem() {
    for (const pane of this.workspace.getPanes()) {
      if (this.itemMatches(pane.getActiveItem())) {
        return true;
      }
    }
    return false;
  }

  setInitialState() {
    if (!this.component.state) {
      this.component.state = {};
    }
    this.component.state[this.stateKey] = this.activeItem;
    return this;
  }

  subscribeToWorkspace() {
    this.subs.dispose();
    this.subs = new CompositeDisposable(
      this.workspace.getCenter().onDidChangeActivePaneItem(this.updateActiveState),
    );
    return this;
  }

  updateActiveState = () => {
    const wasActive = this.activeItem;

    this.activeItem = this.isActiveItem();
    // Update the component's state if it's changed as a result
    if (wasActive && !this.activeItem) {
      return new Promise(resolve => this.component.setState({[this.stateKey]: false}, resolve));
    } else if (!wasActive && this.activeItem) {
      return new Promise(resolve => this.component.setState({[this.stateKey]: true}, resolve));
    } else {
      return Promise.resolve();
    }
  }

  setPattern(pattern) {
    this.pattern = pattern instanceof URIPattern ? pattern : new URIPattern(pattern);

    return this.updateActiveState();
  }

  itemMatches = item => item && item.getURI && this.pattern.matches(item.getURI()).ok()

  dispose() {
    this.subs.dispose();
  }
}

export function watchWorkspaceItem(workspace, pattern, component, stateKey) {
  return new ItemWatcher(workspace, pattern, component, stateKey)
    .setInitialState()
    .subscribeToWorkspace();
}
