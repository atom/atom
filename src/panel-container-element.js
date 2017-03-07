const {CompositeDisposable} = require('event-kit');

class PanelContainerElement extends HTMLElement {
  createdCallback() {
    return this.subscriptions = new CompositeDisposable;
  }

  initialize(model, {views}) {
    this.model = model;
    this.views = views;
    if (this.views == null) { throw new Error("Must pass a views parameter when initializing PanelContainerElements"); }

    this.subscriptions.add(this.model.onDidAddPanel(this.panelAdded.bind(this)));
    this.subscriptions.add(this.model.onDidDestroy(this.destroyed.bind(this)));
    this.classList.add(this.model.getLocation());
    return this;
  }

  getModel() { return this.model; }

  panelAdded({panel, index}) {
    const panelElement = this.views.getView(panel);
    panelElement.classList.add(this.model.getLocation());
    if (this.model.isModal()) {
      panelElement.classList.add("overlay", "from-top");
    } else {
      panelElement.classList.add("tool-panel", `panel-${this.model.getLocation()}`);
    }

    if (index >= this.childNodes.length) {
      this.appendChild(panelElement);
    } else {
      const referenceItem = this.childNodes[index];
      this.insertBefore(panelElement, referenceItem);
    }

    if (this.model.isModal()) {
      this.hideAllPanelsExcept(panel);
      return this.subscriptions.add(panel.onDidChangeVisible(visible => {
        if (visible) { return this.hideAllPanelsExcept(panel); }
      }
      )
      );
    }
  }

  destroyed() {
    this.subscriptions.dispose();
    return (this.parentNode != null ? this.parentNode.removeChild(this) : undefined);
  }

  hideAllPanelsExcept(excludedPanel) {
    for (let panel of this.model.getPanels()) {
      if (panel !== excludedPanel) { panel.hide(); }
    }
  }
}

module.exports = PanelContainerElement = document.registerElement('atom-panel-container', {prototype: PanelContainerElement.prototype});
