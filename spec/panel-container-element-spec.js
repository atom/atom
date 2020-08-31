'use strict';

const Panel = require('../src/panel');
const PanelContainer = require('../src/panel-container');

describe('PanelContainerElement', () => {
  let jasmineContent, element, container;

  class TestPanelContainerItem {}

  class TestPanelContainerItemElement_ extends HTMLElement {
    createdCallback() {
      this.classList.add('test-root');
    }
    initialize(model) {
      this.model = model;
      return this;
    }
    focus() {}
  }

  const TestPanelContainerItemElement = document.registerElement(
    'atom-test-container-item-element',
    { prototype: TestPanelContainerItemElement_.prototype }
  );

  beforeEach(() => {
    jasmineContent = document.body.querySelector('#jasmine-content');

    atom.views.addViewProvider(TestPanelContainerItem, model =>
      new TestPanelContainerItemElement().initialize(model)
    );

    container = new PanelContainer({
      viewRegistry: atom.views,
      location: 'left'
    });
    element = container.getElement();
    jasmineContent.appendChild(element);
  });

  it('has a location class with value from the model', () => {
    expect(element).toHaveClass('left');
  });

  it('removes the element when the container is destroyed', () => {
    expect(element.parentNode).toBe(jasmineContent);
    container.destroy();
    expect(element.parentNode).not.toBe(jasmineContent);
  });

  describe('adding and removing panels', () => {
    it('allows panels to be inserted at any position', () => {
      const panel1 = new Panel(
        { item: new TestPanelContainerItem(), priority: 10 },
        atom.views
      );
      const panel2 = new Panel(
        { item: new TestPanelContainerItem(), priority: 5 },
        atom.views
      );
      const panel3 = new Panel(
        { item: new TestPanelContainerItem(), priority: 8 },
        atom.views
      );

      container.addPanel(panel1);
      container.addPanel(panel2);
      container.addPanel(panel3);

      expect(element.childNodes[2]).toBe(panel1.getElement());
      expect(element.childNodes[1]).toBe(panel3.getElement());
      expect(element.childNodes[0]).toBe(panel2.getElement());
    });

    describe('when the container is at the left location', () =>
      it('adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed', () => {
        expect(element.childNodes.length).toBe(0);

        const panel1 = new Panel(
          { item: new TestPanelContainerItem() },
          atom.views
        );
        container.addPanel(panel1);
        expect(element.childNodes.length).toBe(1);
        expect(element.childNodes[0]).toHaveClass('left');
        expect(element.childNodes[0]).toHaveClass('tool-panel'); // legacy selector support
        expect(element.childNodes[0]).toHaveClass('panel-left'); // legacy selector support

        expect(element.childNodes[0].tagName).toBe('ATOM-PANEL');

        const panel2 = new Panel(
          { item: new TestPanelContainerItem() },
          atom.views
        );
        container.addPanel(panel2);
        expect(element.childNodes.length).toBe(2);

        expect(panel1.getElement().style.display).not.toBe('none');
        expect(panel2.getElement().style.display).not.toBe('none');

        panel1.destroy();
        expect(element.childNodes.length).toBe(1);

        panel2.destroy();
        expect(element.childNodes.length).toBe(0);
      }));

    describe('when the container is at the bottom location', () => {
      beforeEach(() => {
        container = new PanelContainer({
          viewRegistry: atom.views,
          location: 'bottom'
        });
        element = container.getElement();
        jasmineContent.appendChild(element);
      });

      it('adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed', () => {
        expect(element.childNodes.length).toBe(0);

        const panel1 = new Panel(
          { item: new TestPanelContainerItem(), className: 'one' },
          atom.views
        );
        container.addPanel(panel1);
        expect(element.childNodes.length).toBe(1);
        expect(element.childNodes[0]).toHaveClass('bottom');
        expect(element.childNodes[0]).toHaveClass('tool-panel'); // legacy selector support
        expect(element.childNodes[0]).toHaveClass('panel-bottom'); // legacy selector support
        expect(element.childNodes[0].tagName).toBe('ATOM-PANEL');
        expect(panel1.getElement()).toHaveClass('one');

        const panel2 = new Panel(
          { item: new TestPanelContainerItem(), className: 'two' },
          atom.views
        );
        container.addPanel(panel2);
        expect(element.childNodes.length).toBe(2);
        expect(panel2.getElement()).toHaveClass('two');

        panel1.destroy();
        expect(element.childNodes.length).toBe(1);

        panel2.destroy();
        expect(element.childNodes.length).toBe(0);
      });
    });
  });

  describe('when the container is modal', () => {
    beforeEach(() => {
      container = new PanelContainer({
        viewRegistry: atom.views,
        location: 'modal'
      });
      element = container.getElement();
      jasmineContent.appendChild(element);
    });

    it('allows only one panel to be visible at a time', () => {
      const panel1 = new Panel(
        { item: new TestPanelContainerItem() },
        atom.views
      );
      container.addPanel(panel1);

      expect(panel1.getElement().style.display).not.toBe('none');

      const panel2 = new Panel(
        { item: new TestPanelContainerItem() },
        atom.views
      );
      container.addPanel(panel2);

      expect(panel1.getElement().style.display).toBe('none');
      expect(panel2.getElement().style.display).not.toBe('none');

      panel1.show();

      expect(panel1.getElement().style.display).not.toBe('none');
      expect(panel2.getElement().style.display).toBe('none');
    });

    it("adds the 'modal' class to panels", () => {
      const panel1 = new Panel(
        { item: new TestPanelContainerItem() },
        atom.views
      );
      container.addPanel(panel1);

      expect(panel1.getElement()).toHaveClass('modal');

      // legacy selector support
      expect(panel1.getElement()).not.toHaveClass('tool-panel');
      expect(panel1.getElement()).toHaveClass('overlay');
      expect(panel1.getElement()).toHaveClass('from-top');
    });

    describe('autoFocus', () => {
      function createPanel(autoFocus = true) {
        const panel = new Panel(
          {
            item: new TestPanelContainerItem(),
            autoFocus: autoFocus,
            visible: false
          },
          atom.views
        );

        container.addPanel(panel);
        return panel;
      }

      it('focuses the first tabbable item if available', () => {
        const panel = createPanel();
        const panelEl = panel.getElement();
        const inputEl = document.createElement('input');

        panelEl.appendChild(inputEl);
        expect(document.activeElement).not.toBe(inputEl);

        panel.show();
        expect(document.activeElement).toBe(inputEl);
      });

      it('focuses the autoFocus element if available', () => {
        const inputEl1 = document.createElement('input');
        const inputEl2 = document.createElement('input');
        const panel = createPanel(inputEl2);
        const panelEl = panel.getElement();

        panelEl.appendChild(inputEl1);
        panelEl.appendChild(inputEl2);
        expect(document.activeElement).not.toBe(inputEl2);

        panel.show();
        expect(document.activeElement).toBe(inputEl2);
      });

      it('focuses the entire panel item when no tabbable item is available and the panel is focusable', () => {
        const panel = createPanel();
        const panelEl = panel.getElement();

        spyOn(panelEl, 'focus');
        panel.show();
        expect(panelEl.focus).toHaveBeenCalled();
      });

      it('returns focus to the original activeElement', () => {
        const panel = createPanel();
        const previousActiveElement = document.activeElement;
        const panelEl = panel.getElement();
        panelEl.appendChild(document.createElement('input'));

        panel.show();
        panel.hide();

        waitsFor(() => document.activeElement === previousActiveElement);
        runs(() => {
          expect(document.activeElement).toBe(previousActiveElement);
        });
      });
    });
  });
});
