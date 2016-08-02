ViewRegistry = require '../src/view-registry'

describe "ViewRegistry", ->
  registry = null

  beforeEach ->
    registry = new ViewRegistry

  afterEach ->
    registry.clearDocumentRequests()

  describe "::getView(object)", ->
    describe "when passed a DOM node", ->
      it "returns the given DOM node", ->
        node = document.createElement('div')
        expect(registry.getView(node)).toBe node

    describe "when passed an object with an element property", ->
      it "returns the element property if it's an instance of HTMLElement", ->
        class TestComponent
          constructor: -> @element = document.createElement('div')

        component = new TestComponent
        expect(registry.getView(component)).toBe component.element

    describe "when passed an object with a getElement function", ->
      it "returns the return value of getElement if it's an instance of HTMLElement", ->
        class TestComponent
          getElement: ->
            @myElement ?= document.createElement('div')

        component = new TestComponent
        expect(registry.getView(component)).toBe component.myElement

    describe "when passed a model object", ->
      describe "when a view provider is registered matching the object's constructor", ->
        it "constructs a view element and assigns the model on it", ->
          class TestModel

          class TestModelSubclass extends TestModel

          class TestView
            initialize: (@model) -> this

          model = new TestModel

          registry.addViewProvider TestModel, (model) ->
            new TestView().initialize(model)

          view = registry.getView(model)
          expect(view instanceof TestView).toBe true
          expect(view.model).toBe model

          subclassModel = new TestModelSubclass
          view2 = registry.getView(subclassModel)
          expect(view2 instanceof TestView).toBe true
          expect(view2.model).toBe subclassModel

      describe "when a view provider is registered generically, and works with the object", ->
        it "constructs a view element and assigns the model on it", ->
          model = {a: 'b'}

          registry.addViewProvider (model) ->
            if model.a is 'b'
              element = document.createElement('div')
              element.className = 'test-element'
              element

          view = registry.getView({a: 'b'})
          expect(view.className).toBe 'test-element'

          expect(-> registry.getView({a: 'c'})).toThrow()

      describe "when no view provider is registered for the object's constructor", ->
        it "throws an exception", ->
          expect(-> registry.getView(new Object)).toThrow()

  describe "::addViewProvider(providerSpec)", ->
    it "returns a disposable that can be used to remove the provider", ->
      class TestModel
      class TestView
        initialize: (@model) -> this

      disposable = registry.addViewProvider TestModel, (model) ->
        new TestView().initialize(model)

      expect(registry.getView(new TestModel) instanceof TestView).toBe true
      disposable.dispose()
      expect(-> registry.getView(new TestModel)).toThrow()

  describe "::updateDocument(fn) and ::readDocument(fn)", ->
    frameRequests = null

    beforeEach ->
      frameRequests = []
      spyOn(window, 'requestAnimationFrame').andCallFake (fn) -> frameRequests.push(fn)

    it "performs all pending writes before all pending reads on the next animation frame", ->
      events = []

      registry.updateDocument -> events.push('write 1')
      registry.readDocument -> events.push('read 1')
      registry.readDocument -> events.push('read 2')
      registry.updateDocument -> events.push('write 2')

      expect(events).toEqual []

      expect(frameRequests.length).toBe 1
      frameRequests[0]()
      expect(events).toEqual ['write 1', 'write 2', 'read 1', 'read 2']

      frameRequests = []
      events = []
      disposable = registry.updateDocument -> events.push('write 3')
      registry.updateDocument -> events.push('write 4')
      registry.readDocument -> events.push('read 3')

      disposable.dispose()

      expect(frameRequests.length).toBe 1
      frameRequests[0]()
      expect(events).toEqual ['write 4', 'read 3']

    it "performs writes requested from read callbacks in the same animation frame", ->
      spyOn(window, 'setInterval').andCallFake(fakeSetInterval)
      spyOn(window, 'clearInterval').andCallFake(fakeClearInterval)
      events = []

      registry.pollDocument -> events.push('poll')
      registry.pollAfterNextUpdate()
      registry.updateDocument -> events.push('write 1')
      registry.readDocument ->
        registry.updateDocument -> events.push('write from read 1')
        events.push('read 1')
      registry.readDocument ->
        registry.updateDocument -> events.push('write from read 2')
        events.push('read 2')
      registry.updateDocument -> events.push('write 2')

      expect(frameRequests.length).toBe 1
      frameRequests[0]()
      expect(frameRequests.length).toBe 1

      expect(events).toEqual [
        'write 1'
        'write 2'
        'read 1'
        'read 2'
        'poll'
        'write from read 1'
        'write from read 2'
      ]

    it "pauses DOM polling when reads or writes are pending", ->
      spyOn(window, 'setInterval').andCallFake(fakeSetInterval)
      spyOn(window, 'clearInterval').andCallFake(fakeClearInterval)
      events = []

      registry.pollDocument -> events.push('poll')
      registry.updateDocument -> events.push('write')
      registry.readDocument -> events.push('read')

      window.dispatchEvent(new UIEvent('resize'))
      expect(events).toEqual []

      frameRequests[0]()
      expect(events).toEqual ['write', 'read', 'poll']

      window.dispatchEvent(new UIEvent('resize'))
      expect(events).toEqual ['write', 'read', 'poll', 'poll']

    it "polls the document after updating when ::pollAfterNextUpdate() has been called", ->
      events = []
      registry.pollDocument -> events.push('poll')
      registry.updateDocument -> events.push('write')
      registry.readDocument -> events.push('read')
      frameRequests.shift()()
      expect(events).toEqual ['write', 'read']

      events = []
      registry.pollAfterNextUpdate()
      registry.updateDocument -> events.push('write')
      registry.readDocument -> events.push('read')
      frameRequests.shift()()
      expect(events).toEqual ['write', 'read', 'poll']

  describe "::pollDocument(fn)", ->
    [testElement, testStyleSheet, disposable1, disposable2, events] = []

    beforeEach ->
      testElement = document.createElement('div')
      testStyleSheet = document.createElement('style')
      testStyleSheet.textContent = 'body {}'
      jasmineContent = document.getElementById('jasmine-content')
      jasmineContent.appendChild(testElement)
      jasmineContent.appendChild(testStyleSheet)

      events = []
      disposable1 = registry.pollDocument -> events.push('poll 1')
      disposable2 = registry.pollDocument -> events.push('poll 2')

    it "calls all registered polling functions after document or stylesheet changes until they are disabled via a returned disposable", ->
      jasmine.useRealClock()
      expect(events).toEqual []

      testElement.style.width = '400px'

      waitsFor "events to occur in response to DOM mutation", -> events.length > 0

      runs ->
        expect(events).toEqual ['poll 1', 'poll 2']
        events.length = 0

        testStyleSheet.textContent = 'body {color: #333;}'

      waitsFor "events to occur in reponse to style sheet mutation", -> events.length > 0

      runs ->
        expect(events).toEqual ['poll 1', 'poll 2']
        events.length = 0

        disposable1.dispose()
        testElement.style.color = '#fff'

      waitsFor "more events to occur in response to DOM mutation", -> events.length > 0

      runs ->
        expect(events).toEqual ['poll 2']

    it "calls all registered polling functions when the window resizes", ->
      expect(events).toEqual []

      window.dispatchEvent(new UIEvent('resize'))

      expect(events).toEqual ['poll 1', 'poll 2']

  describe "::getNextUpdatePromise()", ->
    it "returns a promise that resolves at the end of the next update cycle", ->
      updateCalled = false
      readCalled = false
      pollCalled = false

      waitsFor 'getNextUpdatePromise to resolve', (done) ->
        registry.getNextUpdatePromise().then ->
          expect(updateCalled).toBe true
          expect(readCalled).toBe true
          expect(pollCalled).toBe true
          done()

        registry.updateDocument -> updateCalled = true
        registry.readDocument -> readCalled = true
        registry.pollDocument -> pollCalled = true
        registry.pollAfterNextUpdate()
