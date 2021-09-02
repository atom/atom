const { CompositeDisposable } = require('event-kit');

class PaneContainerElement extends HTMLElement {
  constructor() {
    super();
    this.subscriptions = new CompositeDisposable();
  }

  initialize(model, { views }) {
    this.model = model;
    this.views = views;
    if (this.views == null) {
      throw new Error(
        'Must pass a views parameter when initializing PaneContainerElements'
      );
    }
    this.subscriptions.add(this.model.observeRoot(this.rootChanged.bind(this)));
    return this;
  }

  connectedCallback() {
    this.classList.add('panes');
  }

  rootChanged(root) {
    const focusedElement = this.hasFocus() ? document.activeElement : null;
    if (this.firstChild != null) {
      this.firstChild.remove();
    }
    if (root != null) {
      const view = this.views.getView(root);
      this.appendChild(view);
      if (focusedElement != null) {
        focusedElement.focus();
      }
    }
  }

  hasFocus() {
    return (
      this === document.activeElement || this.contains(document.activeElement)
    );
  }
}

window.customElements.define('atom-pane-container', PaneContainerElement);

function createPaneContainerElement() {
  return document.createElement('atom-pane-container');
}

module.exports = {
  createPaneContainerElement
};
