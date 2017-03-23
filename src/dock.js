'use strict'

const _ = require('underscore-plus')
const {CompositeDisposable} = require('event-kit')
const PaneContainer = require('./pane-container')
const TextEditor = require('./text-editor')

const MINIMUM_SIZE = 100
const DEFAULT_INITIAL_SIZE = 300
const HANDLE_SIZE = 4
const SHOULD_ANIMATE_CLASS = 'atom-dock-should-animate'
const OPEN_CLASS = 'atom-dock-open'
const RESIZE_HANDLE_RESIZABLE_CLASS = 'atom-dock-resize-handle-resizable'
const TOGGLE_BUTTON_VISIBLE_CLASS = 'atom-dock-toggle-button-visible'
const CURSOR_OVERLAY_VISIBLE_CLASS = 'atom-dock-cursor-overlay-visible'

// Extended: A container at the edges of the editor window capable of holding items.
// You should not create a Dock directly. Instead, access one of the three docks of the workspace
// via {::getLeftDock}, {::getRightDock}, and {::getBottomDock} or add an item to a dock via
// {Workspace::open}.
module.exports = class Dock {
  constructor (params) {
    this.handleResizeHandleDragStart = this.handleResizeHandleDragStart.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseUp = this.handleMouseUp.bind(this)
    this.handleDrag = _.throttle(this.handleDrag.bind(this), 30)
    this.handleDragEnd = this.handleDragEnd.bind(this)

    this.location = params.location
    this.widthOrHeight = getWidthOrHeight(this.location)
    this.config = params.config
    this.applicationDelegate = params.applicationDelegate
    this.deserializerManager = params.deserializerManager
    this.notificationManager = params.notificationManager
    this.viewRegistry = params.viewRegistry

    this.paneContainer = new PaneContainer({
      config: this.config,
      applicationDelegate: this.applicationDelegate,
      deserializerManager: this.deserializerManager,
      notificationManager: this.notificationManager,
      viewRegistry: this.viewRegistry
    })

    this.state = {
      open: false,
      shouldAnimate: false
    }

    this.subscriptions = new CompositeDisposable(
      this.paneContainer.observePanes(pane => {
        pane.onDidAddItem(this.handleDidAddPaneItem.bind(this))
      }),
      this.paneContainer.observePanes(pane => {
        pane.onDidRemoveItem(this.handleDidRemovePaneItem.bind(this))
      })
    )

    this.render(this.state)
  }

  getElement () {
    return this.element
  }

  getLocation () {
    return this.location
  }

  destroy () {
    this.subscriptions.dispose()
    this.paneContainer.destroy()
    this.resizeHandle.destroy()
    this.toggleButton.destroy()
    window.removeEventListener('mousemove', this.handleMouseMove)
    window.removeEventListener('mouseup', this.handleMouseUp)
    window.removeEventListener('drag', this.handleDrag)
    window.removeEventListener('dragend', this.handleDragEnd)
  }

  setHovered (hovered) {
    if (hovered === this.state.hovered) return
    this.setState({hovered})
  }

  setDraggingItem (draggingItem) {
    if (draggingItem === this.state.draggingItem) return
    this.setState({draggingItem})
  }

  activate () {
    this.setState({open: true})
  }

  hide () {
    this.setState({open: false})
  }

  toggle () {
    this.setState({open: !this.state.open})
  }

  isOpen () {
    return this.state.open
  }

  setState (newState) {
    const prevState = this.state
    const nextState = Object.assign({}, prevState, newState)

    // Update the `shouldAnimate` state. This needs to be written to the DOM before updating the
    // class that changes the animated property. Normally we'd have to defer the class change a
    // frame to ensure the property is animated (or not) appropriately, however we luck out in this
    // case because the drag start always happens before the item is dragged into the toggle button.
    if (nextState.open !== prevState.open) {
      // Never animate toggling visiblity...
      nextState.shouldAnimate = false
    } else if (!nextState.open && nextState.draggingItem && !prevState.draggingItem) {
      // ...but do animate if you start dragging while the panel is hidden.
      nextState.shouldAnimate = true
    }

    this.state = nextState
    this.render(this.state)
  }

  render (state) {
    if (this.element == null) {
      this.element = document.createElement('atom-dock')
      this.element.classList.add(this.location)
      this.innerElement = document.createElement('div')
      this.innerElement.classList.add('atom-dock-inner', this.location)
      this.maskElement = document.createElement('div')
      this.maskElement.classList.add('atom-dock-mask')
      this.wrapperElement = document.createElement('div')
      this.wrapperElement.classList.add('atom-dock-content-wrapper', this.location)
      this.resizeHandle = new DockResizeHandle({
        location: this.location,
        onResizeStart: this.handleResizeHandleDragStart,
        toggle: this.toggle.bind(this)
      })
      this.toggleButton = new DockToggleButton({
        onDragEnter: this.handleToggleButtonDragEnter.bind(this),
        location: this.location,
        toggle: this.toggle.bind(this)
      })
      this.cursorOverlayElement = document.createElement('div')
      this.cursorOverlayElement.classList.add('atom-dock-cursor-overlay', this.location)

      // Add the children to the DOM tree
      this.element.appendChild(this.innerElement)
      this.innerElement.appendChild(this.maskElement)
      this.maskElement.appendChild(this.wrapperElement)
      this.wrapperElement.appendChild(this.resizeHandle.getElement())
      this.wrapperElement.appendChild(this.paneContainer.getElement())
      this.wrapperElement.appendChild(this.cursorOverlayElement)
      // The toggle button must be rendered outside the mask because (1) it shouldn't be masked and
      // (2) if we made the mask larger to avoid masking it, the mask would block mouse events.
      this.innerElement.appendChild(this.toggleButton.getElement())
    }

    if (state.open) {
      this.innerElement.classList.add(OPEN_CLASS)
    } else {
      this.innerElement.classList.remove(OPEN_CLASS)
    }

    if (state.shouldAnimate) {
      this.maskElement.classList.add(SHOULD_ANIMATE_CLASS)
    } else {
      this.maskElement.classList.remove(SHOULD_ANIMATE_CLASS)
    }

    if (state.resizing) {
      this.cursorOverlayElement.classList.add(CURSOR_OVERLAY_VISIBLE_CLASS)
    } else {
      this.cursorOverlayElement.classList.remove(CURSOR_OVERLAY_VISIBLE_CLASS)
    }

    const shouldBeVisible = state.open || state.showDropTarget
    const size = Math.max(MINIMUM_SIZE, state.size == null ? this.getInitialSize() : state.size)

    // We need to change the size of the mask...
    this.maskElement.style[this.widthOrHeight] = `${shouldBeVisible ? size : HANDLE_SIZE}px`
    // ...but the content needs to maintain a constant size.
    this.wrapperElement.style[this.widthOrHeight] = `${size}px`

    this.resizeHandle.update({dockIsOpen: this.state.open})
    this.toggleButton.update({
      open: shouldBeVisible,
      visible: state.hovered || (state.draggingItem && !shouldBeVisible)
    })
  }

  handleDidAddPaneItem () {
    // Show the dock if you drop an item into it.
    if (this.paneContainer.getPaneItems().length === 1) {
      this.setState({open: true})
    }
  }

  handleDidRemovePaneItem () {
    // Hide the dock if you remove the last item.
    if (this.paneContainer.getPaneItems().length === 0) {
      this.setState({open: false})
    }
  }

  handleResizeHandleDragStart () {
    window.addEventListener('mousemove', this.handleMouseMove)
    window.addEventListener('mouseup', this.handleMouseUp)
    this.setState({resizing: true})
  }

  handleMouseMove (event) {
    if (event.buttons === 0) { // We missed the mouseup event. For some reason it happens on Windows
      this.handleMouseUp(event)
      return
    }

    let size = 0
    switch (this.location) {
      case 'left':
        size = event.pageX - this.element.getBoundingClientRect().left
        break
      case 'bottom':
        size = this.element.getBoundingClientRect().bottom - event.pageY
        break
      case 'right':
        size = this.element.getBoundingClientRect().right - event.pageX
        break
    }
    this.setState({size})
  }

  handleMouseUp (event) {
    window.removeEventListener('mousemove', this.handleMouseMove)
    window.removeEventListener('mouseup', this.handleMouseUp)
    this.setState({resizing: false})
  }

  handleToggleButtonDragEnter () {
    this.setState({showDropTarget: true})
    window.addEventListener('drag', this.handleDrag)
    window.addEventListener('dragend', this.handleDragEnd)
  }

  handleDrag (event) {
    if (!this.pointWithinHoverArea({x: event.pageX, y: event.pageY}, false)) {
      this.draggedOut()
    }
  }

  handleDragEnd () {
    this.draggedOut()
  }

  draggedOut () {
    this.setState({showDropTarget: false})
    window.removeEventListener('drag', this.handleDrag)
    window.removeEventListener('dragend', this.handleDragEnd)
  }

  // Determine whether the cursor is within the dock hover area. This isn't as simple as just using
  // mouseenter/leave because we want to be a little more forgiving. For example, if the cursor is
  // over the footer, we want to show the bottom dock's toggle button.
  pointWithinHoverArea (point, includeButtonWidth) {
    const dockBounds = this.innerElement.getBoundingClientRect()
    // Copy the bounds object since we can't mutate it.
    const bounds = {
      top: dockBounds.top,
      right: dockBounds.right,
      bottom: dockBounds.bottom,
      left: dockBounds.left
    }

    // Include all panels that are closer to the edge than the dock in our calculations.
    switch (this.location) {
      case 'right':
        bounds.right = Number.POSITIVE_INFINITY
        break
      case 'bottom':
        bounds.bottom = Number.POSITIVE_INFINITY
        break
      case 'left':
        bounds.left = 0
        break
    }

    // The area used when detecting "leave" events is actually larger than when detecting entrances.
    if (includeButtonWidth) {
      const hoverMargin = 20
      const {width, height} = this.toggleButton.getSize()
      switch (this.location) {
        case 'right':
          bounds.left -= width + hoverMargin
          break
        case 'bottom':
          bounds.top -= height + hoverMargin
          break
        case 'left':
          bounds.right += width + hoverMargin
          break
      }
    }
    return rectContainsPoint(bounds, point)
  }

  getInitialSize () {
    let initialSize
    // The item may not have been activated yet. If that's the case, just use the first item.
    const activePaneItem = this.paneContainer.getActivePaneItem() || this.paneContainer.getPaneItems()[0]
    if (activePaneItem != null) {
      initialSize = getPreferredInitialSize(activePaneItem, this.location)
    }
    return initialSize == null ? DEFAULT_INITIAL_SIZE : initialSize
  }

  serialize () {
    return {
      deserializer: 'Dock',
      size: this.state.size,
      paneContainer: this.paneContainer.serialize(),
      open: this.state.open
    }
  }

  deserialize (serialized, deserializerManager) {
    this.paneContainer.deserialize(serialized.paneContainer, deserializerManager)
    this.setState({
      size: serialized.size,
      // If no items could be deserialized, we don't want to show the dock (even if it was open last time)
      open: serialized.open && (this.paneContainer.getPaneItems().length > 0)
    })
  }

  // PaneContainer-delegating methods

  getPanes () {
    return this.paneContainer.getPanes()
  }

  observePanes (fn) {
    return this.paneContainer.observePanes(fn)
  }

  onDidAddPane (fn) {
    return this.paneContainer.onDidAddPane(fn)
  }

  onWillDestroyPane (fn) {
    return this.paneContainer.onWillDestroyPane(fn)
  }

  onDidDestroyPane (fn) {
    return this.paneContainer.onDidDestroyPane(fn)
  }

  paneForURI (uri) {
    return this.paneContainer.paneForURI(uri)
  }

  paneForItem (item) {
    return this.paneContainer.paneForItem(item)
  }

  getActivePane () {
    return this.paneContainer.getActivePane()
  }

  getPaneItems () {
    return this.paneContainer.getPaneItems()
  }

  getActivePaneItem () {
    return this.paneContainer.getActivePaneItem()
  }

  getTextEditors () {
    return this.paneContainer.getTextEditors()
  }

  getActiveTextEditor () {
    const activeItem = this.getActivePaneItem()
    if (activeItem instanceof TextEditor) { return activeItem }
  }

  observePaneItems (fn) {
    return this.paneContainer.observePaneItems(fn)
  }

  onDidAddPaneItem (fn) {
    return this.paneContainer.onDidAddPaneItem(fn)
  }

  onWillDestroyPaneItem (fn) {
    return this.paneContainer.onWillDestroyPaneItem(fn)
  }

  onDidDestroyPaneItem (fn) {
    return this.paneContainer.onDidDestroyPaneItem(fn)
  }

  saveAll () {
    this.paneContainer.saveAll()
  }

  confirmClose (options) {
    return this.paneContainer.confirmClose(options)
  }
}

class DockResizeHandle {
  constructor (props) {
    this.handleMouseDown = this.handleMouseDown.bind(this)
    this.handleClick = this.handleClick.bind(this)

    this.element = document.createElement('div')
    this.element.classList.add('atom-dock-resize-handle', props.location)
    this.element.addEventListener('mousedown', this.handleMouseDown)
    this.element.addEventListener('click', this.handleClick)
    const widthOrHeight = getWidthOrHeight(props.location)
    this.element.style[widthOrHeight] = `${HANDLE_SIZE}px`
    this.props = props
    this.update(props)
  }

  getElement () {
    return this.element
  }

  update (newProps) {
    this.props = Object.assign({}, this.props, newProps)

    if (this.props.dockIsOpen) {
      this.element.classList.add(RESIZE_HANDLE_RESIZABLE_CLASS)
    } else {
      this.element.classList.remove(RESIZE_HANDLE_RESIZABLE_CLASS)
    }
  }

  destroy () {
    this.element.removeEventListener('mousedown', this.handleMouseDown)
    this.element.removeEventListener('click', this.handleClick)
  }

  handleClick () {
    if (!this.props.dockIsOpen) {
      this.props.toggle()
    }
  }

  handleMouseDown () {
    if (this.props.dockIsOpen) {
      this.props.onResizeStart()
    }
  }
}

class DockToggleButton {
  constructor (props) {
    this.handleClick = this.handleClick.bind(this)
    this.handleDragEnter = this.handleDragEnter.bind(this)

    this.element = document.createElement('div')
    this.element.classList.add('atom-dock-toggle-button', props.location)
    this.element.classList.add(props.location)
    this.innerElement = document.createElement('div')
    this.innerElement.classList.add('atom-dock-toggle-button-inner', props.location)
    this.innerElement.addEventListener('click', this.handleClick)
    this.innerElement.addEventListener('dragenter', this.handleDragEnter)
    this.iconElement = document.createElement('span')
    this.innerElement.appendChild(this.iconElement)
    this.element.appendChild(this.innerElement)

    this.props = props
    this.update(props)
  }

  getElement () {
    return this.element
  }

  getSize () {
    if (this.size == null) {
      this.size = this.element.getBoundingClientRect()
    }
    return this.size
  }

  destroy () {
    this.innerElement.removeEventListener('click', this.handleClick)
    this.innerElement.removeEventListener('dragenter', this.handleDragEnter)
  }

  update (newProps) {
    this.props = Object.assign({}, this.props, newProps)

    if (this.props.visible) {
      this.element.classList.add(TOGGLE_BUTTON_VISIBLE_CLASS)
    } else {
      this.element.classList.remove(TOGGLE_BUTTON_VISIBLE_CLASS)
    }

    this.iconElement.className = 'icon ' + getIconName(this.props.location, this.props.open)
  }

  handleClick () {
    this.props.toggle()
  }

  handleDragEnter () {
    this.props.onDragEnter()
  }
}

function getWidthOrHeight (location) {
  return location === 'left' || location === 'right' ? 'width' : 'height'
}

function getPreferredInitialSize (item, location) {
  switch (location) {
    case 'left':
    case 'right':
      return typeof item.getPreferredInitialWidth === 'function'
        ? item.getPreferredInitialWidth()
        : null
    default:
      return typeof item.getPreferredInitialHeight === 'function'
        ? item.getPreferredInitialHeight()
        : null
  }
}

function getIconName (location, open) {
  switch (location) {
    case 'right': return open ? 'icon-chevron-right' : 'icon-chevron-left'
    case 'bottom': return open ? 'icon-chevron-down' : 'icon-chevron-up'
    case 'left': return open ? 'icon-chevron-left' : 'icon-chevron-right'
    default: throw new Error(`Invalid location: ${location}`)
  }
}

function rectContainsPoint (rect, point) {
  return (
    point.x >= rect.left &&
    point.y >= rect.top &&
    point.x <= rect.right &&
    point.y <= rect.bottom
  )
}
