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
      it "returns the root node of the view with a __spacePenView property pointing at the SpacePen view", ->
        class TestView extends View
          @content: -> @div "Hello"

        view = new TestView
        node = registry.getView(view)
        expect(node.textContent).toBe "Hello"
        expect(node.__spacePenView).toBe view

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
            view = node.__spacePenView
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
