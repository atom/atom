const { Emitter, CompositeDisposable } = require('event-kit');

class StylesElement extends HTMLElement {
  constructor() {
    super();
    this.subscriptions = null;
    this.context = null;
  }

  onDidAddStyleElement(callback) {
    this.emitter.on('did-add-style-element', callback);
  }

  onDidRemoveStyleElement(callback) {
    this.emitter.on('did-remove-style-element', callback);
  }

  onDidUpdateStyleElement(callback) {
    this.emitter.on('did-update-style-element', callback);
  }

  createdCallback() {
    this.subscriptions = new CompositeDisposable();
    this.emitter = new Emitter();
    this.styleElementClonesByOriginalElement = new WeakMap();
  }

  attachedCallback() {
    let left;
    this.context =
      (left = this.getAttribute('context')) != null ? left : undefined;
  }

  detachedCallback() {
    this.subscriptions.dispose();
    this.subscriptions = new CompositeDisposable();
  }

  attributeChangedCallback(attrName) {
    if (attrName === 'context') {
      return this.contextChanged();
    }
  }

  initialize(styleManager) {
    this.styleManager = styleManager;
    if (this.styleManager == null) {
      throw new Error(
        'Must pass a styleManager parameter when initializing a StylesElement'
      );
    }

    this.subscriptions.add(
      this.styleManager.observeStyleElements(this.styleElementAdded.bind(this))
    );
    this.subscriptions.add(
      this.styleManager.onDidRemoveStyleElement(
        this.styleElementRemoved.bind(this)
      )
    );
    return this.subscriptions.add(
      this.styleManager.onDidUpdateStyleElement(
        this.styleElementUpdated.bind(this)
      )
    );
  }

  contextChanged() {
    if (this.subscriptions == null) {
      return;
    }

    for (let child of Array.from(Array.prototype.slice.call(this.children))) {
      this.styleElementRemoved(child);
    }
    this.context = this.getAttribute('context');
    for (let styleElement of Array.from(this.styleManager.getStyleElements())) {
      this.styleElementAdded(styleElement);
    }
  }

  styleElementAdded(styleElement) {
    let insertBefore;
    if (!this.styleElementMatchesContext(styleElement)) {
      return;
    }

    const styleElementClone = styleElement.cloneNode(true);
    styleElementClone.sourcePath = styleElement.sourcePath;
    styleElementClone.context = styleElement.context;
    styleElementClone.priority = styleElement.priority;
    this.styleElementClonesByOriginalElement.set(
      styleElement,
      styleElementClone
    );

    const { priority } = styleElement;
    if (priority != null) {
      for (let child of this.children) {
        if (child.priority > priority) {
          insertBefore = child;
          break;
        }
      }
    }

    this.insertBefore(styleElementClone, insertBefore);
    this.emitter.emit('did-add-style-element', styleElementClone);
  }

  styleElementRemoved(styleElement) {
    let left;
    if (!this.styleElementMatchesContext(styleElement)) {
      return;
    }

    const styleElementClone =
      (left = this.styleElementClonesByOriginalElement.get(styleElement)) !=
      null
        ? left
        : styleElement;
    styleElementClone.remove();
    this.emitter.emit('did-remove-style-element', styleElementClone);
  }

  styleElementUpdated(styleElement) {
    if (!this.styleElementMatchesContext(styleElement)) {
      return;
    }

    const styleElementClone = this.styleElementClonesByOriginalElement.get(
      styleElement
    );
    styleElementClone.textContent = styleElement.textContent;
    this.emitter.emit('did-update-style-element', styleElementClone);
  }

  styleElementMatchesContext(styleElement) {
    return this.context == null || styleElement.context === this.context;
  }
}

module.exports = document.registerElement('atom-styles', {
  prototype: StylesElement.prototype
});
