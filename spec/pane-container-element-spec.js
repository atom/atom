const PaneContainer = require('../src/pane-container');
const PaneAxis = require('../src/pane-axis');

const params = {
  location: 'center',
  config: atom.config,
  confirm: atom.confirm.bind(atom),
  viewRegistry: atom.views,
  applicationDelegate: atom.applicationDelegate
};

describe('PaneContainerElement', function() {
  describe('when panes are added or removed', function() {
    it('inserts or removes resize elements', function() {
      const childTagNames = () =>
        Array.from(paneAxisElement.children).map(child =>
          child.nodeName.toLowerCase()
        );

      const paneAxis = new PaneAxis({}, atom.views);
      var paneAxisElement = paneAxis.getElement();

      expect(childTagNames()).toEqual([]);

      paneAxis.addChild(new PaneAxis({}, atom.views));
      expect(childTagNames()).toEqual(['atom-pane-axis']);

      paneAxis.addChild(new PaneAxis({}, atom.views));
      expect(childTagNames()).toEqual([
        'atom-pane-axis',
        'atom-pane-resize-handle',
        'atom-pane-axis'
      ]);

      paneAxis.addChild(new PaneAxis({}, atom.views));
      expect(childTagNames()).toEqual([
        'atom-pane-axis',
        'atom-pane-resize-handle',
        'atom-pane-axis',
        'atom-pane-resize-handle',
        'atom-pane-axis'
      ]);

      paneAxis.removeChild(paneAxis.getChildren()[2]);
      expect(childTagNames()).toEqual([
        'atom-pane-axis',
        'atom-pane-resize-handle',
        'atom-pane-axis'
      ]);
    });

    it('transfers focus to the next pane if a focused pane is removed', function() {
      const container = new PaneContainer(params);
      const containerElement = container.getElement();
      const leftPane = container.getActivePane();
      const leftPaneElement = leftPane.getElement();
      const rightPane = leftPane.splitRight();
      const rightPaneElement = rightPane.getElement();

      jasmine.attachToDOM(containerElement);
      rightPaneElement.focus();
      expect(document.activeElement).toBe(rightPaneElement);

      rightPane.destroy();
      expect(containerElement).toHaveClass('panes');
      expect(document.activeElement).toBe(leftPaneElement);
    });
  });

  describe('when a pane is split', () =>
    it('builds appropriately-oriented atom-pane-axis elements', function() {
      const container = new PaneContainer(params);
      const containerElement = container.getElement();

      const pane1 = container.getActivePane();
      const pane2 = pane1.splitRight();
      const pane3 = pane2.splitDown();

      const horizontalPanes = containerElement.querySelectorAll(
        'atom-pane-container > atom-pane-axis.horizontal > atom-pane'
      );
      expect(horizontalPanes.length).toBe(1);
      expect(horizontalPanes[0]).toBe(pane1.getElement());

      let verticalPanes = containerElement.querySelectorAll(
        'atom-pane-container > atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane'
      );
      expect(verticalPanes.length).toBe(2);
      expect(verticalPanes[0]).toBe(pane2.getElement());
      expect(verticalPanes[1]).toBe(pane3.getElement());

      pane1.destroy();
      verticalPanes = containerElement.querySelectorAll(
        'atom-pane-container > atom-pane-axis.vertical > atom-pane'
      );
      expect(verticalPanes.length).toBe(2);
      expect(verticalPanes[0]).toBe(pane2.getElement());
      expect(verticalPanes[1]).toBe(pane3.getElement());
    }));

  describe('when the resize element is dragged ', function() {
    let [container, containerElement] = [];

    beforeEach(function() {
      container = new PaneContainer(params);
      containerElement = container.getElement();
      document.querySelector('#jasmine-content').appendChild(containerElement);
    });

    const dragElementToPosition = function(element, clientX) {
      element.dispatchEvent(
        new MouseEvent('mousedown', {
          view: window,
          bubbles: true,
          button: 0
        })
      );

      element.dispatchEvent(
        new MouseEvent('mousemove', {
          view: window,
          bubbles: true,
          clientX
        })
      );

      element.dispatchEvent(
        new MouseEvent('mouseup', {
          iew: window,
          bubbles: true,
          button: 0
        })
      );
    };

    const getElementWidth = element => element.getBoundingClientRect().width;

    const expectPaneScale = (...pairs) =>
      (() => {
        const result = [];
        for (let [pane, expectedFlexScale] of pairs) {
          result.push(
            expect(pane.getFlexScale()).toBeCloseTo(expectedFlexScale, 0.1)
          );
        }
        return result;
      })();

    const getResizeElement = i =>
      containerElement.querySelectorAll('atom-pane-resize-handle')[i];

    const getPaneElement = i =>
      containerElement.querySelectorAll('atom-pane')[i];

    it('adds and removes panes in the direction that the pane is being dragged', function() {
      const leftPane = container.getActivePane();
      expectPaneScale([leftPane, 1]);

      const middlePane = leftPane.splitRight();
      expectPaneScale([leftPane, 1], [middlePane, 1]);

      dragElementToPosition(
        getResizeElement(0),
        getElementWidth(getPaneElement(0)) / 2
      );
      expectPaneScale([leftPane, 0.5], [middlePane, 1.5]);

      const rightPane = middlePane.splitRight();
      expectPaneScale([leftPane, 0.5], [middlePane, 1.5], [rightPane, 1]);

      dragElementToPosition(
        getResizeElement(1),
        getElementWidth(getPaneElement(0)) +
          getElementWidth(getPaneElement(1)) / 2
      );
      expectPaneScale([leftPane, 0.5], [middlePane, 0.75], [rightPane, 1.75]);

      waitsForPromise(() => middlePane.close());
      runs(() => expectPaneScale([leftPane, 0.44], [rightPane, 1.55]));

      waitsForPromise(() => leftPane.close());
      runs(() => expectPaneScale([rightPane, 1]));
    });

    it('splits or closes panes in orthogonal direction that the pane is being dragged', function() {
      const leftPane = container.getActivePane();
      expectPaneScale([leftPane, 1]);

      const rightPane = leftPane.splitRight();
      expectPaneScale([leftPane, 1], [rightPane, 1]);

      dragElementToPosition(
        getResizeElement(0),
        getElementWidth(getPaneElement(0)) / 2
      );
      expectPaneScale([leftPane, 0.5], [rightPane, 1.5]);

      // dynamically split pane, pane's flexScale will become to 1
      const lowerPane = leftPane.splitDown();
      expectPaneScale(
        [lowerPane, 1],
        [leftPane, 1],
        [leftPane.getParent(), 0.5]
      );

      // dynamically close pane, the pane's flexscale will recover to origin value
      waitsForPromise(() => lowerPane.close());
      runs(() => expectPaneScale([leftPane, 0.5], [rightPane, 1.5]));
    });

    it('unsubscribes from mouse events when the pane is detached', function() {
      container.getActivePane().splitRight();
      const element = getResizeElement(0);
      spyOn(document, 'addEventListener').andCallThrough();
      spyOn(document, 'removeEventListener').andCallThrough();
      spyOn(element, 'resizeStopped').andCallThrough();

      element.dispatchEvent(
        new MouseEvent('mousedown', {
          view: window,
          bubbles: true,
          button: 0
        })
      );

      waitsFor(() => document.addEventListener.callCount === 2);

      runs(function() {
        expect(element.resizeStopped.callCount).toBe(0);
        container.destroy();
        expect(element.resizeStopped.callCount).toBe(1);
        expect(document.removeEventListener.callCount).toBe(2);
      });
    });

    it('does not throw an error when resized to fit content in a detached state', function() {
      container.getActivePane().splitRight();
      const element = getResizeElement(0);
      element.remove();
      expect(() => element.resizeToFitContent()).not.toThrow();
    });
  });

  describe('pane resizing', function() {
    let [leftPane, rightPane] = [];

    beforeEach(function() {
      const container = new PaneContainer(params);
      leftPane = container.getActivePane();
      rightPane = leftPane.splitRight();
    });

    describe('when pane:increase-size is triggered', () =>
      it('increases the size of the pane', function() {
        expect(leftPane.getFlexScale()).toBe(1);
        expect(rightPane.getFlexScale()).toBe(1);

        atom.commands.dispatch(leftPane.getElement(), 'pane:increase-size');
        expect(leftPane.getFlexScale()).toBe(1.1);
        expect(rightPane.getFlexScale()).toBe(1);

        atom.commands.dispatch(rightPane.getElement(), 'pane:increase-size');
        expect(leftPane.getFlexScale()).toBe(1.1);
        expect(rightPane.getFlexScale()).toBe(1.1);
      }));

    describe('when pane:decrease-size is triggered', () =>
      it('decreases the size of the pane', function() {
        expect(leftPane.getFlexScale()).toBe(1);
        expect(rightPane.getFlexScale()).toBe(1);

        atom.commands.dispatch(leftPane.getElement(), 'pane:decrease-size');
        expect(leftPane.getFlexScale()).toBe(1 / 1.1);
        expect(rightPane.getFlexScale()).toBe(1);

        atom.commands.dispatch(rightPane.getElement(), 'pane:decrease-size');
        expect(leftPane.getFlexScale()).toBe(1 / 1.1);
        expect(rightPane.getFlexScale()).toBe(1 / 1.1);
      }));
  });

  describe('when only a single pane is present', function() {
    let [singlePane] = [];

    beforeEach(function() {
      const container = new PaneContainer(params);
      singlePane = container.getActivePane();
    });

    describe('when pane:increase-size is triggered', () =>
      it('does not increases the size of the pane', function() {
        expect(singlePane.getFlexScale()).toBe(1);

        atom.commands.dispatch(singlePane.getElement(), 'pane:increase-size');
        expect(singlePane.getFlexScale()).toBe(1);

        atom.commands.dispatch(singlePane.getElement(), 'pane:increase-size');
        expect(singlePane.getFlexScale()).toBe(1);
      }));

    describe('when pane:decrease-size is triggered', () =>
      it('does not decreases the size of the pane', function() {
        expect(singlePane.getFlexScale()).toBe(1);

        atom.commands.dispatch(singlePane.getElement(), 'pane:decrease-size');
        expect(singlePane.getFlexScale()).toBe(1);

        atom.commands.dispatch(singlePane.getElement(), 'pane:decrease-size');
        expect(singlePane.getFlexScale()).toBe(1);
      }));
  });
});
