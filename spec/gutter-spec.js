const Gutter = require('../src/gutter');

describe('Gutter', () => {
  const fakeGutterContainer = {
    scheduleComponentUpdate() {}
  };
  const name = 'name';

  describe('::hide', () =>
    it('hides the gutter if it is visible.', () => {
      const options = {
        name,
        visible: true
      };
      const gutter = new Gutter(fakeGutterContainer, options);
      const events = [];
      gutter.onDidChangeVisible(gutter => events.push(gutter.isVisible()));

      expect(gutter.isVisible()).toBe(true);
      gutter.hide();
      expect(gutter.isVisible()).toBe(false);
      expect(events).toEqual([false]);
      gutter.hide();
      expect(gutter.isVisible()).toBe(false);
      // An event should only be emitted when the visibility changes.
      expect(events.length).toBe(1);
    }));

  describe('::show', () =>
    it('shows the gutter if it is hidden.', () => {
      const options = {
        name,
        visible: false
      };
      const gutter = new Gutter(fakeGutterContainer, options);
      const events = [];
      gutter.onDidChangeVisible(gutter => events.push(gutter.isVisible()));

      expect(gutter.isVisible()).toBe(false);
      gutter.show();
      expect(gutter.isVisible()).toBe(true);
      expect(events).toEqual([true]);
      gutter.show();
      expect(gutter.isVisible()).toBe(true);
      // An event should only be emitted when the visibility changes.
      expect(events.length).toBe(1);
    }));

  describe('::destroy', () => {
    let mockGutterContainer, mockGutterContainerRemovedGutters;

    beforeEach(() => {
      mockGutterContainerRemovedGutters = [];
      mockGutterContainer = {
        removeGutter(destroyedGutter) {
          mockGutterContainerRemovedGutters.push(destroyedGutter);
        }
      };
    });

    it('removes the gutter from its container.', () => {
      const gutter = new Gutter(mockGutterContainer, { name });
      gutter.destroy();
      expect(mockGutterContainerRemovedGutters).toEqual([gutter]);
    });

    it('calls all callbacks registered on ::onDidDestroy.', () => {
      const gutter = new Gutter(mockGutterContainer, { name });
      let didDestroy = false;
      gutter.onDidDestroy(() => {
        didDestroy = true;
      });
      gutter.destroy();
      expect(didDestroy).toBe(true);
    });

    it('does not allow destroying the line-number gutter', () => {
      const gutter = new Gutter(mockGutterContainer, { name: 'line-number' });
      expect(gutter.destroy).toThrow();
    });
  });
});
