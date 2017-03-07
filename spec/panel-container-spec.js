const Panel = require('../src/panel');
const PanelContainer = require('../src/panel-container');

describe("PanelContainer", function() {
  let [container] = Array.from([]);

  class TestPanelItem {
    constructor() {}
  }

  beforeEach(() => container = new PanelContainer);

  describe("::addPanel(panel)", () =>
    it('emits an onDidAddPanel event with the index the panel was inserted at', function() {
      let addPanelSpy;
      container.onDidAddPanel(addPanelSpy = jasmine.createSpy());

      const panel1 = new Panel({item: new TestPanelItem()});
      container.addPanel(panel1);
      expect(addPanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0});

      const panel2 = new Panel({item: new TestPanelItem()});
      container.addPanel(panel2);
      return expect(addPanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1});
    })
  );

  describe("when a panel is destroyed", () =>
    it('emits an onDidRemovePanel event with the index of the removed item', function() {
      let removePanelSpy;
      container.onDidRemovePanel(removePanelSpy = jasmine.createSpy());

      const panel1 = new Panel({item: new TestPanelItem()});
      container.addPanel(panel1);
      const panel2 = new Panel({item: new TestPanelItem()});
      container.addPanel(panel2);

      expect(removePanelSpy).not.toHaveBeenCalled();

      panel2.destroy();
      expect(removePanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1});

      panel1.destroy();
      return expect(removePanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0});
    })
  );

  describe("::destroy()", () =>
    it("destroys the container and all of its panels", function() {
      const destroyedPanels = [];

      const panel1 = new Panel({item: new TestPanelItem()});
      panel1.onDidDestroy(() => destroyedPanels.push(panel1));
      container.addPanel(panel1);

      const panel2 = new Panel({item: new TestPanelItem()});
      panel2.onDidDestroy(() => destroyedPanels.push(panel2));
      container.addPanel(panel2);

      container.destroy();

      expect(container.getPanels().length).toBe(0);
      return expect(destroyedPanels).toEqual([panel1, panel2]);
    })
  );

  return describe("panel priority", function() {
    describe('left / top panel container', function() {
      let [initialPanel] = Array.from([]);
      beforeEach(function() {
        // 'left' logic is the same as 'top'
        container = new PanelContainer({location: 'left'});
        initialPanel = new Panel({item: new TestPanelItem()});
        return container.addPanel(initialPanel);
      });

      describe('when a panel with low priority is added', () =>
        it('is inserted at the beginning of the list', function() {
          let addPanelSpy;
          container.onDidAddPanel(addPanelSpy = jasmine.createSpy());
          const panel = new Panel({item: new TestPanelItem(), priority: 0});
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0});
          return expect(container.getPanels()[0]).toBe(panel);
        })
      );

      return describe('when a panel with priority between two other panels is added', () =>
        it('is inserted at the between the two panels', function() {
          let addPanelSpy;
          let panel = new Panel({item: new TestPanelItem(), priority: 1000});
          container.addPanel(panel);

          container.onDidAddPanel(addPanelSpy = jasmine.createSpy());
          panel = new Panel({item: new TestPanelItem(), priority: 101});
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 1});
          return expect(container.getPanels()[1]).toBe(panel);
        })
      );
    });

    return describe('right / bottom panel container', function() {
      let [initialPanel] = Array.from([]);
      beforeEach(function() {
        // 'bottom' logic is the same as 'right'
        container = new PanelContainer({location: 'right'});
        initialPanel = new Panel({item: new TestPanelItem()});
        return container.addPanel(initialPanel);
      });

      describe('when a panel with high priority is added', () =>
        it('is inserted at the beginning of the list', function() {
          let addPanelSpy;
          container.onDidAddPanel(addPanelSpy = jasmine.createSpy());
          const panel = new Panel({item: new TestPanelItem(), priority: 1000});
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0});
          return expect(container.getPanels()[0]).toBe(panel);
        })
      );

      return describe('when a panel with low priority is added', () =>
        it('is inserted at the end of the list', function() {
          let addPanelSpy;
          container.onDidAddPanel(addPanelSpy = jasmine.createSpy());
          const panel = new Panel({item: new TestPanelItem(), priority: 0});
          container.addPanel(panel);

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 1});
          return expect(container.getPanels()[1]).toBe(panel);
        })
      );
    });
  });
});
