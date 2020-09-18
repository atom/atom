/** @babel */

const path = require("path");
const ResultsModel = require("../lib/project/results-model");
const FindOptions = require("../lib/find-options");

describe("ResultsModel", () => {
  let editor, resultsModel, reporterSpy;

  beforeEach(async () => {
    atom.config.set("core.excludeVcsIgnoredPaths", false);
    atom.config.set("find-and-replace.searchContextLineCountBefore", 2);
    atom.config.set("find-and-replace.searchContextLineCountAfter", 3);
    atom.project.setPaths([path.join(__dirname, "fixtures/project")]);

    editor = await atom.workspace.open("sample.js");
    reporterSpy = {
      sendSearchEvent: jasmine.createSpy()
    }
    resultsModel = new ResultsModel(new FindOptions(), reporterSpy);
  });

  describe("searching for a pattern", () => {
    it("populates the model with all the results, and updates in response to changes in the buffer", async () => {
      const resultAddedSpy = jasmine.createSpy();
      const resultSetSpy = jasmine.createSpy();
      const resultRemovedSpy = jasmine.createSpy();

      resultsModel.onDidAddResult(resultAddedSpy);
      resultsModel.onDidSetResult(resultSetSpy);
      resultsModel.onDidRemoveResult(resultRemovedSpy);
      await resultsModel.search("items", "*.js", "");

      expect(resultAddedSpy).toHaveBeenCalled();
      expect(resultAddedSpy.callCount).toBe(1);

      let result = resultsModel.getResult(editor.getPath());
      expect(result.matches.length).toBe(6);
      expect(resultsModel.getPathCount()).toBe(1);
      expect(resultsModel.getMatchCount()).toBe(6);
      expect(resultsModel.getPaths()).toEqual([editor.getPath()]);
      expect(result.matches[0].leadingContextLines.length).toBe(1);
      expect(result.matches[0].leadingContextLines[0]).toBe("var quicksort = function () {");
      expect(result.matches[0].trailingContextLines.length).toBe(3);
      expect(result.matches[0].trailingContextLines[0]).toBe("    if (items.length <= 1) return items;");
      expect(result.matches[0].trailingContextLines[1]).toBe("    var pivot = items.shift(), current, left = [], right = [];");
      expect(result.matches[0].trailingContextLines[2]).toBe("    while(items.length > 0) {");
      expect(result.matches[5].leadingContextLines.length).toBe(2);
      expect(result.matches[5].trailingContextLines.length).toBe(3);

      editor.setText("there are some items in here");
      advanceClock(editor.buffer.stoppedChangingDelay);
      expect(resultAddedSpy.callCount).toBe(1);
      expect(resultSetSpy.callCount).toBe(1);

      result = resultsModel.getResult(editor.getPath());
      expect(result.matches.length).toBe(1);
      expect(resultsModel.getPathCount()).toBe(1);
      expect(resultsModel.getMatchCount()).toBe(1);
      expect(resultsModel.getPaths()).toEqual([editor.getPath()]);
      expect(result.matches[0].lineText).toBe("there are some items in here");
      expect(result.matches[0].leadingContextLines.length).toBe(0);
      expect(result.matches[0].trailingContextLines.length).toBe(0);

      editor.setText("no matches in here");
      advanceClock(editor.buffer.stoppedChangingDelay);
      expect(resultAddedSpy.callCount).toBe(1);
      expect(resultSetSpy.callCount).toBe(1);
      expect(resultRemovedSpy.callCount).toBe(1);

      result = resultsModel.getResult(editor.getPath());
      expect(result).not.toBeDefined();
      expect(resultsModel.getPathCount()).toBe(0);
      expect(resultsModel.getMatchCount()).toBe(0);

      resultsModel.clear();
      spyOn(editor, "scan").andCallThrough();
      editor.setText("no matches in here");
      advanceClock(editor.buffer.stoppedChangingDelay);
      expect(editor.scan).not.toHaveBeenCalled();
      expect(resultsModel.getPathCount()).toBe(0);
      expect(resultsModel.getMatchCount()).toBe(0);
    });

    it("ignores changes in untitled buffers", async () => {
      await atom.workspace.open();
      await resultsModel.search("items", "*.js", "");

      editor = atom.workspace.getCenter().getActiveTextEditor();
      editor.setText("items\nitems");
      spyOn(editor, "scan").andCallThrough();
      advanceClock(editor.buffer.stoppedChangingDelay);
      expect(editor.scan).not.toHaveBeenCalled();
    });

    it("contains valid match objects after destroying a buffer (regression)", async () => {
      await resultsModel.search('items', '*.js', '');

      advanceClock(editor.buffer.stoppedChangingDelay)
      editor.getBuffer().destroy()
      result = resultsModel.getResult(editor.getPath())
      expect(result.matches[0].lineText).toBe("  var sort = function(items) {")
    });
  });

  describe("cancelling a search", () => {
    let cancelledSpy;

    beforeEach(() => {
      cancelledSpy = jasmine.createSpy();
      resultsModel.onDidCancelSearching(cancelledSpy);
    });

    it("populates the model with all the results, and updates in response to changes in the buffer", async () => {
      const searchPromise = resultsModel.search("items", "*.js", "");
      expect(resultsModel.inProgressSearchPromise).toBeTruthy();
      resultsModel.clear();
      expect(resultsModel.inProgressSearchPromise).toBeFalsy();

      await searchPromise;
      expect(cancelledSpy).toHaveBeenCalled();
    });

    it("populates the model with all the results, and updates in response to changes in the buffer", async () => {
      resultsModel.search("items", "*.js", "");
      await resultsModel.search("sort", "*.js", "");

      expect(cancelledSpy).toHaveBeenCalled();
      expect(resultsModel.getPathCount()).toBe(1);
      expect(resultsModel.getMatchCount()).toBe(5);
    });
  });

  describe("logging metrics", () => {
    it("logs the elapsed time and the number of results", async () => {
      await resultsModel.search('items', '*.js', '');

      advanceClock(editor.buffer.stoppedChangingDelay)
      editor.getBuffer().destroy()
      result = resultsModel.getResult(editor.getPath())

      expect(Number.isInteger(reporterSpy.sendSearchEvent.calls[0].args[0])).toBeTruthy()
      expect(reporterSpy.sendSearchEvent.calls[0].args[1]).toBe(6)
    });
  });
});
