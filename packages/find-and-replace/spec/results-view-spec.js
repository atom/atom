/** @babel */

const _ = require('underscore-plus');
const path = require('path');
const temp = require('temp');
const fs = require('fs');
const etch = require('etch');
const ResultsPaneView = require('../lib/project/results-pane');
const getIconServices = require('../lib/get-icon-services');
const DefaultFileIcons = require('../lib/default-file-icons');
const {Disposable} = require('atom')

global.beforeEach(function() {
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
            range: {start: {row: 0, column: 6}, end: {row: 0, column: 11}},
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
            range: {start: {row: 0, column: 4}, end: {row: 0, column: 8}},
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

    let activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
      mainModule.createViews();
      ({projectFindView} = mainModule);
      const spy = spyOn(projectFindView, 'confirm').andCallFake(() => {
        return searchPromise = spy.originalValue.call(projectFindView)
      });
    });

    atom.commands.dispatch(workspaceElement, 'project-find:show');

    await activationPromise;
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
      console.log("Running bad test");
      debugger
      const {listView} = resultsView.refs;
      expect(listView.element.querySelectorAll('li').length).toBeLessThan(resultsView.model.getPathCount() + resultsView.model.getMatchCount());

      expect(listView.element.querySelectorAll('li').length).toBeGreaterThan(0);
      expect(resultsView.resultRows.length).toBeGreaterThan(0);

      await resultsView.moveToBottom();

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
});

function buildMouseEvent(type, properties) {
  properties = _.extend({bubbles: true, cancelable: true, detail: 1}, properties);
  const event = new MouseEvent(type, properties);
  if (properties.which) {
    Object.defineProperty(event, 'which', {get() { return properties.which; }});
  }
  if (properties.target) {
    Object.defineProperty(event, 'target', {get() { return properties.target; }});
    Object.defineProperty(event, 'srcObject', {get() { return properties.target; }});
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
