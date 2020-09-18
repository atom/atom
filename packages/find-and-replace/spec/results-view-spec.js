/** @babel */

const _ = require('underscore-plus');
const path = require('path');
const temp = require('temp');
const fs = require('fs');
const etch = require('etch');
const ResultsPaneView = require('../lib/project/results-pane');
const getIconServices = require('../lib/get-icon-services');
const DefaultFileIcons = require('../lib/default-file-icons');
const { Disposable } = require('atom')

global.beforeEach(function () {
  this.addMatchers({
    toBeWithin(value, delta) {
      this.message = `Expected ${this.actual} to be within ${delta} of ${value}`
      return Math.abs(this.actual - value) < delta;
    }
  });
});

describe('ResultsView', () => {
  let projectFindView, resultsView, searchPromise, workspaceElement;

  function getResultsPane() {
    let pane = atom.workspace.paneForURI(ResultsPaneView.URI);
    if (pane) return pane.itemForURI(ResultsPaneView.URI);
  }

  function getResultsView() {
    return getResultsPane().refs.resultsView;
  }

  function buildResultsView(options = {}) {
    const FindOptions = require("../lib/find-options")
    const ResultsModel = require("../lib/project/results-model")
    const { Result } = ResultsModel
    const ResultsView = require("../lib/project/results-view")
    const model = new ResultsModel(new FindOptions({}), null)
    const resultsView = new ResultsView({ model })

    if (!options.empty) {
      model.addResult("/a/b.txt", Result.create({
        filePath: "/a/b.txt",
        matches: [
          {
            lineText: "hello world",
            matchText: "world",
            range: { start: { row: 0, column: 6 }, end: { row: 0, column: 11 } },
            leadingContextLines: [],
            trailingContextLines: []
          }
        ]
      }))
      model.addResult("/c/d.txt", Result.create({
        filePath: "/c/d.txt",
        matches: [
          {
            lineText: "goodnight moon",
            matchText: "night",
            range: { start: { row: 0, column: 4 }, end: { row: 0, column: 8 } },
            leadingContextLines: [],
            trailingContextLines: []
          }
        ]
      }))
    }

    return resultsView
  }

  beforeEach(async () => {
    workspaceElement = atom.views.getView(atom.workspace);
    workspaceElement.style.height = '1000px';
    jasmine.attachToDOM(workspaceElement);

    atom.config.set('core.excludeVcsIgnoredPaths', false);
    atom.project.setPaths([path.join(__dirname, 'fixtures/project')]);

    let activationPromise = atom.packages.activatePackage("find-and-replace").then(function ({ mainModule }) {
      mainModule.createViews();
      ({ projectFindView } = mainModule);
      const spy = spyOn(projectFindView, 'confirm').andCallFake(() => {
        return searchPromise = spy.originalValue.call(projectFindView)
      });
    });

    atom.commands.dispatch(workspaceElement, 'project-find:show');

    await activationPromise;
  });

  describe("when the result is for a long line", () => {
    it("renders the context around the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.refs.listView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.refs.listView.element.querySelector('.preview').textContent).toBe('test test test test test test test test test test test a b c d e f g h i j k l abcdefghijklmnopqrstuvwxyz');
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
    })
  });

  describe("when there are multiple project paths", () => {
    beforeEach(() => {
      atom.project.addPath(temp.mkdirSync("another-project-path"))
    });

    it("includes the basename of the project path that contains the match", async () => {
      projectFindView.findEditor.setText('ghijkl');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe(path.join("project", "one-long-line.coffee"));
    });
  });

  describe("rendering replacement text", () => {
    let modifiedDelay = null;

    beforeEach(() => {
      projectFindView.findEditor.setText('ghijkl');
      modifiedDelay = projectFindView.replaceEditor.getBuffer().stoppedChangingDelay;
    });

    it("renders the replacement when doing a search and there is a replacement pattern", async () => {
      projectFindView.replaceEditor.setText('cats');
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.path-name').textContent).toBe("one-long-line.coffee");
      expect(resultsView.refs.listView.element.querySelectorAll('.preview').length).toBe(1);
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('cats');
    });

    it("renders the replacement when changing the text in the replacement field", async () => {
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeHidden();

      projectFindView.replaceEditor.setText('cats');
      advanceClock(modifiedDelay);
      await etch.update(resultsView);

      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-error');
      expect(resultsView.refs.listView.element.querySelector('.replacement').textContent).toBe('cats');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeVisible();

      projectFindView.replaceEditor.setText('');
      advanceClock(modifiedDelay);
      await etch.update(resultsView);

      expect(resultsView.refs.listView.element.querySelector('.match').textContent).toBe('ghijkl');
      expect(resultsView.refs.listView.element.querySelector('.match')).toHaveClass('highlight-info');
      expect(resultsView.refs.listView.element.querySelector('.replacement')).toBeHidden();
    });

    it('renders the captured text when the replace pattern uses captures', async () => {
      projectFindView.refs.regexOptionButton.click();
      projectFindView.findEditor.setText('function ?(\\([^)]*\\))');
      projectFindView.replaceEditor.setText('$1 =>')
      atom.commands.dispatch(projectFindView.element, 'core:confirm');
      await searchPromise;

      resultsView = getResultsView();
      const listElement = resultsView.refs.listView.element;
      expect(listElement.querySelectorAll('.match')[0].textContent).toBe('function ()');
      expect(listElement.querySelectorAll('.replacement')[0].textContent).toBe('() =>');
      expect(listElement.querySelectorAll('.match')[1].textContent).toBe('function(items)');
      expect(listElement.querySelectorAll('.replacement')[1].textContent).toBe('(items) =>');
    })
  });

  describe("core:page-up and core:page-down", () => {
    beforeEach(async () => {
      workspaceElement.style.height = '300px';
      workspaceElement.style.width = '1024px';
      projectFindView.findEditor.setText(' ');
      projectFindView.confirm();

      await searchPromise;

      resultsView = getResultsView();
      const { listView } = resultsView.refs;
      expect(listView.element.scrollTop).toBe(0);
      expect(listView.element.scrollHeight).toBeGreaterThan(listView.element.offsetHeight);
    });

    function getSelectedItem() {
      return resultsView.refs.listView.element.querySelector('.selected');
    }

    function getRecursivePosition(element, substract_scroll) {
      let x = 0;
      let y = 0;
      while (element && !isNaN(element.offsetLeft) && !isNaN(element.offsetTop)) {
        x += element.offsetLeft;
        y += element.offsetTop;
        if (substract_scroll) {
          x -= element.scrollLeft;
          y -= element.scrollTop;
        }
        element = element.offsetParent;
      }
      return { top: y, left: x };
    }

    function getSelectedOffset() {
      return getRecursivePosition(getSelectedItem(), true).top;
    }

    function getSelectedPosition() {
      return getRecursivePosition(getSelectedItem(), false).top;
    }

    it("selects the first result on the next page when core:page-down is triggered", async () => {
      const { listView } = resultsView.refs;
      expect(listView.element.querySelectorAll('.path-row').length).not.toBeGreaterThan(resultsView.model.getPathCount());
      expect(listView.element.querySelectorAll('.match-row').length).not.toBeGreaterThan(resultsView.model.getMatchCount());
      expect(listView.element.querySelector('.path-row').parentElement).toHaveClass('selected');

      let initiallySelectedItem = getSelectedItem();
      let initiallySelectedOffset = getSelectedOffset();
      let initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageDown();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      initiallySelectedItem = getSelectedItem();
      initiallySelectedOffset = getSelectedOffset();
      initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageDown();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);

      initiallySelectedPosition = getSelectedPosition();

      for (let i = 0; i < 100; i++) resultsView.pageDown();
      await resultsView.pageDown();
      expect(_.last(resultsView.element.querySelectorAll('.match-row'))).toHaveClass('selected');
      expect(getSelectedPosition()).toBeGreaterThan(initiallySelectedPosition);
    });

    it("selects the first result on the previous page when core:page-up is triggered", async () => {
      await resultsView.moveToBottom();
      expect(_.last(resultsView.element.querySelectorAll('.match-row'))).toHaveClass('selected');

      const { listView } = resultsView.refs;

      let initiallySelectedItem = getSelectedItem();
      let initiallySelectedOffset = getSelectedOffset();
      let initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageUp();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);

      initiallySelectedItem = getSelectedItem();
      initiallySelectedOffset = getSelectedOffset();
      initiallySelectedPosition = getSelectedPosition();

      await resultsView.pageUp();

      expect(getSelectedItem()).not.toBe(initiallySelectedItem);
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);

      initiallySelectedPosition = getSelectedPosition();

      for (let i = 0; i < 100; i++) resultsView.pageUp();
      await resultsView.pageUp();
      expect(listView.element.querySelector('.path-row').parentElement).toHaveClass('selected');
      expect(getSelectedPosition()).toBeLessThan(initiallySelectedPosition);
    });
  });

  describe("core:move-to-top and core:move-to-bottom", () => {
    beforeEach(async () => {
      workspaceElement.style.height = '300px';
      projectFindView.findEditor.setText('so');
      projectFindView.confirm();
      await searchPromise;
      resultsView = getResultsView();
    });

    it("selects the first/last item when core:move-to-top/move-to-bottom is triggered", async () => {
      // console.log("Running bad test");
      const { listView } = resultsView.refs;

      expect(listView.element.querySelectorAll('.match-row').length).toBeGreaterThan(0);

      expect(listView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

      expect(listView.element.querySelectorAll('li').length).toBeGreaterThan(0);
      expect(resultsView.resultRows.length).toBeGreaterThan(0);

      await resultsView.moveToBottom();

      expect(listView.element.querySelectorAll('li').length).toBeGreaterThan(0);
      expect(listView.element.querySelectorAll('.match-row').length).toBeGreaterThan(0);

      expect(_.last(listView.element.querySelectorAll('.match-row'))).toHaveClass('selected');
      expect(listView.element.scrollTop).not.toBe(0);

      await resultsView.moveToTop();
      expect(listView.element.querySelector('.path-row').parentElement).toHaveClass('selected');
      expect(listView.element.scrollTop).toBe(0);
    });

    it("selects the path when when core:move-to-bottom is triggered and last item is collapsed", async () => {
      await resultsView.moveToBottom();
      await resultsView.collapseResult();
      await resultsView.moveToBottom();

      expect(_.last(resultsView.refs.listView.element.querySelectorAll('.path-row')).parentElement).toHaveClass('selected');
    });

    it("selects the path when when core:move-to-top is triggered and first item is collapsed", async () => {
      await resultsView.moveToTop();
      atom.commands.dispatch(resultsView.element, 'core:move-left');
      await resultsView.moveToTop();

      expect(resultsView.refs.listView.element.querySelector('.path-row').parentElement).toHaveClass('selected');
    });
  });

  // describe("expanding and collapsing results", () => {
  //   it('preserves the selected file when collapsing all results', async () => {
  //     projectFindView.findEditor.setText('items');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();

  //     resultsView.moveDown();
  //     resultsView.moveDown();
  //     await resultsView.moveDown();
  //     const selectedMatch = resultsView.element.querySelector('.selected');
  //     expect(selectedMatch).toHaveClass('match-row');

  //     await resultsView.collapseAllResults();
  //     const selectedPath = resultsView.element.querySelector('.selected');
  //     expect(selectedPath.firstChild).toHaveClass('path-row');
  //     expect(selectedPath.firstChild.dataset.filePath).toContain('sample.coffee');

  //     // Moving down while the path is collapsed moves to the next path,
  //     // as opposed to selecting the next match within the collapsed path.
  //     resultsView.moveDown();
  //     await resultsView.expandAllResults();
  //     const newSelectedPath = resultsView.element.querySelector('.selected');
  //     expect(newSelectedPath.firstChild.dataset.filePath).toContain('sample.js');

  //     resultsView.moveDown();
  //     resultsView.moveDown();
  //     await resultsView.moveDown();
  //     expect(resultsView.element.querySelector('.selected')).toHaveClass('match-row');

  //     // Moving up while the path is collapsed moves to the previous path,
  //     // as opposed to moving up to the next match within the collapsed path.
  //     resultsView.collapseAllResults();
  //     resultsView.moveUp();
  //     await resultsView.expandAllResults();
  //     expect(resultsView.element.querySelector('.selected')).toBe(selectedPath);
  //   });

  //   it('re-expands all results when running a new search', async () => {
  //     projectFindView.findEditor.setText('items');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();

  //     await resultsView.collapseResult();
  //     expect(resultsView.element.querySelector('.collapsed')).not.toBe(null);

  //     projectFindView.findEditor.setText('sort');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     expect(resultsView.element.querySelector('.collapsed')).toBe(null);
  //   })

  //   it('preserves the collapsed state of the right files when results are removed', async () => {
  //     projectFindView.findEditor.setText('push');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;
  //     resultsView = getResultsView();

  //     // collapse the first result
  //     resultsView.selectFirstResult();
  //     resultsView.collapseResult();

  //     // remove the first result
  //     const firstPath = resultsView.model.getPaths()[0];
  //     const firstResult = resultsView.model.getResult(firstPath);
  //     resultsView.model.removeResult(firstPath);

  //     // Check that the first result is not collapsed
  //     const matchedPaths = resultsView.refs.listView.element.querySelectorAll('.path.list-nested-item');
  //     expect(matchedPaths[0]).not.toHaveClass('collapsed')
  //   });

  //   it('preserves the collapsed state of the right files when results are added', async () => {
  //     projectFindView.findEditor.setText('push');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;
  //     resultsView = getResultsView();

  //     // remove the first result
  //     const firstPath = resultsView.model.getPaths()[0];
  //     const firstResult = resultsView.model.getResult(firstPath);
  //     resultsView.model.removeResult(firstPath);

  //     // collapse the new first result
  //     resultsView.selectFirstResult();
  //     resultsView.collapseResult();

  //     // re-add the old first result
  //     resultsView.model.addResult(firstPath, firstResult);

  //     await etch.update(resultsView);

  //     // Check that the first result is not collapsed while the second one still is
  //     const matchedPaths = resultsView.refs.listView.element.querySelectorAll('.path-row');
  //     expect(matchedPaths[0].parentElement).not.toHaveClass('collapsed')
  //     expect(matchedPaths[1].parentElement).toHaveClass('collapsed')
  //   });
  // });

  // describe("opening results", () => {
  //   beforeEach(async () => {
  //     await atom.workspace.open('sample.js');

  //     projectFindView.findEditor.setText('items');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();
  //     resultsView.selectFirstResult();
  //   });

  //   function paneItemOpening(pending = null) {
  //     return new Promise(resolve => {
  //       const subscription = atom.workspace.onDidOpen(({pane, item}) => {
  //         if (pending === null || (pane.getPendingItem() === item) === pending) {
  //           resolve()
  //           subscription.dispose()
  //         }
  //       })
  //     })
  //   }

  //   it("opens the file containing the result when 'core:confirm' is called", async () => {
  //     // open something in sample.coffee
  //     resultsView.element.focus();
  //     _.times(3, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
  //     atom.commands.dispatch(resultsView.element, 'core:confirm');
  //     await paneItemOpening()
  //     expect(atom.workspace.getCenter().getActivePaneItem().getPath()).toContain('sample.');

  //     // open something in sample.js
  //     resultsView.element.focus();
  //     _.times(6, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
  //     atom.commands.dispatch(resultsView.element, 'core:confirm');
  //     await paneItemOpening()
  //     expect(atom.workspace.getCenter().getActivePaneItem().getPath()).toContain('sample.');
  //   });

  //   it("opens the file containing the result in a non-pending state when the search result is double-clicked", async () => {
  //     const pathNode = resultsView.refs.listView.element.querySelectorAll(".match-row")[0];
  //     const click1 = buildMouseEvent('mousedown', {target: pathNode, detail: 1});
  //     const click2 = buildMouseEvent('mousedown', {target: pathNode, detail: 2});
  //     pathNode.dispatchEvent(click1);
  //     pathNode.dispatchEvent(click2);

  //     // Otherwise, the double click will transfer focus back to the results view
  //     expect(click2.defaultPrevented).toBe(true);

  //     await paneItemOpening(false)
  //     const editor = atom.workspace.getCenter().getActiveTextEditor();
  //     expect(atom.workspace.getCenter().getActivePane().getPendingItem()).toBe(null);
  //     expect(atom.views.getView(editor)).toHaveFocus();
  //   });

  //   it("opens the file containing the result in a pending state when the search result is single-clicked", async () => {
  //     const pathNode = resultsView.refs.listView.element.querySelectorAll(".match-row")[0];
  //     pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
  //     await paneItemOpening()
  //     const editor = atom.workspace.getCenter().getActiveTextEditor();
  //     expect(atom.workspace.getCenter().getActivePane().getPendingItem()).toBe(editor);
  //     expect(atom.views.getView(editor)).toHaveFocus();
  //   })

  //   it("Result view should maintain scroll position", async () => {
  //     spyOn(resultsView,'setScrollTop').andCallThrough();

  //     projectFindView.findEditor.setText('1');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView.moveToBottom();

  //     const pathNode = resultsView.element.querySelector('.selected');
  //     pathNode.dispatchEvent(buildMouseEvent('mousedown', {target: pathNode, which: 1}));
  //     await paneItemOpening();

  //     expect(resultsView.setScrollTop).toHaveBeenCalledWith(resultsView.currentScrollTop);
  //   });

  //   describe("the `projectSearchResultsPaneSplitDirection` option", () => {
  //     beforeEach(() => {
  //       spyOn(atom.workspace, 'open').andCallThrough()
  //     });

  //     it("does not create a split when the option is 'none'", async () => {
  //       atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'none');
  //       atom.commands.dispatch(resultsView.element, 'core:move-down');
  //       atom.commands.dispatch(resultsView.element, 'core:confirm');
  //       await paneItemOpening()
  //       expect(atom.workspace.open.mostRecentCall.args[1].split).toBeUndefined();
  //     });

  //     it("always opens the file in the left pane when the option is 'right'", async () => {
  //       atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right');
  //       atom.commands.dispatch(resultsView.element, 'core:move-down');
  //       atom.commands.dispatch(resultsView.element, 'core:confirm');
  //       await paneItemOpening()
  //       expect(atom.workspace.open.mostRecentCall.args[1].split).toBe('left');
  //     });

  //     it("always opens the file in the pane above when the options is 'down'", async () => {
  //       atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'down')
  //       atom.commands.dispatch(resultsView.element, 'core:move-down');
  //       atom.commands.dispatch(resultsView.element, 'core:confirm');
  //       await paneItemOpening()
  //       expect(atom.workspace.open.mostRecentCall.args[1].split).toBe('up');
  //     });
  //   });
  // });

  // describe("arrowing through the list", () => {
  //   it("arrows through the entire list without selecting paths and overshooting the boundaries", async () => {
  //     await atom.workspace.open('sample.js');

  //     projectFindView.findEditor.setText('items');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();

  //     let {length: resultCount} = resultsView.refs.listView.element.querySelectorAll(".match-row");
  //     expect(resultCount).toBe(11);

  //     resultsView.selectFirstResult();

  //     // moves down for 11 results + 2 files
  //     for (let i = 0; i < resultCount; ++i) {
  //       resultsView.moveDown();
  //     }
  //     await resultsView.moveDown();
  //     await resultsView.moveDown();
  //     let selectedItem = resultsView.element.querySelector('.selected');
  //     expect(selectedItem).toHaveClass('match-row');

  //     // stays at the bottom
  //     let lastSelectedItem = selectedItem;
  //     await resultsView.moveDown();
  //     await resultsView.moveDown();
  //     selectedItem = resultsView.element.querySelector('.selected');
  //     expect(selectedItem).toBe(lastSelectedItem);

  //     // moves up to the top
  //     lastSelectedItem = selectedItem;
  //     for (let i = 0; i < resultCount; ++i) {
  //       resultsView.moveUp();
  //     }
  //     await resultsView.moveUp();
  //     await resultsView.moveUp();
  //     selectedItem = resultsView.element.querySelector('.selected');
  //     expect(selectedItem.firstChild).toHaveClass('path-row');
  //     expect(selectedItem).not.toBe(lastSelectedItem);

  //     // stays at the top
  //     lastSelectedItem = selectedItem;
  //     await resultsView.moveUp();
  //     await resultsView.moveUp();
  //     selectedItem = resultsView.element.querySelector('.selected');
  //     expect(selectedItem).toBe(lastSelectedItem);
  //   });

  //   describe("when there are a list of items", () => {
  //     beforeEach(async () => {
  //       projectFindView.findEditor.setText('items');
  //       atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //       await searchPromise;
  //       resultsView = getResultsView();
  //     });

  //     it("shows the preview-controls", () => {
  //       expect(getResultsPane().refs.previewControls).toBeVisible();
  //       expect(getResultsPane().refs.previewControls.style).not.toBe('hidden');
  //     });

  //     it("collapses the selected results view", async () => {
  //       clickOn(resultsView.refs.listView.element.querySelector('.match-row'));

  //       await resultsView.collapseResult();

  //       let selectedItem = resultsView.element.querySelector('.selected');
  //       expect(selectedItem).toHaveClass('collapsed');
  //       expect(selectedItem).toBe(resultsView.refs.listView.element.querySelector('.path-row').parentElement);
  //     });

  //     it("collapses all results if collapse All button is pressed", async () => {
  //       await resultsView.collapseAllResults();
  //       for (let item of Array.from(resultsView.refs.listView.element.querySelectorAll('.path-row'))) {
  //         expect(item.parentElement).toHaveClass('collapsed');
  //       }
  //     });

  //     it("expands the selected results view", async () => {
  //       clickOn(resultsView.refs.listView.element.querySelector('.path-row').parentElement);

  //       await resultsView.expandResult();

  //       let selectedItem = resultsView.element.querySelector('.selected');
  //       expect(selectedItem).toHaveClass('match-row');
  //       expect(selectedItem).toBe(resultsView.refs.listView.element.querySelector('.match-row'));
  //     });

  //     it("expands all results if 'Expand All' button is pressed", async () => {
  //       await resultsView.expandAllResults();
  //       await etch.update(resultsView.refs.listView);
  //       for (let item of Array.from(resultsView.refs.listView.element.querySelectorAll('.path-row'))) {
  //         expect(item.parentElement).not.toHaveClass('collapsed');
  //       }
  //     });

  //     describe("when there are collapsed results", () => {
  //       it("moves to the correct prev/next result when a path is selected", async () => {
  //         resultsView.selectRow(0);
  //         resultsView.collapseResult();
  //         await resultsView.selectRow(2);

  //         expect(resultsView.refs.listView.element.querySelectorAll('.match-row')[0]).toHaveClass('selected');

  //         await resultsView.moveUp();
  //         expect(resultsView.refs.listView.element.querySelectorAll('.path-row')[1].parentElement).toHaveClass('selected');

  //         await resultsView.moveUp();
  //         expect(resultsView.refs.listView.element.querySelectorAll('.path-row')[0].parentElement).toHaveClass('selected');

  //         await resultsView.moveDown();
  //         expect(resultsView.refs.listView.element.querySelectorAll('.path-row')[1].parentElement).toHaveClass('selected');
  //       });
  //     });
  //   });
  // });

  // describe("when the results view is empty", () => {
  //   it("ignores core:confirm and other commands for selecting results", async () => {
  //     const resultsView = buildResultsView({ empty: true });
  //     atom.commands.dispatch(resultsView.element, 'core:confirm');
  //     atom.commands.dispatch(resultsView.element, 'core:move-down');
  //     atom.commands.dispatch(resultsView.element, 'core:move-up');
  //     atom.commands.dispatch(resultsView.element, 'core:move-to-top');
  //     atom.commands.dispatch(resultsView.element, 'core:move-to-bottom');
  //     atom.commands.dispatch(resultsView.element, 'core:page-down');
  //     atom.commands.dispatch(resultsView.element, 'core:page-up');
  //   });

  //   it("won't show the preview-controls", async () => {
  //     const resultsPane = new ResultsPaneView();
  //     expect(resultsPane.refs.previewControls.style.display).toBe('none');
  //   });
  // });

  // describe("copying items with core:copy", () => {
  //   it("copies the selected line onto the clipboard", () => {
  //     const resultsView = buildResultsView();

  //     resultsView.selectFirstResult();
  //     _.times(3, () => atom.commands.dispatch(resultsView.element, 'core:move-down'));
  //     atom.commands.dispatch(resultsView.element, 'core:copy');
  //     expect(atom.clipboard.read()).toBe('goodnight moon');
  //   });
  // });

  // describe("copying path with find-and-replace:copy-path", () => {
  //   it("copies the selected file path to clipboard", () => {
  //     const resultsView = buildResultsView();

  //     resultsView.selectFirstResult();
  //     // await resultsView.collapseResult();
  //     atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
  //     expect(atom.clipboard.read()).toBe('/a/b.txt');

  //     atom.commands.dispatch(resultsView.element, 'core:move-down');
  //     atom.commands.dispatch(resultsView.element, 'core:move-down');
  //     atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
  //     expect(atom.clipboard.read()).toBe('/c/d.txt');

  //     atom.commands.dispatch(resultsView.element, 'core:move-up');
  //     atom.commands.dispatch(resultsView.element, 'find-and-replace:copy-path');
  //     expect(atom.clipboard.read()).toBe('/a/b.txt');
  //   });
  // });

  // describe("fonts", () => {
  //   it('respect the editor.fontFamily setting', async () => {
  //     atom.config.set('editor.fontFamily', 'Courier');
  //     const resultsView = buildResultsView();

  //     await etch.update(resultsView);
  //     expect(resultsView.element.style.fontFamily).toBe('Courier');

  //     atom.config.set('editor.fontFamily', 'Helvetica');
  //     await etch.update(resultsView);
  //     expect(resultsView.element.style.fontFamily).toBe('Helvetica');
  //   })
  // });

  // describe('icon services', () => {
  //   describe('atom.file-icons', () => {
  //     it('has a default handler', () => {
  //       expect(getIconServices().fileIcons).toBe(DefaultFileIcons)
  //     })

  //     it('displays icons for common filetypes', () => {
  //       expect(DefaultFileIcons.iconClassForPath('README.md')).toBe('icon-book')
  //       expect(DefaultFileIcons.iconClassForPath('zip.zip')).toBe('icon-file-zip')
  //       expect(DefaultFileIcons.iconClassForPath('a.gif')).toBe('icon-file-media')
  //       expect(DefaultFileIcons.iconClassForPath('a.pdf')).toBe('icon-file-pdf')
  //       expect(DefaultFileIcons.iconClassForPath('an.exe')).toBe('icon-file-binary')
  //       expect(DefaultFileIcons.iconClassForPath('jg.js')).toBe('icon-file-text')
  //     })

  //     it('allows a service provider to change the handler', async () => {
  //       const provider = {
  //         iconClassForPath(path, context) {
  //           expect(context).toBe('find-and-replace')
  //           return (path.endsWith('one-long-line.coffee'))
  //             ? 'first-icon-class second-icon-class'
  //             : ['third-icon-class', 'fourth-icon-class']
  //         }
  //       }
  //       const disposable = atom.packages.serviceHub.provide('atom.file-icons', '1.0.0', provider);
  //       expect(getIconServices().fileIcons).toBe(provider)

  //       projectFindView.findEditor.setText('i');
  //       atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //       await searchPromise;

  //       resultsView = getResultsView();
  //       let fileIconClasses = Array.from(resultsView.refs.listView.element.querySelectorAll('.path-row .icon')).map(el => el.className);
  //       expect(fileIconClasses).toContain('first-icon-class second-icon-class icon');
  //       expect(fileIconClasses).toContain('third-icon-class fourth-icon-class icon');
  //       expect(fileIconClasses).not.toContain('icon-file-text icon');

  //       disposable.dispose();
  //       projectFindView.findEditor.setText('e');
  //       atom.commands.dispatch(projectFindView.element, 'core:confirm');

  //       await searchPromise;
  //       resultsView = getResultsView();
  //       fileIconClasses = Array.from(resultsView.refs.listView.element.querySelectorAll('.path-row .icon')).map(el => el.className);
  //       expect(fileIconClasses).not.toContain('first-icon-class second-icon-class icon');
  //       expect(fileIconClasses).not.toContain('third-icon-class fourth-icon-class icon');
  //       expect(fileIconClasses).toContain('icon-file-text icon');
  //     })
  //   })

  //   describe('file-icons.element-icons', () => {
  //     beforeEach(() => jasmine.useRealClock())

  //     it('has no default handler', () => {
  //       expect(getIconServices().elementIcons).toBe(null)
  //     })

  //     it('uses the element-icon service if available', () => {
  //       const iconSelector = '.path-row .icon:not([data-name="fake-file-path"])'
  //       const provider = (element, path) => {
  //         expect(element).toBeInstanceOf(HTMLElement)
  //         expect(typeof path === "string").toBe(true)
  //         expect(path.length).toBeGreaterThan(0)
  //         const classes = path.endsWith('one-long-line.coffee')
  //           ? ['foo', 'bar']
  //           : ['baz', 'qlux']
  //         element.classList.add(...classes)
  //         return new Disposable(() => {
  //           element.classList.remove(...classes)
  //         })
  //       }
  //       let disposable

  //       waitsForPromise(() => {
  //         disposable = atom.packages.serviceHub.provide('file-icons.element-icons', '1.0.0', provider)
  //         expect(getIconServices().elementIcons).toBe(provider)
  //         projectFindView.findEditor.setText('i');
  //         atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //         return searchPromise
  //       })

  //       waitsForPromise(() => delayFor(35))

  //       runs(() => {
  //         resultsView = getResultsView()
  //         const iconElements = resultsView.element.querySelectorAll(iconSelector)
  //         expect(iconElements[0].className.trim()).toBe('icon foo bar')
  //         expect(iconElements[1].className.trim()).toBe('icon baz qlux')
  //         expect(resultsView.element.querySelector('.icon-file-text')).toBe(null)

  //         disposable.dispose()
  //         projectFindView.findEditor.setText('e')
  //         atom.commands.dispatch(projectFindView.element, 'core:confirm')
  //       })

  //       waitsForPromise(() => searchPromise)

  //       waitsForPromise(() => delayFor(35))

  //       runs(() => {
  //         resultsView = getResultsView()
  //         const iconElements = resultsView.element.querySelectorAll(iconSelector)
  //         expect(iconElements[0].className.trim()).toBe('icon-file-text icon')
  //         expect(iconElements[1].className.trim()).toBe('icon-file-text icon')
  //         expect(resultsView.element.querySelector('.foo, .bar, .baz, .qlux')).toBe(null)
  //       })
  //     })
  //   })
  // })

  // describe('updating the search while viewing results', () => {
  //   it('resets the results message', async () => {
  //     projectFindView.findEditor.setText('a');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsPane = getResultsPane();
  //     await etch.update(resultsPane);
  //     expect(resultsPane.refs.previewCount.textContent).toContain('3 files');

  //     projectFindView.findEditor.setText('');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await etch.update(resultsPane);
  //     expect(resultsPane.refs.previewCount.textContent).toContain('Project search results');
  //   })
  // });

  // describe('search result context lines', () => {
  //   beforeEach(async () => {
  //     atom.config.set('find-and-replace.searchContextLineCountBefore', 4);
  //     atom.config.set('find-and-replace.searchContextLineCountAfter', 3);
  //     atom.config.set('find-and-replace.leadingContextLineCount', 0);
  //     atom.config.set('find-and-replace.trailingContextLineCount', 0);

  //     projectFindView.findEditor.setText('items.');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();
  //   });

  //   function getFirstMatchRows(resultsView) {
  //     const {element} = resultsView.refs.listView
  //     const rowNodes = Array.from(element.querySelectorAll('.list-item'));
  //     const rowCount = resultsView.resultRowGroups[0].rows.filter(row =>
  //       row.data.matchLineNumber === resultsView.resultRows[1].data.matchLineNumber
  //     ).length
  //     return rowNodes.slice(1, 1 + rowCount);
  //   }

  //   it('shows no context lines', async () => {
  //     expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(0);
  //     expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(0);

  //     const lineNodes = getFirstMatchRows(resultsView);
  //     expect(lineNodes.length).toBe(1);
  //     expect(lineNodes[0]).toHaveClass('match-row');
  //     expect(lineNodes[0].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
  //   });

  //   it('shows 1 leading context line, 1 trailing context line', async () => {
  //     resultsView.incrementLeadingContextLines();
  //     await resultsView.incrementTrailingContextLines();
  //     expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(1);
  //     expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(1);

  //     const lineNodes = getFirstMatchRows(resultsView);
  //     expect(lineNodes.length).toBe(3);
  //     expect(lineNodes[0]).toHaveClass('context-row');
  //     /*
  //     FIXME: I suspect this test fails because of a bug in atom's scan
  //     See issue #16948
  //     expect(lineNodes[0].querySelector('.preview').textContent).toBe('  sort: (items) ->');
  //     */
  //     expect(lineNodes[1]).toHaveClass('match-row');
  //     expect(lineNodes[1].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
  //     expect(lineNodes[2]).toHaveClass('context-row');
  //     expect(lineNodes[2].querySelector('.preview').textContent).toBe('');
  //   });

  //   it('shows all leading context lines, 2 trailing context lines', async () => {
  //     resultsView.toggleLeadingContextLines();
  //     resultsView.incrementTrailingContextLines();
  //     await resultsView.incrementTrailingContextLines();
  //     expect(resultsView.model.getFindOptions().leadingContextLineCount).toBe(4);
  //     expect(resultsView.model.getFindOptions().trailingContextLineCount).toBe(2);

  //     const lineNodes = getFirstMatchRows(resultsView);

  //     // There are two leading context lines after the start of the document
  //     // There are two trailing context lines before the next match
  //     expect(lineNodes.length).toBe(4);

  //     expect(lineNodes[0]).toHaveClass('context-row');
  //     expect(lineNodes[0].querySelector('.preview').textContent).toBe('class quicksort');
  //     expect(lineNodes[1]).toHaveClass('context-row');
  //     expect(lineNodes[1].querySelector('.preview').textContent).toBe('  sort: (items) ->');
  //     expect(lineNodes[2]).toHaveClass('match-row');
  //     expect(lineNodes[2].querySelector('.preview').textContent).toBe('    return items if items.length <= 1');
  //     expect(lineNodes[3]).toHaveClass('context-row');
  //     expect(lineNodes[3].querySelector('.preview').textContent).toBe('');
  //   });
  // });

  // describe('selected result and match index', () => {
  //   beforeEach(async () => {
  //     projectFindView.findEditor.setText('push');
  //     atom.commands.dispatch(projectFindView.element, 'core:confirm');
  //     await searchPromise;

  //     resultsView = getResultsView();
  //   });

  //   it('maintains selected result when adding and removing results', async () => {
  //     {
  //       const matchRows = resultsView.refs.listView.element.querySelectorAll('.match-row');
  //       expect(matchRows.length).toBe(3);

  //       resultsView.moveDown();
  //       resultsView.moveDown();
  //       resultsView.moveDown();
  //       await resultsView.moveDown();
  //       expect(matchRows[2]).toHaveClass('selected');
  //       expect(matchRows[2].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
  //       expect(resultsView.selectedRowIndex).toBe(4);
  //     }

  //     // remove the first result
  //     const firstPath = resultsView.model.getPaths()[0];
  //     const firstResult = resultsView.model.getResult(firstPath);
  //     resultsView.model.removeResult(firstPath);
  //     await etch.update(resultsView);

  //     // check that the same match is still selected
  //     {
  //       const matchRows = resultsView.refs.listView.element.querySelectorAll('.match-row');
  //       expect(matchRows.length).toBe(1);
  //       expect(matchRows[0]).toHaveClass('selected');
  //       expect(matchRows[0].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
  //       expect(resultsView.selectedRowIndex).toBe(1);
  //     }

  //     // re-add the first result
  //     resultsView.model.addResult(firstPath, firstResult);
  //     await etch.update(resultsView);

  //     // check that the same match is still selected
  //     {
  //       const matchRows = resultsView.refs.listView.element.querySelectorAll('.match-row');
  //       expect(matchRows.length).toBe(3);
  //       expect(matchRows[2]).toHaveClass('selected');
  //       expect(matchRows[2].querySelector('.preview').textContent).toBe('      current < pivot ? left.push(current) : right.push(current);');
  //       expect(resultsView.selectedRowIndex).toBe(4);
  //     }
  //   });
  // })
});

function buildMouseEvent(type, properties) {
  properties = _.extend({ bubbles: true, cancelable: true, detail: 1 }, properties);
  const event = new MouseEvent(type, properties);
  if (properties.which) {
    Object.defineProperty(event, 'which', { get() { return properties.which; } });
  }
  if (properties.target) {
    Object.defineProperty(event, 'target', { get() { return properties.target; } });
    Object.defineProperty(event, 'srcObject', { get() { return properties.target; } });
  }
  return event;
}

function clickOn(element) {
  element.dispatchEvent(buildMouseEvent('mousedown', { detail: 1 }));
}

function delayFor(ms) {
  return new Promise(done => {
    setTimeout(() => done(), ms)
  })
}
