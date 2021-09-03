'use strict';

const { Emitter, CompositeDisposable } = require('event-kit');
const { createPanelContainerElement } = require('./panel-container-element');

module.exports = class PanelContainer {
  constructor({ location, dock, viewRegistry } = {}) {
    this.location = location;
    this.emitter = new Emitter();
    this.subscriptions = new CompositeDisposable();
    this.panels = [];
    this.dock = dock;
    this.viewRegistry = viewRegistry;
  }

  destroy() {
    for (let panel of this.getPanels()) {
      panel.destroy();
    }
    this.subscriptions.dispose();
    this.emitter.emit('did-destroy', this);
    this.emitter.dispose();
  }

  getElement() {
    if (!this.element) {
      this.element = createPanelContainerElement().initialize(
        this,
        this.viewRegistry
      );
    }
    return this.element;
  }

  /*
  Section: Event Subscription
  */

  onDidAddPanel(callback) {
    return this.emitter.on('did-add-panel', callback);
  }

  onDidRemovePanel(callback) {
    return this.emitter.on('did-remove-panel', callback);
  }

  onDidDestroy(callback) {
    return this.emitter.once('did-destroy', callback);
  }

  /*
  Section: Panels
  */

  getLocation() {
    return this.location;
  }

  isModal() {
    return this.location === 'modal';
  }

  getPanels() {
    return this.panels.slice();
  }

  addPanel(panel) {
    this.subscriptions.add(panel.onDidDestroy(this.panelDestroyed.bind(this)));

    const index = this.getPanelIndex(panel);
    if (index === this.panels.length) {
      this.panels.push(panel);
    } else {
      this.panels.splice(index, 0, panel);
    }

    this.emitter.emit('did-add-panel', { panel, index });
    return panel;
  }

  panelForItem(item) {
    for (let panel of this.panels) {
      if (panel.getItem() === item) {
        return panel;
      }
    }
    return null;
  }

  panelDestroyed(panel) {
    const index = this.panels.indexOf(panel);
    if (index > -1) {
      this.panels.splice(index, 1);
      this.emitter.emit('did-remove-panel', { panel, index });
    }
  }

  getPanelIndex(panel) {
    const priority = panel.getPriority();
    if (['bottom', 'right'].includes(this.location)) {
      for (let i = this.panels.length - 1; i >= 0; i--) {
        const p = this.panels[i];
        if (priority < p.getPriority()) {
          return i + 1;
        }
      }
      return 0;
    } else {
      for (let i = 0; i < this.panels.length; i++) {
        const p = this.panels[i];
        if (priority < p.getPriority()) {
          return i;
        }
      }
      return this.panels.length;
    }
  }
};
