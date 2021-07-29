const { CompositeDisposable } = require('event-kit');
require('./pane-resize-handle-element');

class PaneAxisElement extends HTMLElement {
  connectedCallback() {
    if (this.subscriptions == null) {
      this.subscriptions = this.subscribeToModel();
    }
    this.model
      .getChildren()
      .map((child, index) => this.childAdded({ child, index }));
  }

  disconnectedCallback() {
    this.subscriptions.dispose();
    this.subscriptions = null;
    this.model.getChildren().map(child => this.childRemoved({ child }));
  }

  initialize(model, viewRegistry) {
    this.model = model;
    this.viewRegistry = viewRegistry;
    if (this.subscriptions == null) {
      this.subscriptions = this.subscribeToModel();
    }
    const iterable = this.model.getChildren();
    for (let index = 0; index < iterable.length; index++) {
      const child = iterable[index];
      this.childAdded({ child, index });
    }

    switch (this.model.getOrientation()) {
      case 'horizontal':
        this.classList.add('horizontal', 'pane-row');
        break;
      case 'vertical':
        this.classList.add('vertical', 'pane-column');
        break;
    }
    return this;
  }

  subscribeToModel() {
    const subscriptions = new CompositeDisposable();
    subscriptions.add(this.model.onDidAddChild(this.childAdded.bind(this)));
    subscriptions.add(
      this.model.onDidRemoveChild(this.childRemoved.bind(this))
    );
    subscriptions.add(
      this.model.onDidReplaceChild(this.childReplaced.bind(this))
    );
    subscriptions.add(
      this.model.observeFlexScale(this.flexScaleChanged.bind(this))
    );
    return subscriptions;
  }

  isPaneResizeHandleElement(element) {
    return (
      (element != null ? element.nodeName.toLowerCase() : undefined) ===
      'atom-pane-resize-handle'
    );
  }

  childAdded({ child, index }) {
    let resizeHandle;
    const view = this.viewRegistry.getView(child);
    this.insertBefore(view, this.children[index * 2]);

    const prevElement = view.previousSibling;
    // if previous element is not pane resize element, then insert new resize element
    if (prevElement != null && !this.isPaneResizeHandleElement(prevElement)) {
      resizeHandle = document.createElement('atom-pane-resize-handle');
      this.insertBefore(resizeHandle, view);
    }

    const nextElement = view.nextSibling;
    // if next element isnot resize element, then insert new resize element
    if (nextElement != null && !this.isPaneResizeHandleElement(nextElement)) {
      resizeHandle = document.createElement('atom-pane-resize-handle');
      return this.insertBefore(resizeHandle, nextElement);
    }
  }

  childRemoved({ child }) {
    const view = this.viewRegistry.getView(child);
    const siblingView = view.previousSibling;
    // make sure next sibling view is pane resize view
    if (siblingView != null && this.isPaneResizeHandleElement(siblingView)) {
      siblingView.remove();
    }
    return view.remove();
  }

  childReplaced({ index, oldChild, newChild }) {
    let focusedElement;
    if (this.hasFocus()) {
      focusedElement = document.activeElement;
    }
    this.childRemoved({ child: oldChild, index });
    this.childAdded({ child: newChild, index });
    if (document.activeElement === document.body) {
      return focusedElement != null ? focusedElement.focus() : undefined;
    }
  }

  flexScaleChanged(flexScale) {
    this.style.flexGrow = flexScale;
  }

  hasFocus() {
    return (
      this === document.activeElement || this.contains(document.activeElement)
    );
  }
}

window.customElements.define('atom-pane-axis', PaneAxisElement);

function createPaneAxisElement() {
  return document.createElement('atom-pane-axis');
}

module.exports = {
  createPaneAxisElement
};
