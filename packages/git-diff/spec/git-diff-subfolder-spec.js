const path = require('path');
const fs = require('fs-plus');
const temp = require('temp').track();

describe('GitDiff when targeting nested repository', () => {
  let editor, editorElement, projectPath, screenUpdates;

  beforeEach(() => {
    screenUpdates = 0;
    spyOn(window, 'requestAnimationFrame').andCallFake(fn => {
      fn();
      screenUpdates++;
    });
    spyOn(window, 'cancelAnimationFrame').andCallFake(i => null);

    projectPath = temp.mkdirSync('git-diff-spec-');

    fs.copySync(path.join(__dirname, 'fixtures', 'working-dir'), projectPath);
    fs.moveSync(
      path.join(projectPath, 'git.git'),
      path.join(projectPath, '.git')
    );

    // The nested repo doesn't need to be managed by the temp module because
    // it's a part of our test environment.
    const nestedPath = path.join(projectPath, 'nested-repository');
    // When instantiating a GitRepository, the repository will always point
    // to the .git folder in it's path.
    const targetRepositoryPath = path.join(nestedPath, '.git');
    // Initialize the repository contents.
    fs.copySync(path.join(__dirname, 'fixtures', 'working-dir'), nestedPath);
    fs.moveSync(
      path.join(nestedPath, 'git.git'),
      path.join(nestedPath, '.git')
    );

    atom.project.setPaths([projectPath]);

    jasmine.attachToDOM(atom.workspace.getElement());

    waitsForPromise(async () => {
      await atom.workspace.open(path.join(nestedPath, 'sample.js'));
      await atom.packages.activatePackage('git-diff');
    });

    runs(() => {
      editor = atom.workspace.getActiveTextEditor();
      editorElement = atom.views.getView(editor);
    });
  });

  afterEach(() => {
    temp.cleanup();
  });
  
  describe('When git-diff targets a file in a nested git-repository', () => {
    /***
     * Non-hack regression prevention for nested repositories. If we know
     * that our project path contains two repositories, we can ensure that
     * git-diff is targeting the correct one by creating an artificial change
     * in the ancestor repository, which doesn't effect the target repository.
     * If our diff shows any kind of change to our target file, we're targeting
     * the incorrect repository.
     */
    it("uses the innermost repository", () => {
      //waitsForPromise(async () => await new Promise(resolve => setTimeout(resolve, 4000)));
      //waitsFor(() => !! atom.packages.isPackageLoaded("git-diff"));
      waitsFor(() => screenUpdates > 0);
      runs(() => expect(editor.getMarkers().length).toBe(0));
    });
  });
});
