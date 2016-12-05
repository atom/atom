'use strict'

const EventKit = require('event-kit')
const tooltipComponentsByElement = new WeakMap()
const listen = require('./delegated-listener')

// This tooltip class is derived from Bootstrap 3, but modified to not require
// jQuery, which is an expensive dependency we want to eliminate.

var followThroughTimer = null

var Tooltip = function (element, options, viewRegistry) {
  this.options = null
  this.enabled = null
  this.timeout = null
  this.hoverState = null
  this.element = null
  this.inState = null
  this.viewRegistry = viewRegistry

  this.init(element, options)
}

Tooltip.VERSION = '3.3.5'

Tooltip.FOLLOW_THROUGH_DURATION = 300

Tooltip.DEFAULTS = {
  animation: true,
  placement: 'top',
  selector: false,
  template: '<div class="tooltip" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>',
  trigger: 'hover focus',
  title: '',
  delay: 0,
  html: false,
  container: false,
  viewport: {
    selector: 'body',
    padding: 0
  }
}

Tooltip.prototype.init = function (element, options) {
  this.enabled = true
  this.element = element
  this.options = this.getOptions(options)
  this.disposables = new EventKit.CompositeDisposable()

  if (this.options.viewport) {
    if (typeof this.options.viewport === 'function') {
      this.viewport = this.options.viewport.call(this, this.element)
    } else {
      this.viewport = document.querySelector(this.options.viewport.selector || this.options.viewport)
    }
  }
  this.inState = {click: false, hover: false, focus: false}

  if (this.element instanceof document.constructor && !this.options.selector) {
    throw new Error('`selector` option must be specified when initializing tooltip on the window.document object!')
  }

  var triggers = this.options.trigger.split(' ')

  for (var i = triggers.length; i--;) {
    var trigger = triggers[i]

    if (trigger === 'click') {
      this.disposables.add(listen(this.element, 'click', this.options.selector, this.toggle.bind(this)))
      this.hideOnClickOutsideOfTooltip = (event) => {
        const tooltipElement = this.getTooltipElement()
        if (tooltipElement === event.target) return
        if (tooltipElement.contains(event.target)) return
        if (this.element === event.target) return
        if (this.element.contains(event.target)) return
        this.hide()
      }
    } else if (trigger === 'manual') {
      this.show()
    } else {
      var eventIn, eventOut

      if (trigger === 'hover') {
        if (this.options.selector) {
          eventIn = 'mouseover'
          eventOut = 'mouseout'
        } else {
          eventIn = 'mouseenter'
          eventOut = 'mouseleave'
        }
      } else {
        eventIn = 'focusin'
        eventOut = 'focusout'
      }

      this.disposables.add(listen(this.element, eventIn, this.options.selector, this.enter.bind(this)))
      this.disposables.add(listen(this.element, eventOut, this.options.selector, this.leave.bind(this)))
    }
  }

  this.options.selector
    ? (this._options = extend({}, this.options, { trigger: 'manual', selector: '' }))
    : this.fixTitle()
}

Tooltip.prototype.getDefaults = function () {
  return Tooltip.DEFAULTS
}

Tooltip.prototype.getOptions = function (options) {
  options = extend({}, this.getDefaults(), options)

  if (options.delay && typeof options.delay === 'number') {
    options.delay = {
      show: options.delay,
      hide: options.delay
    }
  }

  return options
}

Tooltip.prototype.getDelegateOptions = function () {
  var options = {}
  var defaults = this.getDefaults()

  if (this._options) {
    for (var key of Object.getOwnPropertyNames(this._options)) {
      var value = this._options[key]
      if (defaults[key] !== value) options[key] = value
    }
  }

  return options
}

Tooltip.prototype.enter = function (event) {
  if (event) {
    if (event.currentTarget !== this.element) {
      this.getDelegateComponent(event.currentTarget).enter(event)
      return
    }

    this.inState[event.type === 'focusin' ? 'focus' : 'hover'] = true
  }

  if (this.getTooltipElement().classList.contains('in') || this.hoverState === 'in') {
    this.hoverState = 'in'
    return
  }

  clearTimeout(this.timeout)

  this.hoverState = 'in'

  if (!this.options.delay ||
      !this.options.delay.show ||
      followThroughTimer) {
    return this.show()
  }

  this.timeout = setTimeout(function () {
    if (this.hoverState === 'in') this.show()
  }.bind(this), this.options.delay.show)
}

Tooltip.prototype.isInStateTrue = function () {
  for (var key in this.inState) {
    if (this.inState[key]) return true
  }

  return false
}

Tooltip.prototype.leave = function (event) {
  if (event) {
    if (event.currentTarget !== this.element) {
      this.getDelegateComponent(event.currentTarget).leave(event)
      return
    }

    this.inState[event.type === 'focusout' ? 'focus' : 'hover'] = false
  }

  if (this.isInStateTrue()) return

  clearTimeout(this.timeout)

  this.hoverState = 'out'

  if (!this.options.delay || !this.options.delay.hide) return this.hide()

  this.timeout = setTimeout(function () {
    if (this.hoverState === 'out') this.hide()
  }.bind(this), this.options.delay.hide)
}

Tooltip.prototype.show = function () {
  if (this.hasContent() && this.enabled) {
    if (this.hideOnClickOutsideOfTooltip) {
      window.addEventListener('click', this.hideOnClickOutsideOfTooltip, true)
    }

    var tip = this.getTooltipElement()
    var tipId = this.getUID('tooltip')

    this.setContent()
    tip.setAttribute('id', tipId)
    this.element.setAttribute('aria-describedby', tipId)

    if (this.options.animation) tip.classList.add('fade')

    var placement = typeof this.options.placement === 'function'
      ? this.options.placement.call(this, tip, this.element)
      : this.options.placement

    var autoToken = /\s?auto?\s?/i
    var autoPlace = autoToken.test(placement)
    if (autoPlace) placement = placement.replace(autoToken, '') || 'top'

    tip.remove()
    tip.style.top = '0px'
    tip.style.left = '0px'
    tip.style.display = 'block'
    tip.classList.add(placement)

    document.body.appendChild(tip)

    var pos = this.element.getBoundingClientRect()
    var actualWidth = tip.offsetWidth
    var actualHeight = tip.offsetHeight

    if (autoPlace) {
      var orgPlacement = placement
      var viewportDim = this.viewport.getBoundingClientRect()

      placement = placement === 'bottom' && pos.bottom + actualHeight > viewportDim.bottom ? 'top'
                : placement === 'top' && pos.top - actualHeight < viewportDim.top ? 'bottom'
                : placement === 'right' && pos.right + actualWidth > viewportDim.width ? 'left'
                : placement === 'left' && pos.left - actualWidth < viewportDim.left ? 'right'
                : placement

      tip.classList.remove(orgPlacement)
      tip.classList.add(placement)
    }

    var calculatedOffset = this.getCalculatedOffset(placement, pos, actualWidth, actualHeight)

    this.applyPlacement(calculatedOffset, placement)

    var prevHoverState = this.hoverState
    this.hoverState = null

    if (prevHoverState === 'out') this.leave()
  }
}

Tooltip.prototype.applyPlacement = function (offset, placement) {
  var tip = this.getTooltipElement()

  var width = tip.offsetWidth
  var height = tip.offsetHeight

  // manually read margins because getBoundingClientRect includes difference
  var computedStyle = window.getComputedStyle(tip)
  var marginTop = parseInt(computedStyle.marginTop, 10)
  var marginLeft = parseInt(computedStyle.marginLeft, 10)

  offset.top += marginTop
  offset.left += marginLeft

  tip.style.top = offset.top + 'px'
  tip.style.left = offset.left + 'px'

  tip.classList.add('in')

  // check to see if placing tip in new offset caused the tip to resize itself
  var actualWidth = tip.offsetWidth
  var actualHeight = tip.offsetHeight

  if (placement === 'top' && actualHeight !== height) {
    offset.top = offset.top + height - actualHeight
  }

  var delta = this.getViewportAdjustedDelta(placement, offset, actualWidth, actualHeight)

  if (delta.left) offset.left += delta.left
  else offset.top += delta.top

  var isVertical = /top|bottom/.test(placement)
  var arrowDelta = isVertical ? delta.left * 2 - width + actualWidth : delta.top * 2 - height + actualHeight
  var arrowOffsetPosition = isVertical ? 'offsetWidth' : 'offsetHeight'

  tip.style.top = offset.top + 'px'
  tip.style.left = offset.left + 'px'

  this.replaceArrow(arrowDelta, tip[arrowOffsetPosition], isVertical)
}

Tooltip.prototype.replaceArrow = function (delta, dimension, isVertical) {
  var arrow = this.getArrowElement()
  var amount = 50 * (1 - delta / dimension) + '%'

  if (isVertical) {
    arrow.style.left = amount
    arrow.style.top = ''
  } else {
    arrow.style.top = amount
    arrow.style.left = ''
  }
}

Tooltip.prototype.setContent = function () {
  var tip = this.getTooltipElement()

  if (this.options.class) {
    tip.classList.add(this.options.class)
  }

  var inner = tip.querySelector('.tooltip-inner')
  if (this.options.item) {
    inner.appendChild(this.viewRegistry.getView(this.options.item))
  } else {
    var title = this.getTitle()
    if (this.options.html) {
      inner.innerHTML = title
    } else {
      inner.textContent = title
    }
  }

  tip.classList.remove('fade', 'in', 'top', 'bottom', 'left', 'right')
}

Tooltip.prototype.hide = function (callback) {
  this.inState = {}

  if (this.hideOnClickOutsideOfTooltip) {
    window.removeEventListener('click', this.hideOnClickOutsideOfTooltip, true)
  }

  this.tip && this.tip.classList.remove('in')

  if (this.hoverState !== 'in') this.tip && this.tip.remove()

  this.element.removeAttribute('aria-describedby')

  callback && callback()

  this.hoverState = null

  clearTimeout(followThroughTimer)
  followThroughTimer = setTimeout(
    function () {
      followThroughTimer = null
    },
    Tooltip.FOLLOW_THROUGH_DURATION
  )

  return this
}

Tooltip.prototype.fixTitle = function () {
  if (this.element.getAttribute('title') || typeof this.element.getAttribute('data-original-title') !== 'string') {
    this.element.setAttribute('data-original-title', this.element.getAttribute('title') || '')
    this.element.setAttribute('title', '')
  }
}

Tooltip.prototype.hasContent = function () {
  return this.getTitle() || this.options.item
}

Tooltip.prototype.getCalculatedOffset = function (placement, pos, actualWidth, actualHeight) {
  return placement === 'bottom' ? { top: pos.top + pos.height, left: pos.left + pos.width / 2 - actualWidth / 2 }
       : placement === 'top' ? { top: pos.top - actualHeight, left: pos.left + pos.width / 2 - actualWidth / 2 }
       : placement === 'left' ? { top: pos.top + pos.height / 2 - actualHeight / 2, left: pos.left - actualWidth }
       :/* placement === 'right' */ { top: pos.top + pos.height / 2 - actualHeight / 2, left: pos.left + pos.width }
}

Tooltip.prototype.getViewportAdjustedDelta = function (placement, pos, actualWidth, actualHeight) {
  var delta = { top: 0, left: 0 }
  if (!this.viewport) return delta

  var viewportPadding = this.options.viewport && this.options.viewport.padding || 0
  var viewportDimensions = this.viewport.getBoundingClientRect()

  if (/right|left/.test(placement)) {
    var topEdgeOffset = pos.top - viewportPadding - viewportDimensions.scroll
    var bottomEdgeOffset = pos.top + viewportPadding - viewportDimensions.scroll + actualHeight
    if (topEdgeOffset < viewportDimensions.top) { // top overflow
      delta.top = viewportDimensions.top - topEdgeOffset
    } else if (bottomEdgeOffset > viewportDimensions.top + viewportDimensions.height) { // bottom overflow
      delta.top = viewportDimensions.top + viewportDimensions.height - bottomEdgeOffset
    }
  } else {
    var leftEdgeOffset = pos.left - viewportPadding
    var rightEdgeOffset = pos.left + viewportPadding + actualWidth
    if (leftEdgeOffset < viewportDimensions.left) { // left overflow
      delta.left = viewportDimensions.left - leftEdgeOffset
    } else if (rightEdgeOffset > viewportDimensions.right) { // right overflow
      delta.left = viewportDimensions.left + viewportDimensions.width - rightEdgeOffset
    }
  }

  return delta
}

Tooltip.prototype.getTitle = function () {
  var title = this.element.getAttribute('data-original-title')
  if (title) {
    return title
  } else {
    return (typeof this.options.title === 'function')
      ? this.options.title.call(this.element)
      : this.options.title
  }
}

Tooltip.prototype.getUID = function (prefix) {
  do prefix += ~~(Math.random() * 1000000)
  while (document.getElementById(prefix))
  return prefix
}

Tooltip.prototype.getTooltipElement = function () {
  if (!this.tip) {
    let div = document.createElement('div')
    div.innerHTML = this.options.template
    if (div.children.length !== 1) {
      throw new Error('Tooltip `template` option must consist of exactly 1 top-level element!')
    }
    this.tip = div.firstChild
  }
  return this.tip
}

Tooltip.prototype.getArrowElement = function () {
  this.arrow = this.arrow || this.getTooltipElement().querySelector('.tooltip-arrow')
  return this.arrow
}

Tooltip.prototype.enable = function () {
  this.enabled = true
}

Tooltip.prototype.disable = function () {
  this.enabled = false
}

Tooltip.prototype.toggleEnabled = function () {
  this.enabled = !this.enabled
}

Tooltip.prototype.toggle = function (event) {
  if (event) {
    if (event.currentTarget !== this.element) {
      this.getDelegateComponent(event.currentTarget).toggle(event)
      return
    }

    this.inState.click = !this.inState.click
    if (this.isInStateTrue()) this.enter()
    else this.leave()
  } else {
    this.getTooltipElement().classList.contains('in') ? this.leave() : this.enter()
  }
}

Tooltip.prototype.destroy = function () {
  clearTimeout(this.timeout)
  this.tip && this.tip.remove()
  this.disposables.dispose()
}

Tooltip.prototype.getDelegateComponent = function (element) {
  var component = tooltipComponentsByElement.get(element)
  if (!component) {
    component = new Tooltip(element, this.getDelegateOptions(), this.viewRegistry)
    tooltipComponentsByElement.set(element, component)
  }
  return component
}

function extend () {
  var args = Array.prototype.slice.apply(arguments)
  var target = args.shift()
  var source = args.shift()
  while (source) {
    for (var key of Object.getOwnPropertyNames(source)) {
      target[key] = source[key]
    }
    source = args.shift()
  }
  return target
}

module.exports = Tooltip
