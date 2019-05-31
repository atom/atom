const Grim = require('grim');
const { Disposable } = require('event-kit');

const AnyConstructor = Symbol('any-constructor');

// Essential: `ViewRegistry` handles the association between model and view
// types in Atom. We call this association a View Provider. As in, for a given
// model, this class can provide a view via {::getView}, as long as the
// model/view association was registered via {::addViewProvider}
//
// If you're adding your own kind of pane item, a good strategy for all but the
// simplest items is to separate the model and the view. The model handles
// application logic and is the primary point of API interaction. The view
// just handles presentation.
//
// Note: Models can be any object, but must implement a `getTitle()` function
// if they are to be displayed in a {Pane}
//
// View providers inform the workspace how your model objects should be
// presented in the DOM. A view provider must always return a DOM node, which
// makes [HTML 5 custom elements](http://www.html5rocks.com/en/tutorials/webcomponents/customelements/)
// an ideal tool for implementing views in Atom.
//
// You can access the `ViewRegistry` object via `atom.views`.
module.exports = class ViewRegistry {
  constructor(atomEnvironment) {
    this.animationFrameRequest = null;
    this.documentReadInProgress = false;
    this.performDocumentUpdate = this.performDocumentUpdate.bind(this);
    this.atomEnvironment = atomEnvironment;
    this.clear();
  }

  clear() {
    this.views = new WeakMap();
    this.providers = [];
    this.clearDocumentRequests();
  }

  // Essential: Add a provider that will be used to construct views in the
  // workspace's view layer based on model objects in its model layer.
  //
  // ## Examples
  //
  // Text editors are divided into a model and a view layer, so when you interact
  // with methods like `atom.workspace.getActiveTextEditor()` you're only going
  // to get the model object. We display text editors on screen by teaching the
  // workspace what view constructor it should use to represent them:
  //
  // ```coffee
  // atom.views.addViewProvider TextEditor, (textEditor) ->
  //   textEditorElement = new TextEditorElement
  //   textEditorElement.initialize(textEditor)
  //   textEditorElement
  // ```
  //
  // * `modelConstructor` (optional) Constructor {Function} for your model. If
  //   a constructor is given, the `createView` function will only be used
  //   for model objects inheriting from that constructor. Otherwise, it will
  //   will be called for any object.
  // * `createView` Factory {Function} that is passed an instance of your model
  //   and must return a subclass of `HTMLElement` or `undefined`. If it returns
  //   `undefined`, then the registry will continue to search for other view
  //   providers.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // added provider.
  addViewProvider(modelConstructor, createView) {
    let provider;
    if (arguments.length === 1) {
      switch (typeof modelConstructor) {
        case 'function':
          provider = {
            createView: modelConstructor,
            modelConstructor: AnyConstructor
          };
          break;
        case 'object':
          Grim.deprecate(
            'atom.views.addViewProvider now takes 2 arguments: a model constructor and a createView function. See docs for details.'
          );
          provider = modelConstructor;
          break;
        default:
          throw new TypeError('Arguments to addViewProvider must be functions');
      }
    } else {
      provider = { modelConstructor, createView };
    }

    this.providers.push(provider);
    return new Disposable(() => {
      this.providers = this.providers.filter(p => p !== provider);
    });
  }

  getViewProviderCount() {
    return this.providers.length;
  }

  // Essential: Get the view associated with an object in the workspace.
  //
  // If you're just *using* the workspace, you shouldn't need to access the view
  // layer, but view layer access may be necessary if you want to perform DOM
  // manipulation that isn't supported via the model API.
  //
  // ## View Resolution Algorithm
  //
  // The view associated with the object is resolved using the following
  // sequence
  //
  //  1. Is the object an instance of `HTMLElement`? If true, return the object.
  //  2. Does the object have a method named `getElement` that returns an
  //     instance of `HTMLElement`? If true, return that value.
  //  3. Does the object have a property named `element` with a value which is
  //     an instance of `HTMLElement`? If true, return the property value.
  //  4. Is the object a jQuery object, indicated by the presence of a `jquery`
  //     property? If true, return the root DOM element (i.e. `object[0]`).
  //  5. Has a view provider been registered for the object? If true, use the
  //     provider to create a view associated with the object, and return the
  //     view.
  //
  // If no associated view is returned by the sequence an error is thrown.
  //
  // Returns a DOM element.
  getView(object) {
    if (object == null) {
      return;
    }

    let view = this.views.get(object);
    if (!view) {
      view = this.createView(object);
      this.views.set(object, view);
    }
    return view;
  }

  createView(object) {
    if (object instanceof HTMLElement) {
      return object;
    }

    let element;
    if (object && typeof object.getElement === 'function') {
      element = object.getElement();
      if (element instanceof HTMLElement) {
        return element;
      }
    }

    if (object && object.element instanceof HTMLElement) {
      return object.element;
    }

    if (object && object.jquery) {
      return object[0];
    }

    for (let provider of this.providers) {
      if (provider.modelConstructor === AnyConstructor) {
        element = provider.createView(object, this.atomEnvironment);
        if (element) {
          return element;
        }
        continue;
      }

      if (object instanceof provider.modelConstructor) {
        element =
          provider.createView &&
          provider.createView(object, this.atomEnvironment);
        if (element) {
          return element;
        }

        let ViewConstructor = provider.viewConstructor;
        if (ViewConstructor) {
          element = new ViewConstructor();
          if (element.initialize) {
            element.initialize(object);
          } else if (element.setModel) {
            element.setModel(object);
          }
          return element;
        }
      }
    }

    if (object && object.getViewClass) {
      let ViewConstructor = object.getViewClass();
      if (ViewConstructor) {
        const view = new ViewConstructor(object);
        return view[0];
      }
    }

    throw new Error(
      `Can't create a view for ${
        object.constructor.name
      } instance. Please register a view provider.`
    );
  }

  updateDocument(fn) {
    this.documentWriters.push(fn);
    if (!this.documentReadInProgress) {
      this.requestDocumentUpdate();
    }
    return new Disposable(() => {
      this.documentWriters = this.documentWriters.filter(
        writer => writer !== fn
      );
    });
  }

  readDocument(fn) {
    this.documentReaders.push(fn);
    this.requestDocumentUpdate();
    return new Disposable(() => {
      this.documentReaders = this.documentReaders.filter(
        reader => reader !== fn
      );
    });
  }

  getNextUpdatePromise() {
    if (this.nextUpdatePromise == null) {
      this.nextUpdatePromise = new Promise(resolve => {
        this.resolveNextUpdatePromise = resolve;
      });
    }

    return this.nextUpdatePromise;
  }

  clearDocumentRequests() {
    this.documentReaders = [];
    this.documentWriters = [];
    this.nextUpdatePromise = null;
    this.resolveNextUpdatePromise = null;
    if (this.animationFrameRequest != null) {
      cancelAnimationFrame(this.animationFrameRequest);
      this.animationFrameRequest = null;
    }
  }

  requestDocumentUpdate() {
    if (this.animationFrameRequest == null) {
      this.animationFrameRequest = requestAnimationFrame(
        this.performDocumentUpdate
      );
    }
  }

  performDocumentUpdate() {
    const { resolveNextUpdatePromise } = this;
    this.animationFrameRequest = null;
    this.nextUpdatePromise = null;
    this.resolveNextUpdatePromise = null;

    var writer = this.documentWriters.shift();
    while (writer) {
      writer();
      writer = this.documentWriters.shift();
    }

    var reader = this.documentReaders.shift();
    this.documentReadInProgress = true;
    while (reader) {
      reader();
      reader = this.documentReaders.shift();
    }
    this.documentReadInProgress = false;

    // process updates requested as a result of reads
    writer = this.documentWriters.shift();
    while (writer) {
      writer();
      writer = this.documentWriters.shift();
    }

    if (resolveNextUpdatePromise) {
      resolveNextUpdatePromise();
    }
  }
};
