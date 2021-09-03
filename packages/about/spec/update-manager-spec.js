const UpdateManager = require('../lib/update-manager');

describe('UpdateManager', () => {
  let updateManager;

  beforeEach(() => {
    updateManager = new UpdateManager();
  });

  describe('::getReleaseNotesURLForVersion', () => {
    it('returns atom.io releases when dev version', () => {
      expect(
        updateManager.getReleaseNotesURLForVersion('1.7.0-dev-e44b57d')
      ).toContain('atom.io/releases');
    });

    it('returns the page for the release when not a dev version', () => {
      expect(updateManager.getReleaseNotesURLForVersion('1.7.0')).toContain(
        'atom/atom/releases/tag/v1.7.0'
      );
      expect(updateManager.getReleaseNotesURLForVersion('v1.7.0')).toContain(
        'atom/atom/releases/tag/v1.7.0'
      );
      expect(
        updateManager.getReleaseNotesURLForVersion('1.7.0-beta10')
      ).toContain('atom/atom/releases/tag/v1.7.0-beta10');
      expect(
        updateManager.getReleaseNotesURLForVersion('1.7.0-nightly10')
      ).toContain('atom/atom-nightly-releases/releases/tag/v1.7.0-nightly10');
    });
  });
});
