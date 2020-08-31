const { CompositeDisposable } = require('event-kit');

class PaneContainerElement extends HTMLElement {
  createdCallback() {
    this.subscriptions = new CompositeDisposable();
    this.classList.add('panes');
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

module.exports = document.registerElement('atom-pane-container', {
  prototype: PaneContainerElement.prototype
});
