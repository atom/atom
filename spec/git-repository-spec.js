const path = require('path');
const fs = require('fs-plus');
const temp = require('temp').track();
const GitRepository = require('../src/git-repository');
const Project = require('../src/project');

describe('GitRepository', () => {
  let repo;

  beforeEach(() => {
    const gitPath = path.join(temp.dir, '.git');
    if (fs.isDirectorySync(gitPath)) fs.removeSync(gitPath);
  });

  afterEach(() => {
    if (repo && !repo.isDestroyed()) repo.destroy();
  });

  describe('@open(path)', () => {
    it('returns null when no repository is found', () => {
      expect(GitRepository.open(path.join(temp.dir, 'nogit.txt'))).toBeNull();
    });
  });

  describe('new GitRepository(path)', () => {
    it('throws an exception when no repository is found', () => {
      expect(
        () => new GitRepository(path.join(temp.dir, 'nogit.txt'))
      ).toThrow();
    });
  });

  describe('.getPath()', () => {
    it('returns the repository path for a .git directory path with a directory', () => {
      repo = new GitRepository(
        path.join(__dirname, 'fixtures', 'git', 'master.git', 'objects')
      );
      expect(repo.getPath()).toBe(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
    });

    it('returns the repository path for a repository path', () => {
      repo = new GitRepository(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
      expect(repo.getPath()).toBe(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
    });
  });

  describe('.isPathIgnored(path)', () => {
    it('returns true for an ignored path', () => {
      repo = new GitRepository(
        path.join(__dirname, 'fixtures', 'git', 'ignore.git')
      );
      expect(repo.isPathIgnored('a.txt')).toBeTruthy();
    });

    it('returns false for a non-ignored path', () => {
      repo = new GitRepository(
        path.join(__dirname, 'fixtures', 'git', 'ignore.git')
      );
      expect(repo.isPathIgnored('b.txt')).toBeFalsy();
    });
  });

  describe('.isPathModified(path)', () => {
    let filePath, newPath;

    beforeEach(() => {
      const workingDirPath = copyRepository();
      repo = new GitRepository(workingDirPath);
      filePath = path.join(workingDirPath, 'a.txt');
      newPath = path.join(workingDirPath, 'new-path.txt');
    });

    describe('when the path is unstaged', () => {
      it('returns false if the path has not been modified', () => {
        expect(repo.isPathModified(filePath)).toBeFalsy();
      });

      it('returns true if the path is modified', () => {
        fs.writeFileSync(filePath, 'change');
        expect(repo.isPathModified(filePath)).toBeTruthy();
      });

      it('returns true if the path is deleted', () => {
        fs.removeSync(filePath);
        expect(repo.isPathModified(filePath)).toBeTruthy();
      });

      it('returns false if the path is new', () => {
        expect(repo.isPathModified(newPath)).toBeFalsy();
      });
    });
  });

  describe('.isPathNew(path)', () => {
    let filePath, newPath;

    beforeEach(() => {
      const workingDirPath = copyRepository();
      repo = new GitRepository(workingDirPath);
      filePath = path.join(workingDirPath, 'a.txt');
      newPath = path.join(workingDirPath, 'new-path.txt');
      fs.writeFileSync(newPath, "i'm new here");
    });

    describe('when the path is unstaged', () => {
      it('returns true if the path is new', () => {
        expect(repo.isPathNew(newPath)).toBeTruthy();
      });

      it("returns false if the path isn't new", () => {
        expect(repo.isPathNew(filePath)).toBeFalsy();
      });
    });
  });

  describe('.checkoutHead(path)', () => {
    let filePath;

    beforeEach(() => {
      const workingDirPath = copyRepository();
      repo = new GitRepository(workingDirPath);
      filePath = path.join(workingDirPath, 'a.txt');
    });

    it('no longer reports a path as modified after checkout', () => {
      expect(repo.isPathModified(filePath)).toBeFalsy();
      fs.writeFileSync(filePath, 'ch ch changes');
      expect(repo.isPathModified(filePath)).toBeTruthy();
      expect(repo.checkoutHead(filePath)).toBeTruthy();
      expect(repo.isPathModified(filePath)).toBeFalsy();
    });

    it('restores the contents of the path to the original text', () => {
      fs.writeFileSync(filePath, 'ch ch changes');
      expect(repo.checkoutHead(filePath)).toBeTruthy();
      expect(fs.readFileSync(filePath, 'utf8')).toBe('');
    });

    it('fires a status-changed event if the checkout completes successfully', () => {
      fs.writeFileSync(filePath, 'ch ch changes');
      repo.getPathStatus(filePath);
      const statusHandler = jasmine.createSpy('statusHandler');
      repo.onDidChangeStatus(statusHandler);
      repo.checkoutHead(filePath);
      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler.argsForCall[0][0]).toEqual({
        path: filePath,
        pathStatus: 0
      });

      repo.checkoutHead(filePath);
      expect(statusHandler.callCount).toBe(1);
    });
  });

  describe('.checkoutHeadForEditor(editor)', () => {
    let filePath, editor;

    beforeEach(async () => {
      spyOn(atom, 'confirm');

      const workingDirPath = copyRepository();
      repo = new GitRepository(workingDirPath, {
        project: atom.project,
        config: atom.config,
        confirm: atom.confirm
      });
      filePath = path.join(workingDirPath, 'a.txt');
      fs.writeFileSync(filePath, 'ch ch changes');

      editor = await atom.workspace.open(filePath);
    });

    it('displays a confirmation dialog by default', () => {
      // Permissions issues with this test on Windows
      if (process.platform === 'win32') return;

      atom.confirm.andCallFake(({ buttons }) => buttons.OK());
      atom.config.set('editor.confirmCheckoutHeadRevision', true);

      repo.checkoutHeadForEditor(editor);

      expect(fs.readFileSync(filePath, 'utf8')).toBe('');
    });

    it('does not display a dialog when confirmation is disabled', () => {
      // Flakey EPERM opening a.txt on Win32
      if (process.platform === 'win32') return;
      atom.config.set('editor.confirmCheckoutHeadRevision', false);

      repo.checkoutHeadForEditor(editor);

      expect(fs.readFileSync(filePath, 'utf8')).toBe('');
      expect(atom.confirm).not.toHaveBeenCalled();
    });
  });

  describe('.destroy()', () => {
    it('throws an exception when any method is called after it is called', () => {
      repo = new GitRepository(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
      repo.destroy();
      expect(() => repo.getShortHead()).toThrow();
    });
  });

  describe('.getPathStatus(path)', () => {
    let filePath;

    beforeEach(() => {
      const workingDirectory = copyRepository();
      repo = new GitRepository(workingDirectory);
      filePath = path.join(workingDirectory, 'file.txt');
    });

    it('trigger a status-changed event when the new status differs from the last cached one', () => {
      const statusHandler = jasmine.createSpy('statusHandler');
      repo.onDidChangeStatus(statusHandler);
      fs.writeFileSync(filePath, '');
      let status = repo.getPathStatus(filePath);
      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler.argsForCall[0][0]).toEqual({
        path: filePath,
        pathStatus: status
      });

      fs.writeFileSync(filePath, 'abc');
      status = repo.getPathStatus(filePath);
      expect(statusHandler.callCount).toBe(1);
    });
  });

  describe('.getDirectoryStatus(path)', () => {
    let directoryPath, filePath;

    beforeEach(() => {
      const workingDirectory = copyRepository();
      repo = new GitRepository(workingDirectory);
      directoryPath = path.join(workingDirectory, 'dir');
      filePath = path.join(directoryPath, 'b.txt');
    });

    it('gets the status based on the files inside the directory', () => {
      expect(
        repo.isStatusModified(repo.getDirectoryStatus(directoryPath))
      ).toBe(false);
      fs.writeFileSync(filePath, 'abc');
      repo.getPathStatus(filePath);
      expect(
        repo.isStatusModified(repo.getDirectoryStatus(directoryPath))
      ).toBe(true);
    });
  });

  describe('.refreshStatus()', () => {
    let newPath, modifiedPath, cleanPath, workingDirectory;

    beforeEach(() => {
      workingDirectory = copyRepository();
      repo = new GitRepository(workingDirectory, {
        project: atom.project,
        config: atom.config
      });
      modifiedPath = path.join(workingDirectory, 'file.txt');
      newPath = path.join(workingDirectory, 'untracked.txt');
      cleanPath = path.join(workingDirectory, 'other.txt');
      fs.writeFileSync(cleanPath, 'Full of text');
      fs.writeFileSync(newPath, '');
      newPath = fs.absolute(newPath);
    });

    it('returns status information for all new and modified files', async () => {
      const statusHandler = jasmine.createSpy('statusHandler');
      repo.onDidChangeStatuses(statusHandler);
      fs.writeFileSync(modifiedPath, 'making this path modified');

      await repo.refreshStatus();
      expect(statusHandler.callCount).toBe(1);
      expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined();
      expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy();
      expect(
        repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))
      ).toBeTruthy();
    });

    it('caches the proper statuses when a subdir is open', async () => {
      const subDir = path.join(workingDirectory, 'dir');
      fs.mkdirSync(subDir);
      const filePath = path.join(subDir, 'b.txt');
      fs.writeFileSync(filePath, '');
      atom.project.setPaths([subDir]);
      await atom.workspace.open('b.txt');
      repo = atom.project.getRepositories()[0];

      await repo.refreshStatus();
      const status = repo.getCachedPathStatus(filePath);
      expect(repo.isStatusModified(status)).toBe(false);
      expect(repo.isStatusNew(status)).toBe(false);
    });

    it('works correctly when the project has multiple folders (regression)', async () => {
      atom.project.addPath(workingDirectory);
      atom.project.addPath(path.join(__dirname, 'fixtures', 'dir'));

      await repo.refreshStatus();
      expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined();
      expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy();
      expect(
        repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))
      ).toBeTruthy();
    });

    it('caches statuses that were looked up synchronously', async () => {
      const originalContent = 'undefined';
      fs.writeFileSync(modifiedPath, 'making this path modified');
      repo.getPathStatus('file.txt');

      fs.writeFileSync(modifiedPath, originalContent);
      await repo.refreshStatus();
      expect(
        repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))
      ).toBeFalsy();
    });
  });

  describe('buffer events', () => {
    let editor;

    beforeEach(async () => {
      atom.project.setPaths([copyRepository()]);
      const refreshPromise = new Promise(resolve =>
        atom.project.getRepositories()[0].onDidChangeStatuses(resolve)
      );
      editor = await atom.workspace.open('other.txt');
      await refreshPromise;
    });

    it('emits a status-changed event when a buffer is saved', async () => {
      editor.insertNewline();

      const statusHandler = jasmine.createSpy('statusHandler');
      atom.project.getRepositories()[0].onDidChangeStatus(statusHandler);

      await editor.save();
      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler).toHaveBeenCalledWith({
        path: editor.getPath(),
        pathStatus: 256
      });
    });

    it('emits a status-changed event when a buffer is reloaded', async () => {
      fs.writeFileSync(editor.getPath(), 'changed');

      const statusHandler = jasmine.createSpy('statusHandler');
      atom.project.getRepositories()[0].onDidChangeStatus(statusHandler);

      await editor.getBuffer().reload();
      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler).toHaveBeenCalledWith({
        path: editor.getPath(),
        pathStatus: 256
      });

      await editor.getBuffer().reload();
      expect(statusHandler.callCount).toBe(1);
    });

    it("emits a status-changed event when a buffer's path changes", () => {
      fs.writeFileSync(editor.getPath(), 'changed');

      const statusHandler = jasmine.createSpy('statusHandler');
      atom.project.getRepositories()[0].onDidChangeStatus(statusHandler);
      editor.getBuffer().emitter.emit('did-change-path');
      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler).toHaveBeenCalledWith({
        path: editor.getPath(),
        pathStatus: 256
      });
      editor.getBuffer().emitter.emit('did-change-path');
      expect(statusHandler.callCount).toBe(1);
    });

    it('stops listening to the buffer when the repository is destroyed (regression)', () => {
      atom.project.getRepositories()[0].destroy();
      expect(() => editor.save()).not.toThrow();
    });
  });

  describe('when a project is deserialized', () => {
    let buffer, project2, statusHandler;

    afterEach(() => {
      if (project2) project2.destroy();
    });

    it('subscribes to all the serialized buffers in the project', async () => {
      atom.project.setPaths([copyRepository()]);

      await atom.workspace.open('file.txt');

      project2 = new Project({
        notificationManager: atom.notifications,
        packageManager: atom.packages,
        confirm: atom.confirm,
        grammarRegistry: atom.grammars,
        applicationDelegate: atom.applicationDelegate
      });
      await project2.deserialize(
        atom.project.serialize({ isUnloading: false })
      );

      buffer = project2.getBuffers()[0];
      buffer.append('changes');

      statusHandler = jasmine.createSpy('statusHandler');
      project2.getRepositories()[0].onDidChangeStatus(statusHandler);
      await buffer.save();

      expect(statusHandler.callCount).toBe(1);
      expect(statusHandler).toHaveBeenCalledWith({
        path: buffer.getPath(),
        pathStatus: 256
      });
    });
  });
});

function copyRepository() {
  const workingDirPath = temp.mkdirSync('atom-spec-git');
  fs.copySync(
    path.join(__dirname, 'fixtures', 'git', 'working-dir'),
    workingDirPath
  );
  fs.renameSync(
    path.join(workingDirPath, 'git.git'),
    path.join(workingDirPath, '.git')
  );
  return workingDirPath;
}
