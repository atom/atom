const path = require('path');
const SelectListView = require('atom-select-list');

describe('GrammarSelector', () => {
  let [editor, textGrammar, jsGrammar] = [];

  beforeEach(async () => {
    jasmine.attachToDOM(atom.views.getView(atom.workspace));
    atom.config.set('grammar-selector.showOnRightSideOfStatusBar', false);

    await atom.packages.activatePackage('status-bar');
    await atom.packages.activatePackage('grammar-selector');
    await atom.packages.activatePackage('language-text');
    await atom.packages.activatePackage('language-javascript');
    await atom.packages.activatePackage(
      path.join(__dirname, 'fixtures', 'language-with-no-name')
    );

    editor = await atom.workspace.open('sample.js');

    textGrammar = atom.grammars.grammarForScopeName('text.plain');
    expect(textGrammar).toBeTruthy();
    jsGrammar = atom.grammars.grammarForScopeName('source.js');
    expect(jsGrammar).toBeTruthy();
    expect(editor.getGrammar()).toBe(jsGrammar);
  });

  describe('when grammar-selector:show is triggered', () =>
    it('displays a list of all the available grammars', async () => {
      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      const grammarView = atom.workspace.getModalPanels()[0].getItem().element;
      // TODO: Remove once Atom 1.23 reaches stable
      if (parseFloat(atom.getVersion()) >= 1.23) {
        // Do not take into account the two JS regex grammars or language-with-no-name
        expect(grammarView.querySelectorAll('li').length).toBe(
          atom.grammars.grammars.length - 3
        );
      } else {
        expect(grammarView.querySelectorAll('li').length).toBe(
          atom.grammars.grammars.length - 1
        );
      }
      expect(grammarView.querySelectorAll('li')[0].textContent).toBe(
        'Auto Detect'
      );
      expect(grammarView.textContent.includes('source.a')).toBe(false);
      grammarView
        .querySelectorAll('li')
        .forEach(li =>
          expect(li.textContent).not.toBe(atom.grammars.nullGrammar.name)
        );
    }));

  describe('when a grammar is selected', () =>
    it('sets the new grammar on the editor', async () => {
      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      const grammarView = atom.workspace.getModalPanels()[0].getItem();
      grammarView.props.didConfirmSelection(textGrammar);
      expect(editor.getGrammar()).toBe(textGrammar);
    }));

  describe('when auto-detect is selected', () =>
    it('restores the auto-detected grammar on the editor', async () => {
      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      let grammarView = atom.workspace.getModalPanels()[0].getItem();
      grammarView.props.didConfirmSelection(textGrammar);
      expect(editor.getGrammar()).toBe(textGrammar);

      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      grammarView = atom.workspace.getModalPanels()[0].getItem();
      grammarView.props.didConfirmSelection(grammarView.items[0]);
      expect(editor.getGrammar()).toBe(jsGrammar);
    }));

  describe("when the editor's current grammar is the null grammar", () =>
    it('displays Auto Detect as the selected grammar', async () => {
      editor.setGrammar(atom.grammars.nullGrammar);
      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      const grammarView = atom.workspace.getModalPanels()[0].getItem().element;
      expect(grammarView.querySelector('li.active').textContent).toBe(
        'Auto Detect'
      );
    }));

  describe('when editor is untitled', () =>
    it('sets the new grammar on the editor', async () => {
      editor = await atom.workspace.open();
      expect(editor.getGrammar()).not.toBe(jsGrammar);

      atom.commands.dispatch(editor.getElement(), 'grammar-selector:show');
      await SelectListView.getScheduler().getNextUpdatePromise();

      const grammarView = atom.workspace.getModalPanels()[0].getItem();
      grammarView.props.didConfirmSelection(jsGrammar);
      expect(editor.getGrammar()).toBe(jsGrammar);
    }));

  describe('Status bar grammar label', () => {
    let [grammarStatus, grammarTile, statusBar] = [];

    beforeEach(async () => {
      statusBar = document.querySelector('status-bar');
      [grammarTile] = statusBar.getLeftTiles().slice(-1);
      grammarStatus = grammarTile.getItem();

      // Wait for status bar service hook to fire
      while (!grammarStatus || !grammarStatus.textContent) {
        await atom.views.getNextUpdatePromise();
        grammarStatus = document.querySelector('.grammar-status');
      }
    });

    it('displays the name of the current grammar', () => {
      expect(grammarStatus.querySelector('a').textContent).toBe('JavaScript');
      expect(getTooltipText(grammarStatus)).toBe(
        'File uses the JavaScript grammar'
      );
    });

    it('displays Plain Text when the current grammar is the null grammar', async () => {
      editor.setGrammar(atom.grammars.nullGrammar);
      await atom.views.getNextUpdatePromise();

      expect(grammarStatus.querySelector('a').textContent).toBe('Plain Text');
      expect(grammarStatus).toBeVisible();
      expect(getTooltipText(grammarStatus)).toBe(
        'File uses the Plain Text grammar'
      );

      editor.setGrammar(atom.grammars.grammarForScopeName('source.js'));
      await atom.views.getNextUpdatePromise();

      expect(grammarStatus.querySelector('a').textContent).toBe('JavaScript');
      expect(grammarStatus).toBeVisible();
    });

    it('hides the label when the current grammar is null', async () => {
      jasmine.attachToDOM(editor.getElement());
      spyOn(editor, 'getGrammar').andReturn(null);
      editor.setGrammar(atom.grammars.nullGrammar);
      await atom.views.getNextUpdatePromise();
      expect(grammarStatus.offsetHeight).toBe(0);
    });

    describe('when the grammar-selector.showOnRightSideOfStatusBar setting changes', () =>
      it('moves the item to the preferred side of the status bar', () => {
        expect(statusBar.getLeftTiles().map(tile => tile.getItem())).toContain(
          grammarStatus
        );
        expect(
          statusBar.getRightTiles().map(tile => tile.getItem())
        ).not.toContain(grammarStatus);

        atom.config.set('grammar-selector.showOnRightSideOfStatusBar', true);

        expect(
          statusBar.getLeftTiles().map(tile => tile.getItem())
        ).not.toContain(grammarStatus);
        expect(statusBar.getRightTiles().map(tile => tile.getItem())).toContain(
          grammarStatus
        );

        atom.config.set('grammar-selector.showOnRightSideOfStatusBar', false);

        expect(statusBar.getLeftTiles().map(tile => tile.getItem())).toContain(
          grammarStatus
        );
        expect(
          statusBar.getRightTiles().map(tile => tile.getItem())
        ).not.toContain(grammarStatus);
      }));

    describe("when the editor's grammar changes", () =>
      it('displays the new grammar of the editor', async () => {
        editor.setGrammar(atom.grammars.grammarForScopeName('text.plain'));
        await atom.views.getNextUpdatePromise();

        expect(grammarStatus.querySelector('a').textContent).toBe('Plain Text');
        expect(getTooltipText(grammarStatus)).toBe(
          'File uses the Plain Text grammar'
        );

        editor.setGrammar(atom.grammars.grammarForScopeName('source.a'));
        await atom.views.getNextUpdatePromise();

        expect(grammarStatus.querySelector('a').textContent).toBe('source.a');
        expect(getTooltipText(grammarStatus)).toBe(
          'File uses the source.a grammar'
        );
      }));

    describe('when clicked', () =>
      it('shows the grammar selector modal', () => {
        const eventHandler = jasmine.createSpy('eventHandler');
        atom.commands.add(
          editor.getElement(),
          'grammar-selector:show',
          eventHandler
        );
        grammarStatus.click();
        expect(eventHandler).toHaveBeenCalled();
      }));

    describe('when the package is deactivated', () =>
      it('removes the view', () => {
        spyOn(grammarTile, 'destroy');
        atom.packages.deactivatePackage('grammar-selector');
        expect(grammarTile.destroy).toHaveBeenCalled();
      }));
  });
});

function getTooltipText(element) {
  const [tooltip] = atom.tooltips.findTooltips(element);
  return tooltip.getTitle();
}
