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
     * in the ancestor repository, which is percieved differently within the
     * child. In this case, creating a new file will not generate markers in
     * the ancestor repo, even if there are changes; but changes will be
     * marked within the child repo. So all we have to do is check if
     * markers exist and we know we're targeting the proper repository,
     * If no markers exist, we're targeting an ancestor repo.
     */
    it('uses the innermost repository', () => {
      editor.insertText('a');
      waitsFor(() => screenUpdates > 0);
      runs(() => {
        expect(
          editorElement.querySelectorAll('.git-line-modified').length
        ).toBe(1);
      });
    });
  });
});
