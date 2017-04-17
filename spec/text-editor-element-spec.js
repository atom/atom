/* global HTMLDivElement */

const {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise, timeoutPromise} = require('./async-spec-helpers')
const TextEditor = require('../src/text-editor')
const TextEditorElement = require('../src/text-editor-element')

describe('TextEditorElement', () => {
  let jasmineContent

  beforeEach(() => {
    jasmineContent = document.body.querySelector('#jasmine-content')
  })

  describe('instantiation', () => {
    it("honors the 'mini' attribute", () => {
      jasmineContent.innerHTML = '<atom-text-editor mini>'
      const element = jasmineContent.firstChild
      expect(element.getModel().isMini()).toBe(true)
    })

    it("honors the 'placeholder-text' attribute", () => {
      jasmineContent.innerHTML = "<atom-text-editor placeholder-text='testing'>"
      const element = jasmineContent.firstChild
      expect(element.getModel().getPlaceholderText()).toBe('testing')
    })

    it("honors the 'gutter-hidden' attribute", () => {
      jasmineContent.innerHTML = '<atom-text-editor gutter-hidden>'
      const element = jasmineContent.firstChild
      expect(element.getModel().isLineNumberGutterVisible()).toBe(false)
    })

    it('honors the text content', () => {
      jasmineContent.innerHTML = '<atom-text-editor>testing</atom-text-editor>'
      const element = jasmineContent.firstChild
      expect(element.getModel().getText()).toBe('testing')
    })
  })

  describe('when the model is assigned', () =>
    it("adds the 'mini' attribute if .isMini() returns true on the model", function (done) {
      const element = new TextEditorElement()
      element.getModel().update({mini: true})
      atom.views.getNextUpdatePromise().then(() => {
        expect(element.hasAttribute('mini')).toBe(true)
        done()
      })
    })
  )

  describe('when the editor is attached to the DOM', () =>
    it('mounts the component and unmounts when removed from the dom', () => {
      const element = new TextEditorElement()
      jasmine.attachToDOM(element)

      const { component } = element
      expect(component.attached).toBe(true)
      element.remove()
      expect(component.attached).toBe(false)

      jasmine.attachToDOM(element)
      expect(element.component.attached).toBe(true)
    })
  )

  describe('when the editor is detached from the DOM and then reattached', () => {
    it('does not render duplicate line numbers', () => {
      const editor = new TextEditor()
      editor.setText('1\n2\n3')
      const element = editor.getElement()

      jasmine.attachToDOM(element)

      const initialCount = element.querySelectorAll('.line-number').length

      element.remove()
      jasmine.attachToDOM(element)
      expect(element.querySelectorAll('.line-number').length).toBe(initialCount)
    })

    it('does not render duplicate decorations in custom gutters', () => {
      const editor = new TextEditor()
      editor.setText('1\n2\n3')
      editor.addGutter({name: 'test-gutter'})
      const marker = editor.markBufferRange([[0, 0], [2, 0]])
      editor.decorateMarker(marker, {type: 'gutter', gutterName: 'test-gutter'})
      const element = editor.getElement()

      jasmine.attachToDOM(element)
      const initialDecorationCount = element.querySelectorAll('.decoration').length

      element.remove()
      jasmine.attachToDOM(element)
      expect(element.querySelectorAll('.decoration').length).toBe(initialDecorationCount)
    })

    it('can be re-focused using the previous `document.activeElement`', () => {
      const editorElement = document.createElement('atom-text-editor')
      jasmine.attachToDOM(editorElement)
      editorElement.focus()

      const { activeElement } = document

      editorElement.remove()
      jasmine.attachToDOM(editorElement)
      activeElement.focus()

      expect(editorElement.hasFocus()).toBe(true)
    })
  })

  describe('focus and blur handling', () => {
    it('proxies focus/blur events to/from the hidden input', () => {
      const element = new TextEditorElement()
      jasmineContent.appendChild(element)

      let blurCalled = false
      element.addEventListener('blur', () => {
        blurCalled = true
      })

      element.focus()
      expect(blurCalled).toBe(false)
      expect(element.hasFocus()).toBe(true)
      expect(document.activeElement).toBe(element.querySelector('input'))

      document.body.focus()
      expect(blurCalled).toBe(true)
    })

    it("doesn't trigger a blur event on the editor element when focusing an already focused editor element", () => {
      let blurCalled = false
      const element = new TextEditorElement()
      element.addEventListener('blur', () => { blurCalled = true })

      jasmineContent.appendChild(element)
      expect(document.activeElement).toBe(document.body)
      expect(blurCalled).toBe(false)

      element.focus()
      expect(document.activeElement).toBe(element.querySelector('input'))
      expect(blurCalled).toBe(false)

      element.focus()
      expect(document.activeElement).toBe(element.querySelector('input'))
      expect(blurCalled).toBe(false)
    })

    describe('when focused while a parent node is being attached to the DOM', () => {
      class ElementThatFocusesChild extends HTMLDivElement {
        attachedCallback () {
          this.firstChild.focus()
        }
      }

      document.registerElement('element-that-focuses-child',
        {prototype: ElementThatFocusesChild.prototype}
      )

      it('proxies the focus event to the hidden input', () => {
        const element = new TextEditorElement()
        const parentElement = document.createElement('element-that-focuses-child')
        parentElement.appendChild(element)
        jasmineContent.appendChild(parentElement)
        expect(document.activeElement).toBe(element.querySelector('input'))
      })
    })
  })

  describe('::onDidAttach and ::onDidDetach', () =>
    it('invokes callbacks when the element is attached and detached', () => {
      const element = new TextEditorElement()

      const attachedCallback = jasmine.createSpy('attachedCallback')
      const detachedCallback = jasmine.createSpy('detachedCallback')

      element.onDidAttach(attachedCallback)
      element.onDidDetach(detachedCallback)

      jasmine.attachToDOM(element)

      expect(attachedCallback).toHaveBeenCalled()
      expect(detachedCallback).not.toHaveBeenCalled()

      attachedCallback.reset()
      element.remove()

      expect(attachedCallback).not.toHaveBeenCalled()
      expect(detachedCallback).toHaveBeenCalled()
    })
  )

  describe('::setUpdatedSynchronously', () =>
    it('controls whether the text editor is updated synchronously', () => {
      spyOn(window, 'requestAnimationFrame').andCallFake(fn => fn())

      const element = new TextEditorElement()
      jasmine.attachToDOM(element)

      element.setUpdatedSynchronously(false)
      expect(element.isUpdatedSynchronously()).toBe(false)

      element.getModel().setText('hello')
      expect(window.requestAnimationFrame).toHaveBeenCalled()

      expect(element.textContent).toContain('hello')

      window.requestAnimationFrame.reset()
      element.setUpdatedSynchronously(true)
      element.getModel().setText('goodbye')
      expect(window.requestAnimationFrame).not.toHaveBeenCalled()
      expect(element.textContent).toContain('goodbye')
    })
  )

  describe('::getDefaultCharacterWidth', () => {
    it('returns null before the element is attached', () => {
      const element = new TextEditorElement()
      expect(element.getDefaultCharacterWidth()).toBeNull()
    })

    it('returns the width of a character in the root scope', () => {
      const element = new TextEditorElement()
      jasmine.attachToDOM(element)
      expect(element.getDefaultCharacterWidth()).toBeGreaterThan(0)
    })
  })

  describe('::getMaxScrollTop', () =>
    it('returns the maximum scroll top that can be applied to the element', async () => {
      const editor = new TextEditor()
      editor.setText('1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16')
      const element = editor.getElement()
      element.style.lineHeight = '10px'
      element.style.width = '200px'
      jasmine.attachToDOM(element)

      expect(element.getMaxScrollTop()).toBe(0)
      await editor.update({autoHeight: false})

      element.style.height = '100px'
      await element.getNextUpdatePromise()
      expect(element.getMaxScrollTop()).toBe(60)

      element.style.height = '120px'
      await element.getNextUpdatePromise()
      expect(element.getMaxScrollTop()).toBe(40)

      element.style.height = '200px'
      await element.getNextUpdatePromise()
      expect(element.getMaxScrollTop()).toBe(0)
    })
  )

  describe('on TextEditor::setMini', () =>
    it("changes the element's 'mini' attribute", async () => {
      const element = new TextEditorElement()
      jasmine.attachToDOM(element)
      expect(element.hasAttribute('mini')).toBe(false)
      element.getModel().setMini(true)
      await element.getNextUpdatePromise()
      expect(element.hasAttribute('mini')).toBe(true)
      element.getModel().setMini(false)
      await element.getNextUpdatePromise()
      expect(element.hasAttribute('mini')).toBe(false)
    })
  )

  describe('events', () => {
    let element = null

    beforeEach(() => {
      element = new TextEditorElement()
      element.getModel().setText('lorem\nipsum\ndolor\nsit\namet')
      element.setUpdatedSynchronously(true)
      element.setHeight(20)
      element.setWidth(20)
      element.getModel().update({autoHeight: false})
    })

    describe('::onDidChangeScrollTop(callback)', () =>
      it('triggers even when subscribing before attaching the element', () => {
        const positions = []
        const subscription1 = element.onDidChangeScrollTop(p => positions.push(p))
        jasmine.attachToDOM(element)
        element.onDidChangeScrollTop(p => positions.push(p))

        positions.length = 0
        element.setScrollTop(10)
        expect(positions).toEqual([10, 10])

        element.remove()
        jasmine.attachToDOM(element)

        positions.length = 0
        element.setScrollTop(20)
        expect(positions).toEqual([20, 20])

        subscription1.dispose()

        positions.length = 0
        element.setScrollTop(30)
        expect(positions).toEqual([30])
      })
    )

    describe('::onDidChangeScrollLeft(callback)', () =>
      it('triggers even when subscribing before attaching the element', () => {
        const positions = []
        const subscription1 = element.onDidChangeScrollLeft(p => positions.push(p))
        jasmine.attachToDOM(element)
        element.onDidChangeScrollLeft(p => positions.push(p))

        positions.length = 0
        element.setScrollLeft(10)
        expect(positions).toEqual([10, 10])

        element.remove()
        jasmine.attachToDOM(element)

        positions.length = 0
        element.setScrollLeft(20)
        expect(positions).toEqual([20, 20])

        subscription1.dispose()

        positions.length = 0
        element.setScrollLeft(30)
        expect(positions).toEqual([30])
      })
    )
  })
})
