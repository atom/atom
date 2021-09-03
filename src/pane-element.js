const path = require('path');
const { CompositeDisposable } = require('event-kit');

class PaneElement extends HTMLElement {
  constructor() {
    super();
    this.attached = false;
    this.subscriptions = new CompositeDisposable();
    this.inlineDisplayStyles = new WeakMap();
    this.subscribeToDOMEvents();
    this.itemViews = document.createElement('div');
  }

  connectedCallback() {
    this.initializeContent();
    this.attached = true;
    if (this.model.isFocused()) {
      this.focus();
    }
  }

  detachedCallback() {
    this.attached = false;
  }

  initializeContent() {
    this.setAttribute('class', 'pane');
    this.setAttribute('tabindex', -1);
    this.appendChild(this.itemViews);
    this.itemViews.setAttribute('class', 'item-views');
  }

  subscribeToDOMEvents() {
    const handleFocus = event => {
      if (
        !(
          this.isActivating ||
          this.model.isDestroyed() ||
          this.contains(event.relatedTarget)
        )
      ) {
        this.model.focus();
      }
      if (event.target !== this) return;
      const view = this.getActiveView();
      if (view) {
        view.focus();
        event.stopPropagation();
      }
    };
    const handleBlur = event => {
      if (!this.contains(event.relatedTarget)) {
        this.model.blur();
      }
    };
    const handleDragOver = event => {
      event.preventDefault();
      event.stopPropagation();
    };
    const handleDrop = event => {
      event.preventDefault();
      event.stopPropagation();
      this.getModel().activate();
      const pathsToOpen = [...event.dataTransfer.files].map(file => file.path);
      if (pathsToOpen.length > 0) {
        this.applicationDelegate.open({ pathsToOpen, here: true });
      }
    };
    this.addEventListener('focus', handleFocus, { capture: true });
    this.addEventListener('blur', handleBlur, { capture: true });
    this.addEventListener('dragover', handleDragOver);
    this.addEventListener('drop', handleDrop);
  }

  initialize(model, { views, applicationDelegate }) {
    this.model = model;
    this.views = views;
    this.applicationDelegate = applicationDelegate;
    if (this.views == null) {
      throw new Error(
        'Must pass a views parameter when initializing PaneElements'
      );
    }
    if (this.applicationDelegate == null) {
      throw new Error(
        'Must pass an applicationDelegate parameter when initializing PaneElements'
      );
    }
    this.subscriptions.add(this.model.onDidActivate(this.activated.bind(this)));
    this.subscriptions.add(
      this.model.observeActive(this.activeStatusChanged.bind(this))
    );
    this.subscriptions.add(
      this.model.observeActiveItem(this.activeItemChanged.bind(this))
    );
    this.subscriptions.add(
      this.model.onDidRemoveItem(this.itemRemoved.bind(this))
    );
    this.subscriptions.add(
      this.model.onDidDestroy(this.paneDestroyed.bind(this))
    );
    this.subscriptions.add(
      this.model.observeFlexScale(this.flexScaleChanged.bind(this))
    );
    return this;
  }

  getModel() {
    return this.model;
  }

  activated() {
    this.isActivating = true;
    if (!this.hasFocus()) {
      // Don't steal focus from children.
      this.focus();
    }
    this.isActivating = false;
  }

  activeStatusChanged(active) {
    if (active) {
      this.classList.add('active');
    } else {
      this.classList.remove('active');
    }
  }

  activeItemChanged(item) {
    delete this.dataset.activeItemName;
    delete this.dataset.activeItemPath;
    if (this.changePathDisposable != null) {
      this.changePathDisposable.dispose();
    }
    if (item == null) {
      return;
    }
    const hasFocus = this.hasFocus();
    const itemView = this.views.getView(item);
    const itemPath = typeof item.getPath === 'function' ? item.getPath() : null;
    if (itemPath) {
      this.dataset.activeItemName = path.basename(itemPath);
      this.dataset.activeItemPath = itemPath;
      if (item.onDidChangePath != null) {
        this.changePathDisposable = item.onDidChangePath(() => {
          const itemPath = item.getPath();
          this.dataset.activeItemName = path.basename(itemPath);
          this.dataset.activeItemPath = itemPath;
        });
      }
    }

    if (!this.itemViews.contains(itemView)) {
      this.itemViews.appendChild(itemView);
    }
    for (const child of this.itemViews.children) {
      if (child === itemView) {
        if (this.attached) {
          this.showItemView(child);
        }
      } else {
        this.hideItemView(child);
      }
    }
    if (hasFocus) {
      itemView.focus();
    }
  }

  showItemView(itemView) {
    const inlineDisplayStyle = this.inlineDisplayStyles.get(itemView);
    if (inlineDisplayStyle != null) {
      itemView.style.display = inlineDisplayStyle;
    } else {
      itemView.style.display = '';
    }
  }

  hideItemView(itemView) {
    const inlineDisplayStyle = itemView.style.display;
    if (inlineDisplayStyle !== 'none') {
      if (inlineDisplayStyle != null) {
        this.inlineDisplayStyles.set(itemView, inlineDisplayStyle);
      }
      itemView.style.display = 'none';
    }
  }

  itemRemoved({ item, index, destroyed }) {
    const viewToRemove = this.views.getView(item);
    if (viewToRemove) {
      viewToRemove.remove();
    }
  }

  paneDestroyed() {
    this.subscriptions.dispose();
    if (this.changePathDisposable != null) {
      this.changePathDisposable.dispose();
    }
  }

  flexScaleChanged(flexScale) {
    this.style.flexGrow = flexScale;
  }

  getActiveView() {
    return this.views.getView(this.model.getActiveItem());
  }

  hasFocus() {
    return (
      this === document.activeElement || this.contains(document.activeElement)
    );
  }
}

function createPaneElement() {
  return document.createElement('atom-pane');
}

window.customElements.define('atom-pane', PaneElement);

module.exports = {
  createPaneElement
};
