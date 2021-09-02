'use strict';

const Panel = require('../src/panel');
const PanelContainer = require('../src/panel-container');

describe('PanelContainer', () => {
  let container;

  class TestPanelItem {}

  beforeEach(() => {
    container = new PanelContainer({ viewRegistry: atom.views });
  });

  describe('::addPanel(panel)', () => {
    it('emits an onDidAddPanel event with the index the panel was inserted at', () => {
      const addPanelSpy = jasmine.createSpy();
      container.onDidAddPanel(addPanelSpy);

      const panel1 = new Panel({ item: new TestPanelItem() }, atom.views);
      container.addPanel(panel1);
      expect(addPanelSpy).toHaveBeenCalledWith({ panel: panel1, index: 0 });

      const panel2 = new Panel({ item: new TestPanelItem() }, atom.views);
      container.addPanel(panel2);
      expect(addPanelSpy).toHaveBeenCalledWith({ panel: panel2, index: 1 });
    });
  });

  describe('when a panel is destroyed', () => {
    it('emits an onDidRemovePanel event with the index of the removed item', () => {
      const removePanelSpy = jasmine.createSpy();
      container.onDidRemovePanel(removePanelSpy);

      const panel1 = new Panel({ item: new TestPanelItem() }, atom.views);
      container.addPanel(panel1);
      const panel2 = new Panel({ item: new TestPanelItem() }, atom.views);
      container.addPanel(panel2);

      expect(removePanelSpy).not.toHaveBeenCalled();

      panel2.destroy();
      expect(removePanelSpy).toHaveBeenCalledWith({ panel: panel2, index: 1 });

      panel1.destroy();
      expect(removePanelSpy).toHaveBeenCalledWith({ panel: panel1, index: 0 });
    });
  });

  describe('::destroy()', () => {
    it('destroys the container and all of its panels', () => {
      const destroyedPanels = [];

      const panel1 = new Panel({ item: new TestPanelItem() }, atom.views);
      panel1.onDidDestroy(() => {
        destroyedPanels.push(panel1);
      });
      container.addPanel(panel1);

      const panel2 = new Panel({ item: new TestPanelItem() }, atom.views);
      panel2.onDidDestroy(() => {
        destroyedPanels.push(panel2);
      });
      container.addPanel(panel2);

      container.destroy();

      expect(container.getPanels().length).toBe(0);
      expect(destroyedPanels).toEqual([panel1, panel2]);
    });
  });

  describe('panel priority', () => {
    describe('left / top panel container', () => {
      let initialPanel;
      beforeEach(() => {
        // 'left' logic is the same as 'top'
        container = new PanelContainer({ location: 'left' });
        initialPanel = new Panel({ item: new TestPanelItem() }, atom.views);
        container.addPanel(initialPanel);
      });

      describe('when a panel with low priority is added', () => {
        it('is inserted at the beginning of the list', () => {
          const addPanelSpy = jasmine.createSpy();
          container.onDidAddPanel(addPanelSpy);
          const panel = new Panel(
            { item: new TestPanelItem(), priority: 0 },
            atom.views
          );
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({ panel, index: 0 });
          expect(container.getPanels()[0]).toBe(panel);
        });
      });

      describe('when a panel with priority between two other panels is added', () => {
        it('is inserted at the between the two panels', () => {
          const addPanelSpy = jasmine.createSpy();
          let panel = new Panel(
            { item: new TestPanelItem(), priority: 1000 },
            atom.views
          );
          container.addPanel(panel);

          container.onDidAddPanel(addPanelSpy);
          panel = new Panel(
            { item: new TestPanelItem(), priority: 101 },
            atom.views
          );
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({ panel, index: 1 });
          expect(container.getPanels()[1]).toBe(panel);
        });
      });
    });

    describe('right / bottom panel container', () => {
      let initialPanel;
      beforeEach(() => {
        // 'bottom' logic is the same as 'right'
        container = new PanelContainer({ location: 'right' });
        initialPanel = new Panel({ item: new TestPanelItem() }, atom.views);
        container.addPanel(initialPanel);
      });

      describe('when a panel with high priority is added', () => {
        it('is inserted at the beginning of the list', () => {
          const addPanelSpy = jasmine.createSpy();
          container.onDidAddPanel(addPanelSpy);
          const panel = new Panel(
            { item: new TestPanelItem(), priority: 1000 },
            atom.views
          );
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({ panel, index: 0 });
          expect(container.getPanels()[0]).toBe(panel);
        });
      });

      describe('when a panel with low priority is added', () => {
        it('is inserted at the end of the list', () => {
          const addPanelSpy = jasmine.createSpy();
          container.onDidAddPanel(addPanelSpy);
          const panel = new Panel(
            { item: new TestPanelItem(), priority: 0 },
            atom.views
          );
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({ panel, index: 1 });
          expect(container.getPanels()[1]).toBe(panel);
        });
      });
    });
  });
});
