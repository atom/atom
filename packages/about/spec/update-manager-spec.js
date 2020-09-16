const UpdateManager = require('../lib/update-manager');

const REPO_OWNER = process.env.REPO_OWNER || 'atom';
const MAIN_REPO = process.env.MAIN_REPO || 'atom';
const NIGHTLY_RELEASE_REPO =
  process.env.NIGHTLY_RELEASE_REPO || 'atom-nightly-releases';

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
        `${REPO_OWNER}/${MAIN_REPO}/releases/tag/v1.7.0`
      );
      expect(updateManager.getReleaseNotesURLForVersion('v1.7.0')).toContain(
        `${REPO_OWNER}/${MAIN_REPO}/releases/tag/v1.7.0`
      );
      expect(
        updateManager.getReleaseNotesURLForVersion('1.7.0-beta10')
      ).toContain(`${REPO_OWNER}/${MAIN_REPO}/releases/tag/v1.7.0-beta10`);
      expect(
        updateManager.getReleaseNotesURLForVersion('1.7.0-nightly10')
      ).toContain(`${REPO_OWNER}/${NIGHTLY_RELEASE_REPO}/releases/tag/v1.7.0-nightly10`);
    });
  });
});
