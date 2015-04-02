ViewRegistry = require '../src/view-registry'
{View} = require '../src/space-pen-extensions'

describe "ViewRegistry", ->
  registry = null

  beforeEach ->
    registry = new ViewRegistry

  describe "::getView(object)", ->
    describe "when passed a DOM node", ->
      it "returns the given DOM node", ->
        node = document.createElement('div')
        expect(registry.getView(node)).toBe node

    describe "when passed a SpacePen view", ->
      it "returns the root node of the view with a .spacePenView property pointing at the SpacePen view", ->
        class TestView extends View
          @content: -> @div "Hello"

        view = new TestView
        node = registry.getView(view)
        expect(node.textContent).toBe "Hello"
        expect(node.spacePenView).toBe view

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

      describe "when no view provider is registered for the object's constructor", ->
        describe "when the object has a .getViewClass() method", ->
          it "builds an instance of the view class with the model, then returns its root node with a __spacePenView property pointing at the view", ->
            class TestView extends View
              @content: (model) -> @div model.name
              initialize: (@model) ->

            class TestModel
              constructor: (@name) ->
              getViewClass: -> TestView

            model = new TestModel("hello")
            node = registry.getView(model)

            expect(node.textContent).toBe "hello"
            view = node.spacePenView
            expect(view instanceof TestView).toBe true
            expect(view.model).toBe model

            # returns the same DOM node for repeated calls
            expect(registry.getView(model)).toBe node

        describe "when the object has no .getViewClass() method", ->
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

    it "pauses DOM polling when reads or writes are pending", ->
      spyOn(window, 'setInterval').andCallFake(fakeSetInterval)
      spyOn(window, 'clearInterval').andCallFake(fakeClearInterval)
      events = []

      registry.pollDocument -> events.push('poll')
      registry.updateDocument -> events.push('write')
      registry.readDocument -> events.push('read')

      advanceClock(registry.documentPollingInterval)
      expect(events).toEqual []

      frameRequests[0]()
      expect(events).toEqual ['write', 'read', 'poll']

      advanceClock(registry.documentPollingInterval)
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
    it "calls all registered reader functions on an interval until they are disabled via a returned disposable", ->
      spyOn(window, 'setInterval').andCallFake(fakeSetInterval)

      events = []
      disposable1 = registry.pollDocument -> events.push('poll 1')
      disposable2 = registry.pollDocument -> events.push('poll 2')

      expect(events).toEqual []

      advanceClock(registry.documentPollingInterval)
      expect(events).toEqual ['poll 1', 'poll 2']

      advanceClock(registry.documentPollingInterval)
      expect(events).toEqual ['poll 1', 'poll 2', 'poll 1', 'poll 2']

      disposable1.dispose()
      advanceClock(registry.documentPollingInterval)
      expect(events).toEqual ['poll 1', 'poll 2', 'poll 1', 'poll 2', 'poll 2']

      disposable2.dispose()
      advanceClock(registry.documentPollingInterval)
      expect(events).toEqual ['poll 1', 'poll 2', 'poll 1', 'poll 2', 'poll 2']
