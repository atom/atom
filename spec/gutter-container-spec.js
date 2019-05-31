const Gutter = require('../src/gutter');
const GutterContainer = require('../src/gutter-container');

describe('GutterContainer', () => {
  let gutterContainer = null;
  const fakeTextEditor = {
    scheduleComponentUpdate() {}
  };

  beforeEach(() => {
    gutterContainer = new GutterContainer(fakeTextEditor);
  });

  describe('when initialized', () =>
    it('it has no gutters', () => {
      expect(gutterContainer.getGutters().length).toBe(0);
    }));

  describe('::addGutter', () => {
    it('creates a new gutter', () => {
      const newGutter = gutterContainer.addGutter({
        'test-gutter': 'test-gutter',
        priority: 1
      });
      expect(gutterContainer.getGutters()).toEqual([newGutter]);
      expect(newGutter.priority).toBe(1);
    });

    it('throws an error if the provided gutter name is already in use', () => {
      const name = 'test-gutter';
      gutterContainer.addGutter({ name });
      expect(gutterContainer.addGutter.bind(null, { name })).toThrow();
    });

    it('keeps added gutters sorted by ascending priority', () => {
      const gutter1 = gutterContainer.addGutter({ name: 'first', priority: 1 });
      const gutter3 = gutterContainer.addGutter({ name: 'third', priority: 3 });
      const gutter2 = gutterContainer.addGutter({
        name: 'second',
        priority: 2
      });
      expect(gutterContainer.getGutters()).toEqual([gutter1, gutter2, gutter3]);
    });
  });

  describe('::removeGutter', () => {
    let removedGutters;

    beforeEach(function() {
      gutterContainer = new GutterContainer(fakeTextEditor);
      removedGutters = [];
      gutterContainer.onDidRemoveGutter(gutterName =>
        removedGutters.push(gutterName)
      );
    });

    it('removes the gutter if it is contained by this GutterContainer', () => {
      const gutter = gutterContainer.addGutter({
        'test-gutter': 'test-gutter'
      });
      expect(gutterContainer.getGutters()).toEqual([gutter]);
      gutterContainer.removeGutter(gutter);
      expect(gutterContainer.getGutters().length).toBe(0);
      expect(removedGutters).toEqual([gutter.name]);
    });

    it('throws an error if the gutter is not within this GutterContainer', () => {
      const fakeOtherTextEditor = {};
      const otherGutterContainer = new GutterContainer(fakeOtherTextEditor);
      const gutter = new Gutter('gutter-name', otherGutterContainer);
      expect(gutterContainer.removeGutter.bind(null, gutter)).toThrow();
    });
  });

  describe('::destroy', () =>
    it('clears its array of gutters and destroys custom gutters', () => {
      const newGutter = gutterContainer.addGutter({
        'test-gutter': 'test-gutter',
        priority: 1
      });
      const newGutterSpy = jasmine.createSpy();
      newGutter.onDidDestroy(newGutterSpy);

      gutterContainer.destroy();
      expect(newGutterSpy).toHaveBeenCalled();
      expect(gutterContainer.getGutters()).toEqual([]);
    }));
});
