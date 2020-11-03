const PaneContainer = require('../src/pane-container');

describe('PaneElement', function() {
  let [paneElement, container, containerElement, pane] = [];

  beforeEach(function() {
    spyOn(atom.applicationDelegate, 'open');

    container = new PaneContainer({
      location: 'center',
      config: atom.config,
      confirm: atom.confirm.bind(atom),
      viewRegistry: atom.views,
      applicationDelegate: atom.applicationDelegate
    });
    containerElement = container.getElement();
    pane = container.getActivePane();
    paneElement = pane.getElement();
  });

  describe("when the pane's active status changes", () =>
    it('adds or removes the .active class as appropriate', function() {
      const pane2 = pane.splitRight();
      expect(pane2.isActive()).toBe(true);

      expect(paneElement.className).not.toMatch(/active/);
      pane.activate();
      expect(paneElement.className).toMatch(/active/);
      pane2.activate();
      expect(paneElement.className).not.toMatch(/active/);
    }));

  describe('when the active item changes', function() {
    it('hides all item elements except the active one', function() {
      const item1 = document.createElement('div');
      const item2 = document.createElement('div');
      const item3 = document.createElement('div');
      pane.addItem(item1);
      pane.addItem(item2);
      pane.addItem(item3);

      expect(pane.getActiveItem()).toBe(item1);
      expect(item1.parentElement).toBeDefined();
      expect(item1.style.display).toBe('');
      expect(item2.parentElement).toBeNull();
      expect(item3.parentElement).toBeNull();

      pane.activateItem(item2);
      expect(item2.parentElement).toBeDefined();
      expect(item1.style.display).toBe('none');
      expect(item2.style.display).toBe('');
      expect(item3.parentElement).toBeNull();

      pane.activateItem(item3);
      expect(item3.parentElement).toBeDefined();
      expect(item1.style.display).toBe('none');
      expect(item2.style.display).toBe('none');
      expect(item3.style.display).toBe('');
    });

    it('transfers focus to the new item if the previous item was focused', function() {
      const item1 = document.createElement('div');
      item1.tabIndex = -1;
      const item2 = document.createElement('div');
      item2.tabIndex = -1;
      pane.addItem(item1);
      pane.addItem(item2);
      jasmine.attachToDOM(paneElement);
      paneElement.focus();

      expect(document.activeElement).toBe(item1);
      pane.activateItem(item2);
      expect(document.activeElement).toBe(item2);
    });

    describe('if the active item is a model object', () =>
      it('retrieves the associated view from atom.views and appends it to the itemViews div', function() {
        class TestModel {}

        atom.views.addViewProvider(TestModel, function(model) {
          const view = document.createElement('div');
          view.model = model;
          return view;
        });

        const item1 = new TestModel();
        const item2 = new TestModel();
        pane.addItem(item1);
        pane.addItem(item2);

        expect(paneElement.itemViews.children[0].model).toBe(item1);
        expect(paneElement.itemViews.children[0].style.display).toBe('');
        pane.activateItem(item2);
        expect(paneElement.itemViews.children[1].model).toBe(item2);
        expect(paneElement.itemViews.children[0].style.display).toBe('none');
        expect(paneElement.itemViews.children[1].style.display).toBe('');
      }));

    describe('when the new active implements .getPath()', function() {
      it('adds the file path and file name as a data attribute on the pane', function() {
        const item1 = document.createElement('div');
        item1.getPath = () => '/foo/bar.txt';
        const item2 = document.createElement('div');
        pane.addItem(item1);
        pane.addItem(item2);

        expect(paneElement.dataset.activeItemPath).toBe('/foo/bar.txt');
        expect(paneElement.dataset.activeItemName).toBe('bar.txt');

        pane.activateItem(item2);

        expect(paneElement.dataset.activeItemPath).toBeUndefined();
        expect(paneElement.dataset.activeItemName).toBeUndefined();

        pane.activateItem(item1);
        expect(paneElement.dataset.activeItemPath).toBe('/foo/bar.txt');
        expect(paneElement.dataset.activeItemName).toBe('bar.txt');

        pane.destroyItems();
        expect(paneElement.dataset.activeItemPath).toBeUndefined();
        expect(paneElement.dataset.activeItemName).toBeUndefined();
      });

      describe('when the path of the item changes', function() {
        let [item1, item2] = [];

        beforeEach(function() {
          item1 = document.createElement('div');
          item1.path = '/foo/bar.txt';
          item1.changePathCallbacks = [];
          item1.setPath = function(path) {
            this.path = path;
            for (let callback of Array.from(this.changePathCallbacks)) {
              callback();
            }
          };
          item1.getPath = function() {
            return this.path;
          };
          item1.onDidChangePath = function(callback) {
            this.changePathCallbacks.push(callback);
            return {
              dispose: () => {
                this.changePathCallbacks = this.changePathCallbacks.filter(
                  f => f !== callback
                );
              }
            };
          };

          item2 = document.createElement('div');

          pane.addItem(item1);
          pane.addItem(item2);
        });

        it('changes the file path and file name data attributes on the pane if the active item path is changed', function() {
          expect(paneElement.dataset.activeItemPath).toBe('/foo/bar.txt');
          expect(paneElement.dataset.activeItemName).toBe('bar.txt');

          item1.setPath('/foo/bar1.txt');

          expect(paneElement.dataset.activeItemPath).toBe('/foo/bar1.txt');
          expect(paneElement.dataset.activeItemName).toBe('bar1.txt');

          pane.activateItem(item2);

          expect(paneElement.dataset.activeItemPath).toBeUndefined();
          expect(paneElement.dataset.activeItemName).toBeUndefined();

          item1.setPath('/foo/bar2.txt');

          expect(paneElement.dataset.activeItemPath).toBeUndefined();
          expect(paneElement.dataset.activeItemName).toBeUndefined();

          pane.activateItem(item1);

          expect(paneElement.dataset.activeItemPath).toBe('/foo/bar2.txt');
          expect(paneElement.dataset.activeItemName).toBe('bar2.txt');
        });
      });
    });
  });

  describe('when an item is removed from the pane', function() {
    describe('when the destroyed item is an element', () =>
      it('removes the item from the itemViews div', function() {
        const item1 = document.createElement('div');
        const item2 = document.createElement('div');
        pane.addItem(item1);
        pane.addItem(item2);
        paneElement = pane.getElement();

        expect(item1.parentElement).toBe(paneElement.itemViews);
        pane.destroyItem(item1);
        expect(item1.parentElement).toBeNull();
        expect(item2.parentElement).toBe(paneElement.itemViews);
        pane.destroyItem(item2);
        expect(item2.parentElement).toBeNull();
      }));

    describe('when the destroyed item is a model', () =>
      it("removes the model's associated view", function() {
        class TestModel {}

        atom.views.addViewProvider(TestModel, function(model) {
          const view = document.createElement('div');
          model.element = view;
          view.model = model;
          return view;
        });

        const item1 = new TestModel();
        const item2 = new TestModel();
        pane.addItem(item1);
        pane.addItem(item2);

        expect(item1.element.parentElement).toBe(paneElement.itemViews);
        pane.destroyItem(item1);
        expect(item1.element.parentElement).toBeNull();
        expect(item2.element.parentElement).toBe(paneElement.itemViews);
        pane.destroyItem(item2);
        expect(item2.element.parentElement).toBeNull();
      }));
  });

  describe('when the pane element is focused', function() {
    it('transfers focus to the active view', function() {
      const item = document.createElement('div');
      item.tabIndex = -1;
      pane.activateItem(item);
      jasmine.attachToDOM(paneElement);

      expect(document.activeElement).toBe(document.body);
      paneElement.focus();
      expect(document.activeElement).toBe(item);

      document.body.focus();
      pane.activate();
      expect(document.activeElement).toBe(item);
    });

    it('makes the pane active', function() {
      pane.splitRight();
      expect(pane.isActive()).toBe(false);

      jasmine.attachToDOM(paneElement);
      paneElement.focus();

      expect(pane.isActive()).toBe(true);
    });

    it('does not re-activate the pane when focus changes within the pane', function() {
      const item = document.createElement('div');
      const itemChild = document.createElement('div');
      item.tabIndex = -1;
      itemChild.tabIndex = -1;
      item.appendChild(itemChild);
      jasmine.attachToDOM(paneElement);

      pane.activateItem(item);
      pane.activate();

      let activationCount = 0;
      pane.onDidActivate(() => activationCount++);

      itemChild.focus();
      expect(activationCount).toBe(0);
    });
  });

  describe('when the pane element is attached', () =>
    it('focuses the pane element if isFocused() returns true on its model', function() {
      pane.focus();
      jasmine.attachToDOM(paneElement);
      expect(document.activeElement).toBe(paneElement);
    }));

  describe('drag and drop', function() {
    const buildDragEvent = function(type, files) {
      const dataTransfer = {
        files,
        data: {},
        setData(key, value) {
          this.data[key] = value;
        },
        getData(key) {
          return this.data[key];
        }
      };

      const event = new CustomEvent('drop');
      event.dataTransfer = dataTransfer;
      return event;
    };

    describe('when a file is dragged to the pane', () =>
      it('opens it', function() {
        const event = buildDragEvent('drop', [
          { path: '/fake1' },
          { path: '/fake2' }
        ]);
        paneElement.dispatchEvent(event);
        expect(atom.applicationDelegate.open.callCount).toBe(1);
        expect(atom.applicationDelegate.open.argsForCall[0][0]).toEqual({
          pathsToOpen: ['/fake1', '/fake2'],
          here: true
        });
      }));

    describe('when a non-file is dragged to the pane', () =>
      it('does nothing', function() {
        const event = buildDragEvent('drop', []);
        paneElement.dispatchEvent(event);
        expect(atom.applicationDelegate.open).not.toHaveBeenCalled();
      }));
  });

  describe('resize', () =>
    it("shrinks independently of its contents' width", function() {
      jasmine.attachToDOM(containerElement);
      const item = document.createElement('div');
      item.style.width = '2000px';
      item.style.height = '30px';
      paneElement.insertBefore(item, paneElement.children[0]);

      paneElement.style.flexGrow = 0.1;
      expect(paneElement.getBoundingClientRect().width).toBeGreaterThan(0);
      expect(paneElement.getBoundingClientRect().width).toBeLessThan(
        item.getBoundingClientRect().width
      );

      paneElement.style.flexGrow = 0;
      expect(paneElement.getBoundingClientRect().width).toBe(0);
    }));
});
