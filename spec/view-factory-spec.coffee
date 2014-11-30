ViewFactory = require '../src/view-factory'
{View} = require '../src/space-pen-extensions'

describe "ViewFactory", ->
  factory = null

  beforeEach ->
    factory = new ViewFactory

  describe "::createView(object, params)", ->
    describe "when passed a DOM node", ->
      it "returns the given DOM node", ->
        node = document.createElement('div')
        expect(factory.createView(node)).toBe node

    describe "when passed a SpacePen view", ->
      it "returns the root node of the view with a __spacePenView property pointing at the SpacePen view", ->
        class TestView extends View
          @content: -> @div "Hello"

        view = new TestView
        node = factory.createView(view)
        expect(node.textContent).toBe "Hello"
        expect(node.__spacePenView).toBe view

    describe "when passed a model object", ->
      describe "when a view provider is registered matching the object's constructor", ->
        describe "when the provider has a viewConstructor property", ->
          it "constructs a view element and calls initialize on it with the creation params", ->
            class TestModel

            class TestModelSubclass extends TestModel

            class TestView
              initialize: (@params) ->

            model = new TestModel

            factory.addViewProvider
              modelConstructor: TestModel
              viewConstructor: TestView

            view = factory.createView(model, a: 1)
            expect(view instanceof TestView).toBe true
            expect(view.params.a).toBe 1
            expect(view.params.model).toBe model

            subclassModel = new TestModelSubclass
            view2 = factory.createView(subclassModel)
            expect(view2 instanceof TestView).toBe true
            expect(view2.params.model).toBe subclassModel

        describe "when the provider has a createView method", ->
          it "constructs a view element by calling the createView method with the creation params", ->
            class TestModel
            class TestView
              initialize: (@params) ->

            factory.addViewProvider
              modelConstructor: TestModel
              createView: (params) ->
                view = new TestView
                view.initialize(params)
                view

            model = new TestModel
            view = factory.createView(model, a: 1)
            expect(view instanceof TestView).toBe true
            expect(view.params.a).toBe 1
            expect(view.params.model).toBe model

      describe "when no view provider is registered for the object's constructor", ->
        describe "when the object has a .createViewClass() method", ->
          beforeEach ->
            jasmine.snapshotDeprecations()

          afterEach ->
            jasmine.restoreDeprecationsSnapshot()

          it "builds an instance of the view class with the model, then returns its root node with a __spacePenView property pointing at the view", ->
            class TestView extends View
              @content: (model) -> @div model.name
              initialize: (@model) ->

            class TestModel
              constructor: (@name) ->
              getViewClass: -> TestView

            model = new TestModel("hello")
            node = factory.createView(model)

            expect(node.textContent).toBe "hello"
            view = node.__spacePenView
            expect(view instanceof TestView).toBe true
            expect(view.model).toBe model

        describe "when the object has no .createViewClass() method", ->
          it "throws an exception", ->
            expect(-> factory.createView(new Object)).toThrow()

  describe "::addViewProvider(providerSpec)", ->
    it "returns a disposable that can be used to remove the provider", ->
      class TestModel
      class TestView
        initialize: ->
      disposable = factory.addViewProvider
        modelConstructor: TestModel
        viewConstructor: TestView

      expect(factory.createView(new TestModel) instanceof TestView).toBe true
      disposable.dispose()
      expect(-> factory.createView(new TestModel)).toThrow()
