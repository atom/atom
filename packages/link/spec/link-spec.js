const { shell } = require('electron');

describe('link package', () => {
  beforeEach(async () => {
    await atom.packages.activatePackage('language-gfm');
    await atom.packages.activatePackage('language-hyperlink');

    const activationPromise = atom.packages.activatePackage('link');
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'link:open');
    await activationPromise;
  });

  describe('when the cursor is on a link', () => {
    it("opens the link using the 'open' command", async () => {
      await atom.workspace.open('sample.md');

      const editor = atom.workspace.getActiveTextEditor();
      editor.setText('// "http://github.com"');

      spyOn(shell, 'openExternal');
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');
      expect(shell.openExternal).not.toHaveBeenCalled();

      editor.setCursorBufferPosition([0, 4]);
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');

      expect(shell.openExternal).toHaveBeenCalled();
      expect(shell.openExternal.argsForCall[0][0]).toBe('http://github.com');

      shell.openExternal.reset();
      editor.setCursorBufferPosition([0, 8]);
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');

      expect(shell.openExternal).toHaveBeenCalled();
      expect(shell.openExternal.argsForCall[0][0]).toBe('http://github.com');

      shell.openExternal.reset();
      editor.setCursorBufferPosition([0, 21]);
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');

      expect(shell.openExternal).toHaveBeenCalled();
      expect(shell.openExternal.argsForCall[0][0]).toBe('http://github.com');
    });

    // only works in Atom >= 1.33.0
    // https://github.com/atom/link/pull/33#issuecomment-419643655
    const atomVersion = atom.getVersion().split('.');
    console.error('atomVersion', atomVersion);
    if (+atomVersion[0] > 1 || +atomVersion[1] >= 33) {
      it("opens an 'atom:' link", async () => {
        await atom.workspace.open('sample.md');

        const editor = atom.workspace.getActiveTextEditor();
        editor.setText(
          '// "atom://core/open/file?filename=sample.js&line=1&column=2"'
        );

        spyOn(shell, 'openExternal');
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');
        expect(shell.openExternal).not.toHaveBeenCalled();

        editor.setCursorBufferPosition([0, 4]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');

        expect(shell.openExternal).toHaveBeenCalled();
        expect(shell.openExternal.argsForCall[0][0]).toBe(
          'atom://core/open/file?filename=sample.js&line=1&column=2'
        );

        shell.openExternal.reset();
        editor.setCursorBufferPosition([0, 8]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');

        expect(shell.openExternal).toHaveBeenCalled();
        expect(shell.openExternal.argsForCall[0][0]).toBe(
          'atom://core/open/file?filename=sample.js&line=1&column=2'
        );

        shell.openExternal.reset();
        editor.setCursorBufferPosition([0, 60]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');

        expect(shell.openExternal).toHaveBeenCalled();
        expect(shell.openExternal.argsForCall[0][0]).toBe(
          'atom://core/open/file?filename=sample.js&line=1&column=2'
        );
      });
    }

    describe('when the cursor is on a [name][url-name] style markdown link', () =>
      it('opens the named url', async () => {
        await atom.workspace.open('README.md');

        const editor = atom.workspace.getActiveTextEditor();
        editor.setText(`\
you should [click][here]
you should not [click][her]

[here]: http://github.com\
`);

        spyOn(shell, 'openExternal');
        editor.setCursorBufferPosition([0, 0]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');
        expect(shell.openExternal).not.toHaveBeenCalled();

        editor.setCursorBufferPosition([0, 20]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');

        expect(shell.openExternal).toHaveBeenCalled();
        expect(shell.openExternal.argsForCall[0][0]).toBe('http://github.com');

        shell.openExternal.reset();
        editor.setCursorBufferPosition([1, 24]);
        atom.commands.dispatch(atom.views.getView(editor), 'link:open');

        expect(shell.openExternal).not.toHaveBeenCalled();
      }));

    it('does not open non http/https/atom links', async () => {
      await atom.workspace.open('sample.md');

      const editor = atom.workspace.getActiveTextEditor();
      editor.setText('// ftp://github.com\n');

      spyOn(shell, 'openExternal');
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');
      expect(shell.openExternal).not.toHaveBeenCalled();

      editor.setCursorBufferPosition([0, 5]);
      atom.commands.dispatch(atom.views.getView(editor), 'link:open');

      expect(shell.openExternal).not.toHaveBeenCalled();
    });
  });
});
