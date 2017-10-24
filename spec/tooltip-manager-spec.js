/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {CompositeDisposable} = require('atom')
const TooltipManager = require('../src/tooltip-manager')
const Tooltip = require('../src/tooltip')
const _ = require('underscore-plus')

describe('TooltipManager', function () {
  let [manager, element] = Array.from([])

  const ctrlX = _.humanizeKeystroke('ctrl-x')
  const ctrlY = _.humanizeKeystroke('ctrl-y')

  beforeEach(function () {
    manager = new TooltipManager({keymapManager: atom.keymaps, viewRegistry: atom.views})
    element = createElement('foo')
  })

  var createElement = function (className) {
    const el = document.createElement('div')
    el.classList.add(className)
    jasmine.attachToDOM(el)
    return el
  }

  const mouseEnter = function (element) {
    element.dispatchEvent(new CustomEvent('mouseenter', {bubbles: false}))
    return element.dispatchEvent(new CustomEvent('mouseover', {bubbles: true}))
  }

  const mouseLeave = function (element) {
    element.dispatchEvent(new CustomEvent('mouseleave', {bubbles: false}))
    return element.dispatchEvent(new CustomEvent('mouseout', {bubbles: true}))
  }

  const hover = function (element, fn) {
    mouseEnter(element)
    advanceClock(manager.hoverDefaults.delay.show)
    fn()
    mouseLeave(element)
    return advanceClock(manager.hoverDefaults.delay.hide)
  }

  return describe('::add(target, options)', function () {
    describe("when the trigger is 'hover' (the default)", function () {
      it('creates a tooltip when hovering over the target element', function () {
        manager.add(element, {title: 'Title'})
        return hover(element, () => expect(document.body.querySelector('.tooltip')).toHaveText('Title'))
      })

      return it('displays tooltips immediately when hovering over new elements once a tooltip has been displayed once', function () {
        const disposables = new CompositeDisposable()
        const element1 = createElement('foo')
        disposables.add(manager.add(element1, {title: 'Title'}))
        const element2 = createElement('bar')
        disposables.add(manager.add(element2, {title: 'Title'}))
        const element3 = createElement('baz')
        disposables.add(manager.add(element3, {title: 'Title'}))

        hover(element1, function () {})
        expect(document.body.querySelector('.tooltip')).toBeNull()

        mouseEnter(element2)
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        mouseLeave(element2)
        advanceClock(manager.hoverDefaults.delay.hide)
        expect(document.body.querySelector('.tooltip')).toBeNull()

        advanceClock(Tooltip.FOLLOW_THROUGH_DURATION)
        mouseEnter(element3)
        expect(document.body.querySelector('.tooltip')).toBeNull()
        advanceClock(manager.hoverDefaults.delay.show)
        expect(document.body.querySelector('.tooltip')).not.toBeNull()

        return disposables.dispose()
      })
    })

    describe("when the trigger is 'manual'", () =>
      it('creates a tooltip immediately and only hides it on dispose', function () {
        const disposable = manager.add(element, {title: 'Title', trigger: 'manual'})
        expect(document.body.querySelector('.tooltip')).toHaveText('Title')
        disposable.dispose()
        return expect(document.body.querySelector('.tooltip')).toBeNull()
      })
    )

    describe("when the trigger is 'click'", () =>
      it('shows and hides the tooltip when the target element is clicked', function () {
        manager.add(element, {title: 'Title', trigger: 'click'})
        expect(document.body.querySelector('.tooltip')).toBeNull()
        element.click()
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        element.click()
        expect(document.body.querySelector('.tooltip')).toBeNull()

        // Hide the tooltip when clicking anywhere but inside the tooltip element
        element.click()
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        document.body.querySelector('.tooltip').click()
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        document.body.querySelector('.tooltip').firstChild.click()
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        document.body.click()
        expect(document.body.querySelector('.tooltip')).toBeNull()

        // Tooltip can show again after hiding due to clicking outside of the tooltip
        element.click()
        expect(document.body.querySelector('.tooltip')).not.toBeNull()
        element.click()
        return expect(document.body.querySelector('.tooltip')).toBeNull()
      })
    )

    it('allows a custom item to be specified for the content of the tooltip', function () {
      const tooltipElement = document.createElement('div')
      manager.add(element, {item: {element: tooltipElement}})
      return hover(element, () => expect(tooltipElement.closest('.tooltip')).not.toBeNull())
    })

    it('allows a custom class to be specified for the tooltip', function () {
      const tooltipElement = document.createElement('div')
      manager.add(element, {title: 'Title', class: 'custom-tooltip-class'})
      return hover(element, () => expect(document.body.querySelector('.tooltip').classList.contains('custom-tooltip-class')).toBe(true))
    })

    it('allows jQuery elements to be passed as the target', function () {
      const element2 = document.createElement('div')
      jasmine.attachToDOM(element2)

      const fakeJqueryWrapper = [element, element2]
      fakeJqueryWrapper.jquery = 'any-version'
      const disposable = manager.add(fakeJqueryWrapper, {title: 'Title'})

      hover(element, () => expect(document.body.querySelector('.tooltip')).toHaveText('Title'))
      expect(document.body.querySelector('.tooltip')).toBeNull()
      hover(element2, () => expect(document.body.querySelector('.tooltip')).toHaveText('Title'))
      expect(document.body.querySelector('.tooltip')).toBeNull()

      disposable.dispose()

      hover(element, () => expect(document.body.querySelector('.tooltip')).toBeNull())
      return hover(element2, () => expect(document.body.querySelector('.tooltip')).toBeNull())
    })

    describe('when a keyBindingCommand is specified', function () {
      describe('when a title is specified', () =>
        it('appends the key binding corresponding to the command to the title', function () {
          atom.keymaps.add('test', {
            '.foo': { 'ctrl-x ctrl-y': 'test-command'
            },
            '.bar': { 'ctrl-x ctrl-z': 'test-command'
            }
          }
          )

          manager.add(element, {title: 'Title', keyBindingCommand: 'test-command'})

          return hover(element, function () {
            const tooltipElement = document.body.querySelector('.tooltip')
            return expect(tooltipElement).toHaveText(`Title ${ctrlX} ${ctrlY}`)
          })
        })
      )

      describe('when no title is specified', () =>
        it('shows the key binding corresponding to the command alone', function () {
          atom.keymaps.add('test', {'.foo': {'ctrl-x ctrl-y': 'test-command'}})

          manager.add(element, {keyBindingCommand: 'test-command'})

          return hover(element, function () {
            const tooltipElement = document.body.querySelector('.tooltip')
            return expect(tooltipElement).toHaveText(`${ctrlX} ${ctrlY}`)
          })
        })
      )

      return describe('when a keyBindingTarget is specified', function () {
        it('looks up the key binding relative to the target', function () {
          atom.keymaps.add('test', {
            '.bar': { 'ctrl-x ctrl-z': 'test-command'
            },
            '.foo': { 'ctrl-x ctrl-y': 'test-command'
            }
          }
          )

          manager.add(element, {keyBindingCommand: 'test-command', keyBindingTarget: element})

          return hover(element, function () {
            const tooltipElement = document.body.querySelector('.tooltip')
            return expect(tooltipElement).toHaveText(`${ctrlX} ${ctrlY}`)
          })
        })

        return it('does not display the keybinding if there is nothing mapped to the specified keyBindingCommand', function () {
          manager.add(element, {title: 'A Title', keyBindingCommand: 'test-command', keyBindingTarget: element})

          return hover(element, function () {
            const tooltipElement = document.body.querySelector('.tooltip')
            return expect(tooltipElement.textContent).toBe('A Title')
          })
        })
      })
    })

    describe('when .dispose() is called on the returned disposable', () =>
      it('no longer displays the tooltip on hover', function () {
        const disposable = manager.add(element, {title: 'Title'})

        hover(element, () => expect(document.body.querySelector('.tooltip')).toHaveText('Title'))

        disposable.dispose()

        return hover(element, () => expect(document.body.querySelector('.tooltip')).toBeNull())
      })
    )

    describe('when the window is resized', () =>
      it('hides the tooltips', function () {
        const disposable = manager.add(element, {title: 'Title'})
        return hover(element, function () {
          expect(document.body.querySelector('.tooltip')).not.toBeNull()
          window.dispatchEvent(new CustomEvent('resize'))
          expect(document.body.querySelector('.tooltip')).toBeNull()
          return disposable.dispose()
        })
      })
    )

    return describe('findTooltips', function () {
      it('adds and remove tooltips correctly', function () {
        expect(manager.findTooltips(element).length).toBe(0)
        const disposable1 = manager.add(element, {title: 'elem1'})
        expect(manager.findTooltips(element).length).toBe(1)
        const disposable2 = manager.add(element, {title: 'elem2'})
        expect(manager.findTooltips(element).length).toBe(2)
        disposable1.dispose()
        expect(manager.findTooltips(element).length).toBe(1)
        disposable2.dispose()
        return expect(manager.findTooltips(element).length).toBe(0)
      })

      return it('lets us hide tooltips programmatically', function () {
        const disposable = manager.add(element, {title: 'Title'})
        return hover(element, function () {
          expect(document.body.querySelector('.tooltip')).not.toBeNull()
          manager.findTooltips(element)[0].hide()
          expect(document.body.querySelector('.tooltip')).toBeNull()
          return disposable.dispose()
        })
      })
    })
  })
})
