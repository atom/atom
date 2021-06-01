const etch = require('etch');
const _ = require('underscore-plus');
const { CompositeDisposable, Emitter } = require('event-kit');
const PaneContainer = require('./pane-container');
const TextEditor = require('./text-editor');
const Grim = require('grim');

const $ = etch.dom;
const MINIMUM_SIZE = 100;
const DEFAULT_INITIAL_SIZE = 300;
const SHOULD_ANIMATE_CLASS = 'atom-dock-should-animate';
const VISIBLE_CLASS = 'atom-dock-open';
const RESIZE_HANDLE_RESIZABLE_CLASS = 'atom-dock-resize-handle-resizable';
const TOGGLE_BUTTON_VISIBLE_CLASS = 'atom-dock-toggle-button-visible';
const CURSOR_OVERLAY_VISIBLE_CLASS = 'atom-dock-cursor-overlay-visible';

// Extended: A container at the edges of the editor window capable of holding items.
// You should not create a Dock directly. Instead, access one of the three docks of the workspace
// via {Workspace::getLeftDock}, {Workspace::getRightDock}, and {Workspace::getBottomDock}
// or add an item to a dock via {Workspace::open}.
module.exports = class Dock {
  constructor(params) {
    this.handleResizeHandleDragStart = this.handleResizeHandleDragStart.bind(
      this
    );
    this.handleResizeToFit = this.handleResizeToFit.bind(this);
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleDrag = _.throttle(this.handleDrag.bind(this), 30);
    this.handleDragEnd = this.handleDragEnd.bind(this);
    this.handleToggleButtonDragEnter = this.handleToggleButtonDragEnter.bind(
      this
    );
    this.toggle = this.toggle.bind(this);

    this.location = params.location;
    this.widthOrHeight = getWidthOrHeight(this.location);
    this.config = params.config;
    this.applicationDelegate = params.applicationDelegate;
    this.deserializerManager = params.deserializerManager;
    this.notificationManager = params.notificationManager;
    this.viewRegistry = params.viewRegistry;
    this.didActivate = params.didActivate;

    this.emitter = new Emitter();

    this.paneContainer = new PaneContainer({
      location: this.location,
      config: this.config,
      applicationDelegate: this.applicationDelegate,
      deserializerManager: this.deserializerManager,
      notificationManager: this.notificationManager,
      viewRegistry: this.viewRegistry
    });

    this.state = {
      size: null,
      visible: false,
      shouldAnimate: false
    };

    this.subscriptions = new CompositeDisposable(
      this.emitter,
      this.paneContainer.onDidActivatePane(() => {
        this.show();
        this.didActivate(this);
      }),
      this.paneContainer.observePanes(pane => {
        pane.onDidAddItem(this.handleDidAddPaneItem.bind(this));
        pane.onDidRemoveItem(this.handleDidRemovePaneItem.bind(this));
      }),
      this.paneContainer.onDidChangeActivePane(item =>
        params.didChangeActivePane(this, item)
      ),
      this.paneContainer.onDidChangeActivePaneItem(item =>
        params.didChangeActivePaneItem(this, item)
      ),
      this.paneContainer.onDidDestroyPaneItem(item =>
        params.didDestroyPaneItem(item)
      )
    );
  }

  // This method is called explicitly by the object which adds the Dock to the document.
  elementAttached() {
    // Re-render when the dock is attached to make sure we remeasure sizes defined in CSS.
    etch.updateSync(this);
  }

  getElement() {
    // Because this code is included in the snapshot, we have to make sure we don't touch the DOM
    // during initialization. Therefore, we defer initialization of the component (which creates a
    // DOM element) until somebody asks for the element.
    if (this.element == null) {
      etch.initialize(this);
    }
    return this.element;
  }

  getLocation() {
    return this.location;
  }

  destroy() {
    this.subscriptions.dispose();
    this.paneContainer.destroy();
    window.removeEventListener('mousemove', this.handleMouseMove);
    window.removeEventListener('mouseup', this.handleMouseUp);
    window.removeEventListener('drag', this.handleDrag);
    window.removeEventListener('dragend', this.handleDragEnd);
  }

  setHovered(hovered) {
    if (hovered === this.state.hovered) return;
    this.setState({ hovered });
  }

  setDraggingItem(draggingItem) {
    if (draggingItem === this.state.draggingItem) return;
    this.setState({ draggingItem });
  }

  // Extended: Show the dock and focus its active {Pane}.
  activate() {
    this.getActivePane().activate();
  }

  // Extended: Show the dock without focusing it.
  show() {
    this.setState({ visible: true });
  }

  // Extended: Hide the dock and activate the {WorkspaceCenter} if the dock was
  // was previously focused.
  hide() {
    this.setState({ visible: false });
  }

  // Extended: Toggle the dock's visibility without changing the {Workspace}'s
  // active pane container.
  toggle() {
    const state = { visible: !this.state.visible };
    if (!state.visible) state.hovered = false;
    this.setState(state);
  }

  // Extended: Check if the dock is visible.
  //
  // Returns a {Boolean}.
  isVisible() {
    return this.state.visible;
  }

  setState(newState) {
    const prevState = this.state;
    const nextState = Object.assign({}, prevState, newState);

    // Update the `shouldAnimate` state. This needs to be written to the DOM before updating the
    // class that changes the animated property. Normally we'd have to defer the class change a
    // frame to ensure the property is animated (or not) appropriately, however we luck out in this
    // case because the drag start always happens before the item is dragged into the toggle button.
    if (nextState.visible !== prevState.visible) {
      // Never animate toggling visibility...
      nextState.shouldAnimate = false;
    } else if (
      !nextState.visible &&
      nextState.draggingItem &&
      !prevState.draggingItem
    ) {
      // ...but do animate if you start dragging while the panel is hidden.
      nextState.shouldAnimate = true;
    }

    this.state = nextState;

    const { hovered, visible } = this.state;

    // Render immediately if the dock becomes visible or the size changes in case people are
    // measuring after opening, for example.
    if (this.element != null) {
      if ((visible && !prevState.visible) || this.state.size !== prevState.size)
        etch.updateSync(this);
      else etch.update(this);
    }

    if (hovered !== prevState.hovered) {
      this.emitter.emit('did-change-hovered', hovered);
    }
    if (visible !== prevState.visible) {
      this.emitter.emit('did-change-visible', visible);
    }
  }

  render() {
    const innerElementClassList = ['atom-dock-inner', this.location];
    if (this.state.visible) innerElementClassList.push(VISIBLE_CLASS);

    const maskElementClassList = ['atom-dock-mask'];
    if (this.state.shouldAnimate)
      maskElementClassList.push(SHOULD_ANIMATE_CLASS);

    const cursorOverlayElementClassList = [
      'atom-dock-cursor-overlay',
      this.location
    ];
    if (this.state.resizing)
      cursorOverlayElementClassList.push(CURSOR_OVERLAY_VISIBLE_CLASS);

    const shouldBeVisible = this.state.visible || this.state.showDropTarget;
    const size = Math.max(
      MINIMUM_SIZE,
      this.state.size ||
        (this.state.draggingItem &&
          getPreferredSize(this.state.draggingItem, this.location)) ||
        DEFAULT_INITIAL_SIZE
    );

    // We need to change the size of the mask...
    const maskStyle = {
      [this.widthOrHeight]: `${shouldBeVisible ? size : 0}px`
    };
    // ...but the content needs to maintain a constant size.
    const wrapperStyle = { [this.widthOrHeight]: `${size}px` };

    return $(
      'atom-dock',
      { className: this.location },
      $.div(
        { ref: 'innerElement', className: innerElementClassList.join(' ') },
        $.div(
          {
            className: maskElementClassList.join(' '),
            style: maskStyle
          },
          $.div(
            {
              ref: 'wrapperElement',
              className: `atom-dock-content-wrapper ${this.location}`,
              style: wrapperStyle
            },
            $(DockResizeHandle, {
              location: this.location,
              onResizeStart: this.handleResizeHandleDragStart,
              onResizeToFit: this.handleResizeToFit,
              dockIsVisible: this.state.visible
            }),
            $(ElementComponent, { element: this.paneContainer.getElement() }),
            $.div({ className: cursorOverlayElementClassList.join(' ') })
          )
        ),
        $(DockToggleButton, {
          ref: 'toggleButton',
          onDragEnter: this.state.draggingItem
            ? this.handleToggleButtonDragEnter
            : null,
          location: this.location,
          toggle: this.toggle,
          dockIsVisible: shouldBeVisible,
          visible:
            // Don't show the toggle button if the dock is closed and empty...
            (this.state.hovered &&
              (this.state.visible || this.getPaneItems().length > 0)) ||
            // ...or if the item can't be dropped in that dock.
            (!shouldBeVisible &&
              this.state.draggingItem &&
              isItemAllowed(this.state.draggingItem, this.location))
        })
      )
    );
  }

  update(props) {
    // Since we're interopping with non-etch stuff, this method's actually never called.
    return etch.update(this);
  }

  handleDidAddPaneItem() {
    if (this.state.size == null) {
      this.setState({ size: this.getInitialSize() });
    }
  }

  handleDidRemovePaneItem() {
    // Hide the dock if you remove the last item.
    if (this.paneContainer.getPaneItems().length === 0) {
      this.setState({ visible: false, hovered: false, size: null });
    }
  }

  handleResizeHandleDragStart() {
    window.addEventListener('mousemove', this.handleMouseMove);
    window.addEventListener('mouseup', this.handleMouseUp);
    this.setState({ resizing: true });
  }

  handleResizeToFit() {
    const item = this.getActivePaneItem();
    if (item) {
      const size = getPreferredSize(item, this.getLocation());
      if (size != null) this.setState({ size });
    }
  }

  handleMouseMove(event) {
    if (event.buttons === 0) {
      // We missed the mouseup event. For some reason it happens on Windows
      this.handleMouseUp(event);
      return;
    }

    let size = 0;
    switch (this.location) {
      case 'left':
        size = event.pageX - this.element.getBoundingClientRect().left;
        break;
      case 'bottom':
        size = this.element.getBoundingClientRect().bottom - event.pageY;
        break;
      case 'right':
        size = this.element.getBoundingClientRect().right - event.pageX;
        break;
    }
    this.setState({ size });
  }

  handleMouseUp(event) {
    window.removeEventListener('mousemove', this.handleMouseMove);
    window.removeEventListener('mouseup', this.handleMouseUp);
    this.setState({ resizing: false });
  }

  handleToggleButtonDragEnter() {
    this.setState({ showDropTarget: true });
    window.addEventListener('drag', this.handleDrag);
    window.addEventListener('dragend', this.handleDragEnd);
  }

  handleDrag(event) {
    if (!this.pointWithinHoverArea({ x: event.pageX, y: event.pageY }, true)) {
      this.draggedOut();
    }
  }

  handleDragEnd() {
    this.draggedOut();
  }

  draggedOut() {
    this.setState({ showDropTarget: false });
    window.removeEventListener('drag', this.handleDrag);
    window.removeEventListener('dragend', this.handleDragEnd);
  }

  // Determine whether the cursor is within the dock hover area. This isn't as simple as just using
  // mouseenter/leave because we want to be a little more forgiving. For example, if the cursor is
  // over the footer, we want to show the bottom dock's toggle button. Also note that our criteria
  // for detecting entry are different than detecting exit but, in order for us to avoid jitter, the
  // area considered when detecting exit MUST fully encompass the area considered when detecting
  // entry.
  pointWithinHoverArea(point, detectingExit) {
    const dockBounds = this.refs.innerElement.getBoundingClientRect();

    // Copy the bounds object since we can't mutate it.
    const bounds = {
      top: dockBounds.top,
      right: dockBounds.right,
      bottom: dockBounds.bottom,
      left: dockBounds.left
    };

    // To provide a minimum target, expand the area toward the center a bit.
    switch (this.location) {
      case 'right':
        bounds.left = Math.min(bounds.left, bounds.right - 2);
        break;
      case 'bottom':
        bounds.top = Math.min(bounds.top, bounds.bottom - 1);
        break;
      case 'left':
        bounds.right = Math.max(bounds.right, bounds.left + 2);
        break;
    }

    // Further expand the area to include all panels that are closer to the edge than the dock.
    switch (this.location) {
      case 'right':
        bounds.right = Number.POSITIVE_INFINITY;
        break;
      case 'bottom':
        bounds.bottom = Number.POSITIVE_INFINITY;
        break;
      case 'left':
        bounds.left = Number.NEGATIVE_INFINITY;
        break;
    }

    // If we're in this area, we know we're within the hover area without having to take further
    // measurements.
    if (rectContainsPoint(bounds, point)) return true;

    // If we're within the toggle button, we're definitely in the hover area. Unfortunately, we
    // can't do this measurement conditionally (e.g. only if the toggle button is visible) because
    // our knowledge of the toggle's button is incomplete due to CSS animations. (We may think the
    // toggle button isn't visible when in actuality it is, but is animating to its hidden state.)
    //
    // Since `point` is always the current mouse position, one possible optimization would be to
    // remove it as an argument and determine whether we're inside the toggle button using
    // mouseenter/leave events on it. This class would still need to keep track of the mouse
    // position (via a mousemove listener) for the other measurements, though.
    const toggleButtonBounds = this.refs.toggleButton.getBounds();
    if (rectContainsPoint(toggleButtonBounds, point)) return true;

    // The area used when detecting exit is actually larger than when detecting entrances. Expand
    // our bounds and recheck them.
    if (detectingExit) {
      const hoverMargin = 20;
      switch (this.location) {
        case 'right':
          bounds.left =
            Math.min(bounds.left, toggleButtonBounds.left) - hoverMargin;
          break;
        case 'bottom':
          bounds.top =
            Math.min(bounds.top, toggleButtonBounds.top) - hoverMargin;
          break;
        case 'left':
          bounds.right =
            Math.max(bounds.right, toggleButtonBounds.right) + hoverMargin;
          break;
      }
      if (rectContainsPoint(bounds, point)) return true;
    }

    return false;
  }

  getInitialSize() {
    // The item may not have been activated yet. If that's the case, just use the first item.
    const activePaneItem =
      this.paneContainer.getActivePaneItem() ||
      this.paneContainer.getPaneItems()[0];
    // If there are items, we should have an explicit width; if not, we shouldn't.
    return activePaneItem
      ? getPreferredSize(activePaneItem, this.location) || DEFAULT_INITIAL_SIZE
      : null;
  }

  serialize() {
    return {
      deserializer: 'Dock',
      size: this.state.size,
      paneContainer: this.paneContainer.serialize(),
      visible: this.state.visible
    };
  }

  deserialize(serialized, deserializerManager) {
    this.paneContainer.deserialize(
      serialized.paneContainer,
      deserializerManager
    );
    this.setState({
      size: serialized.size || this.getInitialSize(),
      // If no items could be deserialized, we don't want to show the dock (even if it was visible last time)
      visible:
        serialized.visible && this.paneContainer.getPaneItems().length > 0
    });
  }

  /*
  Section: Event Subscription
  */

  // Essential: Invoke the given callback when the visibility of the dock changes.
  //
  // * `callback` {Function} to be called when the visibility changes.
  //   * `visible` {Boolean} Is the dock now visible?
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible(callback) {
    return this.emitter.on('did-change-visible', callback);
  }

  // Essential: Invoke the given callback with the current and all future visibilities of the dock.
  //
  // * `callback` {Function} to be called when the visibility changes.
  //   * `visible` {Boolean} Is the dock now visible?
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeVisible(callback) {
    callback(this.isVisible());
    return this.onDidChangeVisible(callback);
  }

  // Essential: Invoke the given callback with all current and future panes items
  // in the dock.
  //
  // * `callback` {Function} to be called with current and future pane items.
  //   * `item` An item that is present in {::getPaneItems} at the time of
  //      subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePaneItems(callback) {
    return this.paneContainer.observePaneItems(callback);
  }

  // Essential: Invoke the given callback when the active pane item changes.
  //
  // Because observers are invoked synchronously, it's important not to perform
  // any expensive operations via this method. Consider
  // {::onDidStopChangingActivePaneItem} to delay operations until after changes
  // stop occurring.
  //
  // * `callback` {Function} to be called when the active pane item changes.
  //   * `item` The active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePaneItem(callback) {
    return this.paneContainer.onDidChangeActivePaneItem(callback);
  }

  // Essential: Invoke the given callback when the active pane item stops
  // changing.
  //
  // Observers are called asynchronously 100ms after the last active pane item
  // change. Handling changes here rather than in the synchronous
  // {::onDidChangeActivePaneItem} prevents unneeded work if the user is quickly
  // changing or closing tabs and ensures critical UI feedback, like changing the
  // highlighted tab, gets priority over work that can be done asynchronously.
  //
  // * `callback` {Function} to be called when the active pane item stopts
  //   changing.
  //   * `item` The active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidStopChangingActivePaneItem(callback) {
    return this.paneContainer.onDidStopChangingActivePaneItem(callback);
  }

  // Essential: Invoke the given callback with the current active pane item and
  // with all future active pane items in the dock.
  //
  // * `callback` {Function} to be called when the active pane item changes.
  //   * `item` The current active pane item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePaneItem(callback) {
    return this.paneContainer.observeActivePaneItem(callback);
  }

  // Extended: Invoke the given callback when a pane is added to the dock.
  //
  // * `callback` {Function} to be called panes are added.
  //   * `event` {Object} with the following keys:
  //     * `pane` The added pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPane(callback) {
    return this.paneContainer.onDidAddPane(callback);
  }

  // Extended: Invoke the given callback before a pane is destroyed in the
  // dock.
  //
  // * `callback` {Function} to be called before panes are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `pane` The pane to be destroyed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillDestroyPane(callback) {
    return this.paneContainer.onWillDestroyPane(callback);
  }

  // Extended: Invoke the given callback when a pane is destroyed in the dock.
  //
  // * `callback` {Function} to be called panes are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `pane` The destroyed pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroyPane(callback) {
    return this.paneContainer.onDidDestroyPane(callback);
  }

  // Extended: Invoke the given callback with all current and future panes in the
  // dock.
  //
  // * `callback` {Function} to be called with current and future panes.
  //   * `pane` A {Pane} that is present in {::getPanes} at the time of
  //      subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePanes(callback) {
    return this.paneContainer.observePanes(callback);
  }

  // Extended: Invoke the given callback when the active pane changes.
  //
  // * `callback` {Function} to be called when the active pane changes.
  //   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePane(callback) {
    return this.paneContainer.onDidChangeActivePane(callback);
  }

  // Extended: Invoke the given callback with the current active pane and when
  // the active pane changes.
  //
  // * `callback` {Function} to be called with the current and future active#
  //   panes.
  //   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePane(callback) {
    return this.paneContainer.observeActivePane(callback);
  }

  // Extended: Invoke the given callback when a pane item is added to the dock.
  //
  // * `callback` {Function} to be called when pane items are added.
  //   * `event` {Object} with the following keys:
  //     * `item` The added pane item.
  //     * `pane` {Pane} containing the added item.
  //     * `index` {Number} indicating the index of the added item in its pane.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPaneItem(callback) {
    return this.paneContainer.onDidAddPaneItem(callback);
  }

  // Extended: Invoke the given callback when a pane item is about to be
  // destroyed, before the user is prompted to save it.
  //
  // * `callback` {Function} to be called before pane items are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `item` The item to be destroyed.
  //     * `pane` {Pane} containing the item to be destroyed.
  //     * `index` {Number} indicating the index of the item to be destroyed in
  //       its pane.
  //
  // Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onWillDestroyPaneItem(callback) {
    return this.paneContainer.onWillDestroyPaneItem(callback);
  }

  // Extended: Invoke the given callback when a pane item is destroyed.
  //
  // * `callback` {Function} to be called when pane items are destroyed.
  //   * `event` {Object} with the following keys:
  //     * `item` The destroyed item.
  //     * `pane` {Pane} containing the destroyed item.
  //     * `index` {Number} indicating the index of the destroyed item in its
  //       pane.
  //
  // Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onDidDestroyPaneItem(callback) {
    return this.paneContainer.onDidDestroyPaneItem(callback);
  }

  // Extended: Invoke the given callback when the hovered state of the dock changes.
  //
  // * `callback` {Function} to be called when the hovered state changes.
  //   * `hovered` {Boolean} Is the dock now hovered?
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeHovered(callback) {
    return this.emitter.on('did-change-hovered', callback);
  }

  /*
  Section: Pane Items
  */

  // Essential: Get all pane items in the dock.
  //
  // Returns an {Array} of items.
  getPaneItems() {
    return this.paneContainer.getPaneItems();
  }

  // Essential: Get the active {Pane}'s active item.
  //
  // Returns an pane item {Object}.
  getActivePaneItem() {
    return this.paneContainer.getActivePaneItem();
  }

  // Deprecated: Get the active item if it is a {TextEditor}.
  //
  // Returns a {TextEditor} or `undefined` if the current active item is not a
  // {TextEditor}.
  getActiveTextEditor() {
    Grim.deprecate(
      'Text editors are not allowed in docks. Use atom.workspace.getActiveTextEditor() instead.'
    );

    const activeItem = this.getActivePaneItem();
    if (activeItem instanceof TextEditor) {
      return activeItem;
    }
  }

  // Save all pane items.
  saveAll() {
    this.paneContainer.saveAll();
  }

  confirmClose(options) {
    return this.paneContainer.confirmClose(options);
  }

  /*
  Section: Panes
  */

  // Extended: Get all panes in the dock.
  //
  // Returns an {Array} of {Pane}s.
  getPanes() {
    return this.paneContainer.getPanes();
  }

  // Extended: Get the active {Pane}.
  //
  // Returns a {Pane}.
  getActivePane() {
    return this.paneContainer.getActivePane();
  }

  // Extended: Make the next pane active.
  activateNextPane() {
    return this.paneContainer.activateNextPane();
  }

  // Extended: Make the previous pane active.
  activatePreviousPane() {
    return this.paneContainer.activatePreviousPane();
  }

  paneForURI(uri) {
    return this.paneContainer.paneForURI(uri);
  }

  paneForItem(item) {
    return this.paneContainer.paneForItem(item);
  }

  // Destroy (close) the active pane.
  destroyActivePane() {
    const activePane = this.getActivePane();
    if (activePane != null) {
      activePane.destroy();
    }
  }
};

class DockResizeHandle {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
  }

  render() {
    const classList = ['atom-dock-resize-handle', this.props.location];
    if (this.props.dockIsVisible) classList.push(RESIZE_HANDLE_RESIZABLE_CLASS);

    return $.div({
      className: classList.join(' '),
      on: { mousedown: this.handleMouseDown }
    });
  }

  getElement() {
    return this.element;
  }

  getSize() {
    if (!this.size) {
      this.size = this.element.getBoundingClientRect()[
        getWidthOrHeight(this.props.location)
      ];
    }
    return this.size;
  }

  update(newProps) {
    this.props = Object.assign({}, this.props, newProps);
    return etch.update(this);
  }

  handleMouseDown(event) {
    if (event.detail === 2) {
      this.props.onResizeToFit();
    } else if (this.props.dockIsVisible) {
      this.props.onResizeStart();
    }
  }
}

class DockToggleButton {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
  }

  render() {
    const classList = ['atom-dock-toggle-button', this.props.location];
    if (this.props.visible) classList.push(TOGGLE_BUTTON_VISIBLE_CLASS);

    return $.div(
      { className: classList.join(' ') },
      $.div(
        {
          ref: 'innerElement',
          className: `atom-dock-toggle-button-inner ${this.props.location}`,
          on: {
            click: this.handleClick,
            dragenter: this.props.onDragEnter
          }
        },
        $.span({
          ref: 'iconElement',
          className: `icon ${getIconName(
            this.props.location,
            this.props.dockIsVisible
          )}`
        })
      )
    );
  }

  getElement() {
    return this.element;
  }

  getBounds() {
    return this.refs.innerElement.getBoundingClientRect();
  }

  update(newProps) {
    this.props = Object.assign({}, this.props, newProps);
    return etch.update(this);
  }

  handleClick() {
    this.props.toggle();
  }
}

// An etch component that doesn't use etch, this component provides a gateway from JSX back into
// the mutable DOM world.
class ElementComponent {
  constructor(props) {
    this.element = props.element;
  }

  update(props) {
    this.element = props.element;
  }
}

function getWidthOrHeight(location) {
  return location === 'left' || location === 'right' ? 'width' : 'height';
}

function getPreferredSize(item, location) {
  switch (location) {
    case 'left':
    case 'right':
      return typeof item.getPreferredWidth === 'function'
        ? item.getPreferredWidth()
        : null;
    default:
      return typeof item.getPreferredHeight === 'function'
        ? item.getPreferredHeight()
        : null;
  }
}

function getIconName(location, visible) {
  switch (location) {
    case 'right':
      return visible ? 'icon-chevron-right' : 'icon-chevron-left';
    case 'bottom':
      return visible ? 'icon-chevron-down' : 'icon-chevron-up';
    case 'left':
      return visible ? 'icon-chevron-left' : 'icon-chevron-right';
    default:
      throw new Error(`Invalid location: ${location}`);
  }
}

function rectContainsPoint(rect, point) {
  return (
    point.x >= rect.left &&
    point.y >= rect.top &&
    point.x <= rect.right &&
    point.y <= rect.bottom
  );
}

// Is the item allowed in the given location?
function isItemAllowed(item, location) {
  if (typeof item.getAllowedLocations !== 'function') return true;
  return item.getAllowedLocations().includes(location);
}
