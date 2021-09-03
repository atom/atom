const { CompositeDisposable } = require('atom');
const TooltipManager = require('../src/tooltip-manager');
const Tooltip = require('../src/tooltip');
const _ = require('underscore-plus');

describe('TooltipManager', () => {
  let manager, element;

  const ctrlX = _.humanizeKeystroke('ctrl-x');
  const ctrlY = _.humanizeKeystroke('ctrl-y');

  const hover = function(element, fn) {
    mouseEnter(element);
    advanceClock(manager.hoverDefaults.delay.show);
    fn();
    mouseLeave(element);
    advanceClock(manager.hoverDefaults.delay.hide);
  };

  beforeEach(function() {
    manager = new TooltipManager({
      keymapManager: atom.keymaps,
      viewRegistry: atom.views
    });
    element = createElement('foo');
  });

  describe('::add(target, options)', () => {
    describe("when the trigger is 'hover' (the default)", () => {
      it('creates a tooltip when hovering over the target element', () => {
        manager.add(element, { title: 'Title' });
        hover(element, () =>
          expect(document.body.querySelector('.tooltip')).toHaveText('Title')
        );
      });

      it('displays tooltips immediately when hovering over new elements once a tooltip has been displayed once', () => {
        const disposables = new CompositeDisposable();
        const element1 = createElement('foo');
        disposables.add(manager.add(element1, { title: 'Title' }));
        const element2 = createElement('bar');
        disposables.add(manager.add(element2, { title: 'Title' }));
        const element3 = createElement('baz');
        disposables.add(manager.add(element3, { title: 'Title' }));

        hover(element1, () => {});
        expect(document.body.querySelector('.tooltip')).toBeNull();

        mouseEnter(element2);
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        mouseLeave(element2);
        advanceClock(manager.hoverDefaults.delay.hide);
        expect(document.body.querySelector('.tooltip')).toBeNull();

        advanceClock(Tooltip.FOLLOW_THROUGH_DURATION);
        mouseEnter(element3);
        expect(document.body.querySelector('.tooltip')).toBeNull();
        advanceClock(manager.hoverDefaults.delay.show);
        expect(document.body.querySelector('.tooltip')).not.toBeNull();

        disposables.dispose();
      });

      it('hides the tooltip on keydown events', () => {
        const disposable = manager.add(element, {
          title: 'Title',
          trigger: 'hover'
        });
        hover(element, function() {
          expect(document.body.querySelector('.tooltip')).not.toBeNull();
          window.dispatchEvent(
            new CustomEvent('keydown', {
              bubbles: true
            })
          );
          expect(document.body.querySelector('.tooltip')).toBeNull();
          disposable.dispose();
        });
      });
    });

    describe("when the trigger is 'manual'", () =>
      it('creates a tooltip immediately and only hides it on dispose', () => {
        const disposable = manager.add(element, {
          title: 'Title',
          trigger: 'manual'
        });
        expect(document.body.querySelector('.tooltip')).toHaveText('Title');
        disposable.dispose();
        expect(document.body.querySelector('.tooltip')).toBeNull();
      }));

    describe("when the trigger is 'click'", () =>
      it('shows and hides the tooltip when the target element is clicked', () => {
        manager.add(element, { title: 'Title', trigger: 'click' });
        expect(document.body.querySelector('.tooltip')).toBeNull();
        element.click();
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        element.click();
        expect(document.body.querySelector('.tooltip')).toBeNull();

        // Hide the tooltip when clicking anywhere but inside the tooltip element
        element.click();
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        document.body.querySelector('.tooltip').click();
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        document.body.querySelector('.tooltip').firstChild.click();
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        document.body.click();
        expect(document.body.querySelector('.tooltip')).toBeNull();

        // Tooltip can show again after hiding due to clicking outside of the tooltip
        element.click();
        expect(document.body.querySelector('.tooltip')).not.toBeNull();
        element.click();
        expect(document.body.querySelector('.tooltip')).toBeNull();
      }));

    it('does not hide the tooltip on keyboard input', () => {
      manager.add(element, { title: 'Title', trigger: 'click' });
      element.click();
      expect(document.body.querySelector('.tooltip')).not.toBeNull();
      window.dispatchEvent(
        new CustomEvent('keydown', {
          bubbles: true
        })
      );
      expect(document.body.querySelector('.tooltip')).not.toBeNull();
      // click again to hide the tooltip because otherwise state leaks
      // into other tests.
      element.click();
    });

    it('allows a custom item to be specified for the content of the tooltip', () => {
      const tooltipElement = document.createElement('div');
      manager.add(element, { item: { element: tooltipElement } });
      hover(element, () =>
        expect(tooltipElement.closest('.tooltip')).not.toBeNull()
      );
    });

    it('allows a custom class to be specified for the tooltip', () => {
      manager.add(element, { title: 'Title', class: 'custom-tooltip-class' });
      hover(element, () =>
        expect(
          document.body
            .querySelector('.tooltip')
            .classList.contains('custom-tooltip-class')
        ).toBe(true)
      );
    });

    it('allows jQuery elements to be passed as the target', () => {
      const element2 = document.createElement('div');
      jasmine.attachToDOM(element2);

      const fakeJqueryWrapper = {
        0: element,
        1: element2,
        length: 2,
        jquery: 'any-version'
      };
      const disposable = manager.add(fakeJqueryWrapper, { title: 'Title' });

      hover(element, () =>
        expect(document.body.querySelector('.tooltip')).toHaveText('Title')
      );
      expect(document.body.querySelector('.tooltip')).toBeNull();
      hover(element2, () =>
        expect(document.body.querySelector('.tooltip')).toHaveText('Title')
      );
      expect(document.body.querySelector('.tooltip')).toBeNull();

      disposable.dispose();

      hover(element, () =>
        expect(document.body.querySelector('.tooltip')).toBeNull()
      );
      hover(element2, () =>
        expect(document.body.querySelector('.tooltip')).toBeNull()
      );
    });

    describe('when a keyBindingCommand is specified', () => {
      describe('when a title is specified', () =>
        it('appends the key binding corresponding to the command to the title', () => {
          atom.keymaps.add('test', {
            '.foo': { 'ctrl-x ctrl-y': 'test-command' },
            '.bar': { 'ctrl-x ctrl-z': 'test-command' }
          });

          manager.add(element, {
            title: 'Title',
            keyBindingCommand: 'test-command'
          });

          hover(element, function() {
            const tooltipElement = document.body.querySelector('.tooltip');
            expect(tooltipElement).toHaveText(`Title ${ctrlX} ${ctrlY}`);
          });
        }));

      describe('when no title is specified', () =>
        it('shows the key binding corresponding to the command alone', () => {
          atom.keymaps.add('test', {
            '.foo': { 'ctrl-x ctrl-y': 'test-command' }
          });

          manager.add(element, { keyBindingCommand: 'test-command' });

          hover(element, function() {
            const tooltipElement = document.body.querySelector('.tooltip');
            expect(tooltipElement).toHaveText(`${ctrlX} ${ctrlY}`);
          });
        }));

      describe('when a keyBindingTarget is specified', () => {
        it('looks up the key binding relative to the target', () => {
          atom.keymaps.add('test', {
            '.bar': { 'ctrl-x ctrl-z': 'test-command' },
            '.foo': { 'ctrl-x ctrl-y': 'test-command' }
          });

          manager.add(element, {
            keyBindingCommand: 'test-command',
            keyBindingTarget: element
          });

          hover(element, function() {
            const tooltipElement = document.body.querySelector('.tooltip');
            expect(tooltipElement).toHaveText(`${ctrlX} ${ctrlY}`);
          });
        });

        it('does not display the keybinding if there is nothing mapped to the specified keyBindingCommand', () => {
          manager.add(element, {
            title: 'A Title',
            keyBindingCommand: 'test-command',
            keyBindingTarget: element
          });

          hover(element, function() {
            const tooltipElement = document.body.querySelector('.tooltip');
            expect(tooltipElement.textContent).toBe('A Title');
          });
        });
      });
    });

    describe('when .dispose() is called on the returned disposable', () =>
      it('no longer displays the tooltip on hover', () => {
        const disposable = manager.add(element, { title: 'Title' });

        hover(element, () =>
          expect(document.body.querySelector('.tooltip')).toHaveText('Title')
        );

        disposable.dispose();

        hover(element, () =>
          expect(document.body.querySelector('.tooltip')).toBeNull()
        );
      }));

    describe('when the window is resized', () =>
      it('hides the tooltips', () => {
        const disposable = manager.add(element, { title: 'Title' });
        hover(element, function() {
          expect(document.body.querySelector('.tooltip')).not.toBeNull();
          window.dispatchEvent(new CustomEvent('resize'));
          expect(document.body.querySelector('.tooltip')).toBeNull();
          disposable.dispose();
        });
      }));

    describe('findTooltips', () => {
      it('adds and remove tooltips correctly', () => {
        expect(manager.findTooltips(element).length).toBe(0);
        const disposable1 = manager.add(element, { title: 'elem1' });
        expect(manager.findTooltips(element).length).toBe(1);
        const disposable2 = manager.add(element, { title: 'elem2' });
        expect(manager.findTooltips(element).length).toBe(2);
        disposable1.dispose();
        expect(manager.findTooltips(element).length).toBe(1);
        disposable2.dispose();
        expect(manager.findTooltips(element).length).toBe(0);
      });

      it('lets us hide tooltips programmatically', () => {
        const disposable = manager.add(element, { title: 'Title' });
        hover(element, function() {
          expect(document.body.querySelector('.tooltip')).not.toBeNull();
          manager.findTooltips(element)[0].hide();
          expect(document.body.querySelector('.tooltip')).toBeNull();
          disposable.dispose();
        });
      });
    });
  });
});

function createElement(className) {
  const el = document.createElement('div');
  el.classList.add(className);
  jasmine.attachToDOM(el);
  return el;
}

function mouseEnter(element) {
  element.dispatchEvent(new CustomEvent('mouseenter', { bubbles: false }));
  element.dispatchEvent(new CustomEvent('mouseover', { bubbles: true }));
}

function mouseLeave(element) {
  element.dispatchEvent(new CustomEvent('mouseleave', { bubbles: false }));
  element.dispatchEvent(new CustomEvent('mouseout', { bubbles: true }));
}
