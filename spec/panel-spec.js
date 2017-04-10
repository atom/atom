const Panel = require('../src/panel')

describe('Panel', () => {
  class TestPanelItem {
    getElement () {
      if (!this.element) {
        this.element = document.createElement('div')
        this.element.className = 'test-root'
      }
      return this.element
    }
  }

  it('adds the item\'s element as a child of the panel', () => {
    const panel = new Panel({item: new TestPanelItem()}, atom.views)
    const element = panel.getElement()
    expect(element.tagName.toLowerCase()).toBe('atom-panel')
    expect(element.firstChild).toBe(panel.getItem().getElement())
  })

  it('removes the element when the panel is destroyed', () => {
    const panel = new Panel({item: new TestPanelItem()}, atom.views)
    const element = panel.getElement()
    const jasmineContent = document.getElementById('jasmine-content')
    jasmineContent.appendChild(element)

    expect(element.parentNode).toBe(jasmineContent)
    panel.destroy()
    expect(element.parentNode).not.toBe(jasmineContent)
  })

  describe('changing panel visibility', () => {
    it('notifies observers added with onDidChangeVisible', () => {
      const panel = new Panel({item: new TestPanelItem()}, atom.views)

      const spy = jasmine.createSpy()
      panel.onDidChangeVisible(spy)

      panel.hide()
      expect(panel.isVisible()).toBe(false)
      expect(spy).toHaveBeenCalledWith(false)
      spy.reset()

      panel.show()
      expect(panel.isVisible()).toBe(true)
      expect(spy).toHaveBeenCalledWith(true)

      panel.destroy()
      expect(panel.isVisible()).toBe(false)
      expect(spy).toHaveBeenCalledWith(false)
    })

    it('initially renders panel created with visibile: false', () => {
      const panel = new Panel({visible: false, item: new TestPanelItem()}, atom.views)
      const element = panel.getElement()
      expect(element.style.display).toBe('none')
    })

    it('hides and shows the panel element when Panel::hide() and Panel::show() are called', () => {
      const panel = new Panel({item: new TestPanelItem()}, atom.views)
      const element = panel.getElement()
      expect(element.style.display).not.toBe('none')

      panel.hide()
      expect(element.style.display).toBe('none')

      panel.show()
      expect(element.style.display).not.toBe('none')
    })
  })

  describe('when a class name is specified', () => {
    it('initially renders panel created with visibile: false', () => {
      const panel = new Panel({className: 'some classes', item: new TestPanelItem()}, atom.views)
      const element = panel.getElement()

      expect(element).toHaveClass('some')
      expect(element).toHaveClass('classes')
    })
  })

  describe('creating an atom-panel via markup', () => {
    it('does not throw an error', () => {
      const element = document.createElement('atom-panel')
    })
  })
})
