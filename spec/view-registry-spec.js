/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const ViewRegistry = require('../src/view-registry');

describe('ViewRegistry', () => {
  let registry = null;

  beforeEach(() => {
    registry = new ViewRegistry();
  });

  afterEach(() => {
    registry.clearDocumentRequests();
  });

  describe('::getView(object)', () => {
    describe('when passed a DOM node', () =>
      it('returns the given DOM node', () => {
        const node = document.createElement('div');
        expect(registry.getView(node)).toBe(node);
      }));

    describe('when passed an object with an element property', () =>
      it("returns the element property if it's an instance of HTMLElement", () => {
        class TestComponent {
          constructor() {
            this.element = document.createElement('div');
          }
        }

        const component = new TestComponent();
        expect(registry.getView(component)).toBe(component.element);
      }));

    describe('when passed an object with a getElement function', () =>
      it("returns the return value of getElement if it's an instance of HTMLElement", () => {
        class TestComponent {
          getElement() {
            if (this.myElement == null) {
              this.myElement = document.createElement('div');
            }
            return this.myElement;
          }
        }

        const component = new TestComponent();
        expect(registry.getView(component)).toBe(component.myElement);
      }));

    describe('when passed a model object', () => {
      describe("when a view provider is registered matching the object's constructor", () =>
        it('constructs a view element and assigns the model on it', () => {
          class TestModel {}

          class TestModelSubclass extends TestModel {}

          class TestView {
            initialize(model) {
              this.model = model;
              return this;
            }
          }

          const model = new TestModel();

          registry.addViewProvider(TestModel, model =>
            new TestView().initialize(model)
          );

          const view = registry.getView(model);
          expect(view instanceof TestView).toBe(true);
          expect(view.model).toBe(model);

          const subclassModel = new TestModelSubclass();
          const view2 = registry.getView(subclassModel);
          expect(view2 instanceof TestView).toBe(true);
          expect(view2.model).toBe(subclassModel);
        }));

      describe('when a view provider is registered generically, and works with the object', () =>
        it('constructs a view element and assigns the model on it', () => {
          registry.addViewProvider(model => {
            if (model.a === 'b') {
              const element = document.createElement('div');
              element.className = 'test-element';
              return element;
            }
          });

          const view = registry.getView({ a: 'b' });
          expect(view.className).toBe('test-element');

          expect(() => registry.getView({ a: 'c' })).toThrow();
        }));

      describe("when no view provider is registered for the object's constructor", () =>
        it('throws an exception', () => {
          expect(() => registry.getView({})).toThrow();
        }));
    });
  });

  describe('::addViewProvider(providerSpec)', () =>
    it('returns a disposable that can be used to remove the provider', () => {
      class TestModel {}
      class TestView {
        initialize(model) {
          this.model = model;
          return this;
        }
      }

      const disposable = registry.addViewProvider(TestModel, model =>
        new TestView().initialize(model)
      );

      expect(registry.getView(new TestModel()) instanceof TestView).toBe(true);
      disposable.dispose();
      expect(() => registry.getView(new TestModel())).toThrow();
    }));

  describe('::updateDocument(fn) and ::readDocument(fn)', () => {
    let frameRequests = null;

    beforeEach(() => {
      frameRequests = [];
      spyOn(window, 'requestAnimationFrame').andCallFake(fn =>
        frameRequests.push(fn)
      );
    });

    it('performs all pending writes before all pending reads on the next animation frame', () => {
      let events = [];

      registry.updateDocument(() => events.push('write 1'));
      registry.readDocument(() => events.push('read 1'));
      registry.readDocument(() => events.push('read 2'));
      registry.updateDocument(() => events.push('write 2'));

      expect(events).toEqual([]);

      expect(frameRequests.length).toBe(1);
      frameRequests[0]();
      expect(events).toEqual(['write 1', 'write 2', 'read 1', 'read 2']);

      frameRequests = [];
      events = [];
      const disposable = registry.updateDocument(() => events.push('write 3'));
      registry.updateDocument(() => events.push('write 4'));
      registry.readDocument(() => events.push('read 3'));

      disposable.dispose();

      expect(frameRequests.length).toBe(1);
      frameRequests[0]();
      expect(events).toEqual(['write 4', 'read 3']);
    });

    it('performs writes requested from read callbacks in the same animation frame', () => {
      spyOn(window, 'setInterval').andCallFake(fakeSetInterval);
      spyOn(window, 'clearInterval').andCallFake(fakeClearInterval);
      const events = [];

      registry.updateDocument(() => events.push('write 1'));
      registry.readDocument(() => {
        registry.updateDocument(() => events.push('write from read 1'));
        events.push('read 1');
      });
      registry.readDocument(() => {
        registry.updateDocument(() => events.push('write from read 2'));
        events.push('read 2');
      });
      registry.updateDocument(() => events.push('write 2'));

      expect(frameRequests.length).toBe(1);
      frameRequests[0]();
      expect(frameRequests.length).toBe(1);

      expect(events).toEqual([
        'write 1',
        'write 2',
        'read 1',
        'read 2',
        'write from read 1',
        'write from read 2'
      ]);
    });
  });

  describe('::getNextUpdatePromise()', () =>
    it('returns a promise that resolves at the end of the next update cycle', () => {
      let updateCalled = false;
      let readCalled = false;

      waitsFor('getNextUpdatePromise to resolve', done => {
        registry.getNextUpdatePromise().then(() => {
          expect(updateCalled).toBe(true);
          expect(readCalled).toBe(true);
          done();
        });

        registry.updateDocument(() => {
          updateCalled = true;
        });
        registry.readDocument(() => {
          readCalled = true;
        });
      });
    }));
});
