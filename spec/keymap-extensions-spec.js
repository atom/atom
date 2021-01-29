const temp = require('temp').track();
const fs = require('fs-plus');

describe('keymap-extensions', function() {
  beforeEach(function() {
    atom.keymaps.configDirPath = temp.path('atom-spec-keymap-ext');
    fs.writeFileSync(atom.keymaps.getUserKeymapPath(), '#');
    this.userKeymapLoaded = function() {};
    atom.keymaps.onDidLoadUserKeymap(() => this.userKeymapLoaded());
  });

  afterEach(function() {
    fs.removeSync(atom.keymaps.configDirPath);
    atom.keymaps.destroy();
  });

  describe('did-load-user-keymap', () =>
    it('fires when user keymap is loaded', function() {
      spyOn(this, 'userKeymapLoaded');
      atom.keymaps.loadUserKeymap();
      expect(this.userKeymapLoaded).toHaveBeenCalled();
    }));
});
