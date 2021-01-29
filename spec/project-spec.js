const temp = require('temp').track();
const TextBuffer = require('text-buffer');
const Project = require('../src/project');
const fs = require('fs-plus');
const path = require('path');
const { Directory } = require('pathwatcher');
const { stopAllWatchers } = require('../src/path-watcher');
const GitRepository = require('../src/git-repository');

describe('Project', () => {
  beforeEach(() => {
    const directory = atom.project.getDirectories()[0];
    const paths = directory ? [directory.resolve('dir')] : [null];
    atom.project.setPaths(paths);

    // Wait for project's service consumers to be asynchronously added
    waits(1);
  });

  describe('serialization', () => {
    let deserializedProject = null;
    let notQuittingProject = null;
    let quittingProject = null;

    afterEach(() => {
      if (deserializedProject != null) {
        deserializedProject.destroy();
      }
      if (notQuittingProject != null) {
        notQuittingProject.destroy();
      }
      if (quittingProject != null) {
        quittingProject.destroy();
      }
    });

    it("does not deserialize paths to directories that don't exist", () => {
      deserializedProject = new Project({
        notificationManager: atom.notifications,
        packageManager: atom.packages,
        confirm: atom.confirm,
        grammarRegistry: atom.grammars
      });
      const state = atom.project.serialize();
      state.paths.push('/directory/that/does/not/exist');

      let err = null;
      waitsForPromise(() =>
        deserializedProject.deserialize(state, atom.deserializers).catch(e => {
          err = e;
        })
      );

      runs(() => {
        expect(deserializedProject.getPaths()).toEqual(atom.project.getPaths());
        expect(err.missingProjectPaths).toEqual([
          '/directory/that/does/not/exist'
        ]);
      });
    });

    it('does not deserialize paths that are now files', () => {
      const childPath = path.join(temp.mkdirSync('atom-spec-project'), 'child');
      fs.mkdirSync(childPath);

      deserializedProject = new Project({
        notificationManager: atom.notifications,
        packageManager: atom.packages,
        confirm: atom.confirm,
        grammarRegistry: atom.grammars
      });
      atom.project.setPaths([childPath]);
      const state = atom.project.serialize();

      fs.rmdirSync(childPath);
      fs.writeFileSync(childPath, 'surprise!\n');

      let err = null;
      waitsForPromise(() =>
        deserializedProject.deserialize(state, atom.deserializers).catch(e => {
          err = e;
        })
      );

      runs(() => {
        expect(deserializedProject.getPaths()).toEqual([]);
        expect(err.missingProjectPaths).toEqual([childPath]);
      });
    });

    it('does not include unretained buffers in the serialized state', () => {
      waitsForPromise(() => atom.project.bufferForPath('a'));

      runs(() => {
        expect(atom.project.getBuffers().length).toBe(1);

        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => expect(deserializedProject.getBuffers().length).toBe(0));
    });

    it('listens for destroyed events on deserialized buffers and removes them when they are destroyed', () => {
      waitsForPromise(() => atom.workspace.open('a'));

      runs(() => {
        expect(atom.project.getBuffers().length).toBe(1);
        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => {
        expect(deserializedProject.getBuffers().length).toBe(1);
        deserializedProject.getBuffers()[0].destroy();
        expect(deserializedProject.getBuffers().length).toBe(0);
      });
    });

    it('does not deserialize buffers when their path is now a directory', () => {
      const pathToOpen = path.join(
        temp.mkdirSync('atom-spec-project'),
        'file.txt'
      );

      waitsForPromise(() => atom.workspace.open(pathToOpen));

      runs(() => {
        expect(atom.project.getBuffers().length).toBe(1);
        fs.mkdirSync(pathToOpen);
        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => expect(deserializedProject.getBuffers().length).toBe(0));
    });

    it('does not deserialize buffers when their path is inaccessible', () => {
      if (process.platform === 'win32') {
        return;
      } // chmod not supported on win32
      const pathToOpen = path.join(
        temp.mkdirSync('atom-spec-project'),
        'file.txt'
      );
      fs.writeFileSync(pathToOpen, '');

      waitsForPromise(() => atom.workspace.open(pathToOpen));

      runs(() => {
        expect(atom.project.getBuffers().length).toBe(1);
        fs.chmodSync(pathToOpen, '000');
        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => expect(deserializedProject.getBuffers().length).toBe(0));
    });

    it('does not deserialize buffers with their path is no longer present', () => {
      const pathToOpen = path.join(
        temp.mkdirSync('atom-spec-project'),
        'file.txt'
      );
      fs.writeFileSync(pathToOpen, '');

      waitsForPromise(() => atom.workspace.open(pathToOpen));

      runs(() => {
        expect(atom.project.getBuffers().length).toBe(1);
        fs.unlinkSync(pathToOpen);
        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => expect(deserializedProject.getBuffers().length).toBe(0));
    });

    it('deserializes buffers that have never been saved before', () => {
      const pathToOpen = path.join(
        temp.mkdirSync('atom-spec-project'),
        'file.txt'
      );

      waitsForPromise(() => atom.workspace.open(pathToOpen));

      runs(() => {
        atom.workspace.getActiveTextEditor().setText('unsaved\n');
        expect(atom.project.getBuffers().length).toBe(1);

        deserializedProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        deserializedProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => {
        expect(deserializedProject.getBuffers().length).toBe(1);
        expect(deserializedProject.getBuffers()[0].getPath()).toBe(pathToOpen);
        expect(deserializedProject.getBuffers()[0].getText()).toBe('unsaved\n');
      });
    });

    it('serializes marker layers and history only if Atom is quitting', () => {
      waitsForPromise(() => atom.workspace.open('a'));

      let bufferA = null;
      let layerA = null;
      let markerA = null;

      runs(() => {
        bufferA = atom.project.getBuffers()[0];
        layerA = bufferA.addMarkerLayer({ persistent: true });
        markerA = layerA.markPosition([0, 3]);
        bufferA.append('!');
        notQuittingProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        notQuittingProject.deserialize(
          atom.project.serialize({ isUnloading: false })
        )
      );

      runs(() => {
        expect(
          notQuittingProject.getBuffers()[0].getMarkerLayer(layerA.id),
          x => x.getMarker(markerA.id)
        ).toBeUndefined();
        expect(notQuittingProject.getBuffers()[0].undo()).toBe(false);
        quittingProject = new Project({
          notificationManager: atom.notifications,
          packageManager: atom.packages,
          confirm: atom.confirm,
          grammarRegistry: atom.grammars
        });
      });

      waitsForPromise(() =>
        quittingProject.deserialize(
          atom.project.serialize({ isUnloading: true })
        )
      );

      runs(() => {
        expect(quittingProject.getBuffers()[0].getMarkerLayer(layerA.id), x =>
          x.getMarker(markerA.id)
        ).not.toBeUndefined();
        expect(quittingProject.getBuffers()[0].undo()).toBe(true);
      });
    });
  });

  describe('when an editor is saved and the project has no path', () => {
    it("sets the project's path to the saved file's parent directory", () => {
      const tempFile = temp.openSync().path;
      atom.project.setPaths([]);
      expect(atom.project.getPaths()[0]).toBeUndefined();
      let editor = null;

      waitsForPromise(() =>
        atom.workspace.open().then(o => {
          editor = o;
        })
      );

      waitsForPromise(() => editor.saveAs(tempFile));

      runs(() =>
        expect(atom.project.getPaths()[0]).toBe(path.dirname(tempFile))
      );
    });
  });

  describe('.replace', () => {
    let projectSpecification, projectPath1, projectPath2;
    beforeEach(() => {
      atom.project.replace(null);
      projectPath1 = temp.mkdirSync('project-path1');
      projectPath2 = temp.mkdirSync('project-path2');
      projectSpecification = {
        paths: [projectPath1, projectPath2],
        originPath: 'originPath',
        config: {
          baz: 'buzz'
        }
      };
    });
    it('sets a project specification', () => {
      expect(atom.config.get('baz')).toBeUndefined();
      atom.project.replace(projectSpecification);
      expect(atom.project.getPaths()).toEqual([projectPath1, projectPath2]);
      expect(atom.config.get('baz')).toBe('buzz');
    });

    it('clears a project through replace with no params', () => {
      expect(atom.config.get('baz')).toBeUndefined();
      atom.project.replace(projectSpecification);
      expect(atom.config.get('baz')).toBe('buzz');
      expect(atom.project.getPaths()).toEqual([projectPath1, projectPath2]);
      atom.project.replace();
      expect(atom.config.get('baz')).toBeUndefined();
      expect(atom.project.getPaths()).toEqual([]);
    });

    it('responds to change of project specification', () => {
      let wasCalled = false;
      const callback = () => {
        wasCalled = true;
      };
      atom.project.onDidReplace(callback);
      atom.project.replace(projectSpecification);
      expect(wasCalled).toBe(true);
      wasCalled = false;
      atom.project.replace();
      expect(wasCalled).toBe(true);
    });
  });

  describe('before and after saving a buffer', () => {
    let buffer;
    beforeEach(() =>
      waitsForPromise(() =>
        atom.project
          .bufferForPath(path.join(__dirname, 'fixtures', 'sample.js'))
          .then(o => {
            buffer = o;
            buffer.retain();
          })
      )
    );

    afterEach(() => buffer.release());

    it('emits save events on the main process', () => {
      spyOn(atom.project.applicationDelegate, 'emitDidSavePath');
      spyOn(atom.project.applicationDelegate, 'emitWillSavePath');

      waitsForPromise(() => buffer.save());

      runs(() => {
        expect(
          atom.project.applicationDelegate.emitDidSavePath.calls.length
        ).toBe(1);
        expect(
          atom.project.applicationDelegate.emitDidSavePath
        ).toHaveBeenCalledWith(buffer.getPath());
        expect(
          atom.project.applicationDelegate.emitWillSavePath.calls.length
        ).toBe(1);
        expect(
          atom.project.applicationDelegate.emitWillSavePath
        ).toHaveBeenCalledWith(buffer.getPath());
      });
    });
  });

  describe('when a watch error is thrown from the TextBuffer', () => {
    let editor = null;
    beforeEach(() =>
      waitsForPromise(() =>
        atom.workspace.open(require.resolve('./fixtures/dir/a')).then(o => {
          editor = o;
        })
      )
    );

    it('creates a warning notification', () => {
      let noteSpy;
      atom.notifications.onDidAddNotification((noteSpy = jasmine.createSpy()));

      const error = new Error('SomeError');
      error.eventType = 'resurrect';
      editor.buffer.emitter.emit('will-throw-watch-error', {
        handle: jasmine.createSpy(),
        error
      });

      expect(noteSpy).toHaveBeenCalled();

      const notification = noteSpy.mostRecentCall.args[0];
      expect(notification.getType()).toBe('warning');
      expect(notification.getDetail()).toBe('SomeError');
      expect(notification.getMessage()).toContain('`resurrect`');
      expect(notification.getMessage()).toContain(
        path.join('fixtures', 'dir', 'a')
      );
    });
  });

  describe('when a custom repository-provider service is provided', () => {
    let fakeRepositoryProvider, fakeRepository;

    beforeEach(() => {
      fakeRepository = {
        destroy() {
          return null;
        }
      };
      fakeRepositoryProvider = {
        repositoryForDirectory(directory) {
          return Promise.resolve(fakeRepository);
        },
        repositoryForDirectorySync(directory) {
          return fakeRepository;
        }
      };
    });

    it('uses it to create repositories for any directories that need one', () => {
      const projectPath = temp.mkdirSync('atom-project');
      atom.project.setPaths([projectPath]);
      expect(atom.project.getRepositories()).toEqual([null]);

      atom.packages.serviceHub.provide(
        'atom.repository-provider',
        '0.1.0',
        fakeRepositoryProvider
      );
      waitsFor(() => atom.project.repositoryProviders.length > 1);
      runs(() => atom.project.getRepositories()[0] === fakeRepository);
    });

    it('does not create any new repositories if every directory has a repository', () => {
      const repositories = atom.project.getRepositories();
      expect(repositories.length).toEqual(1);
      expect(repositories[0]).toBeTruthy();

      atom.packages.serviceHub.provide(
        'atom.repository-provider',
        '0.1.0',
        fakeRepositoryProvider
      );
      waitsFor(() => atom.project.repositoryProviders.length > 1);
      runs(() => expect(atom.project.getRepositories()).toBe(repositories));
    });

    it('stops using it to create repositories when the service is removed', () => {
      atom.project.setPaths([]);

      const disposable = atom.packages.serviceHub.provide(
        'atom.repository-provider',
        '0.1.0',
        fakeRepositoryProvider
      );
      waitsFor(() => atom.project.repositoryProviders.length > 1);
      runs(() => {
        disposable.dispose();
        atom.project.addPath(temp.mkdirSync('atom-project'));
        expect(atom.project.getRepositories()).toEqual([null]);
      });
    });
  });

  describe('when a custom directory-provider service is provided', () => {
    class DummyDirectory {
      constructor(aPath) {
        this.path = aPath;
      }
      getPath() {
        return this.path;
      }
      getFile() {
        return {
          existsSync() {
            return false;
          }
        };
      }
      getSubdirectory() {
        return {
          existsSync() {
            return false;
          }
        };
      }
      isRoot() {
        return true;
      }
      existsSync() {
        return this.path.endsWith('does-exist');
      }
      contains(filePath) {
        return filePath.startsWith(this.path);
      }
      onDidChangeFiles(callback) {
        onDidChangeFilesCallback = callback;
        return { dispose: () => {} };
      }
    }

    let serviceDisposable = null;
    let onDidChangeFilesCallback = null;

    beforeEach(() => {
      serviceDisposable = atom.packages.serviceHub.provide(
        'atom.directory-provider',
        '0.1.0',
        {
          directoryForURISync(uri) {
            if (uri.startsWith('ssh://')) {
              return new DummyDirectory(uri);
            } else {
              return null;
            }
          }
        }
      );
      onDidChangeFilesCallback = null;

      waitsFor(() => atom.project.directoryProviders.length > 0);
    });

    it("uses the provider's custom directories for any paths that it handles", () => {
      const localPath = temp.mkdirSync('local-path');
      const remotePath = 'ssh://foreign-directory:8080/does-exist';

      atom.project.setPaths([localPath, remotePath]);

      let directories = atom.project.getDirectories();
      expect(directories[0].getPath()).toBe(localPath);
      expect(directories[0] instanceof Directory).toBe(true);
      expect(directories[1].getPath()).toBe(remotePath);
      expect(directories[1] instanceof DummyDirectory).toBe(true);

      // It does not add new remote paths that do not exist
      const nonExistentRemotePath =
        'ssh://another-directory:8080/does-not-exist';
      atom.project.addPath(nonExistentRemotePath);
      expect(atom.project.getDirectories().length).toBe(2);

      // It adds new remote paths if their directories exist.
      const newRemotePath = 'ssh://another-directory:8080/does-exist';
      atom.project.addPath(newRemotePath);
      directories = atom.project.getDirectories();
      expect(directories[2].getPath()).toBe(newRemotePath);
      expect(directories[2] instanceof DummyDirectory).toBe(true);
    });

    it('stops using the provider when the service is removed', () => {
      serviceDisposable.dispose();
      atom.project.setPaths(['ssh://foreign-directory:8080/does-exist']);
      expect(atom.project.getDirectories().length).toBe(0);
    });

    it('uses the custom onDidChangeFiles as the watcher if available', () => {
      // Ensure that all preexisting watchers are stopped
      waitsForPromise(() => stopAllWatchers());

      const remotePath = 'ssh://another-directory:8080/does-exist';
      runs(() => atom.project.setPaths([remotePath]));
      waitsForPromise(() => atom.project.getWatcherPromise(remotePath));

      runs(() => {
        expect(onDidChangeFilesCallback).not.toBeNull();

        const changeSpy = jasmine.createSpy('atom.project.onDidChangeFiles');
        const disposable = atom.project.onDidChangeFiles(changeSpy);

        const events = [{ action: 'created', path: remotePath + '/test.txt' }];
        onDidChangeFilesCallback(events);

        expect(changeSpy).toHaveBeenCalledWith(events);
        disposable.dispose();
      });
    });
  });

  describe('.open(path)', () => {
    let absolutePath, newBufferHandler;

    beforeEach(() => {
      absolutePath = require.resolve('./fixtures/dir/a');
      newBufferHandler = jasmine.createSpy('newBufferHandler');
      atom.project.onDidAddBuffer(newBufferHandler);
    });

    describe("when given an absolute path that isn't currently open", () => {
      it("returns a new edit session for the given path and emits 'buffer-created'", () => {
        let editor = null;
        waitsForPromise(() =>
          atom.workspace.open(absolutePath).then(o => {
            editor = o;
          })
        );

        runs(() => {
          expect(editor.buffer.getPath()).toBe(absolutePath);
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer);
        });
      });
    });

    describe("when given a relative path that isn't currently opened", () => {
      it("returns a new edit session for the given path (relative to the project root) and emits 'buffer-created'", () => {
        let editor = null;
        waitsForPromise(() =>
          atom.workspace.open(absolutePath).then(o => {
            editor = o;
          })
        );

        runs(() => {
          expect(editor.buffer.getPath()).toBe(absolutePath);
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer);
        });
      });
    });

    describe('when passed the path to a buffer that is currently opened', () => {
      it('returns a new edit session containing currently opened buffer', () => {
        let editor = null;

        waitsForPromise(() =>
          atom.workspace.open(absolutePath).then(o => {
            editor = o;
          })
        );

        runs(() => newBufferHandler.reset());

        waitsForPromise(() =>
          atom.workspace
            .open(absolutePath)
            .then(({ buffer }) => expect(buffer).toBe(editor.buffer))
        );

        waitsForPromise(() =>
          atom.workspace.open('a').then(({ buffer }) => {
            expect(buffer).toBe(editor.buffer);
            expect(newBufferHandler).not.toHaveBeenCalled();
          })
        );
      });
    });

    describe('when not passed a path', () => {
      it("returns a new edit session and emits 'buffer-created'", () => {
        let editor = null;
        waitsForPromise(() =>
          atom.workspace.open().then(o => {
            editor = o;
          })
        );

        runs(() => {
          expect(editor.buffer.getPath()).toBeUndefined();
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer);
        });
      });
    });
  });

  describe('.bufferForPath(path)', () => {
    let buffer = null;

    beforeEach(() =>
      waitsForPromise(() =>
        atom.project.bufferForPath('a').then(o => {
          buffer = o;
          buffer.retain();
        })
      )
    );

    afterEach(() => buffer.release());

    describe('when opening a previously opened path', () => {
      it('does not create a new buffer', () => {
        waitsForPromise(() =>
          atom.project
            .bufferForPath('a')
            .then(anotherBuffer => expect(anotherBuffer).toBe(buffer))
        );

        waitsForPromise(() =>
          atom.project
            .bufferForPath('b')
            .then(anotherBuffer => expect(anotherBuffer).not.toBe(buffer))
        );

        waitsForPromise(() =>
          Promise.all([
            atom.project.bufferForPath('c'),
            atom.project.bufferForPath('c')
          ]).then(([buffer1, buffer2]) => {
            expect(buffer1).toBe(buffer2);
          })
        );
      });

      it('retries loading the buffer if it previously failed', () => {
        waitsForPromise({ shouldReject: true }, () => {
          spyOn(TextBuffer, 'load').andCallFake(() =>
            Promise.reject(new Error('Could not open file'))
          );
          return atom.project.bufferForPath('b');
        });

        waitsForPromise({ shouldReject: false }, () => {
          TextBuffer.load.andCallThrough();
          return atom.project.bufferForPath('b');
        });
      });

      it('creates a new buffer if the previous buffer was destroyed', () => {
        buffer.release();

        waitsForPromise(() =>
          atom.project
            .bufferForPath('b')
            .then(anotherBuffer => expect(anotherBuffer).not.toBe(buffer))
        );
      });
    });
  });

  describe('.repositoryForDirectory(directory)', () => {
    it('resolves to null when the directory does not have a repository', () => {
      waitsForPromise(() => {
        const directory = new Directory('/tmp');
        return atom.project.repositoryForDirectory(directory).then(result => {
          expect(result).toBeNull();
          expect(atom.project.repositoryProviders.length).toBeGreaterThan(0);
          expect(atom.project.repositoryPromisesByPath.size).toBe(0);
        });
      });
    });

    it('resolves to a GitRepository and is cached when the given directory is a Git repo', () => {
      waitsForPromise(() => {
        const directory = new Directory(path.join(__dirname, '..'));
        const promise = atom.project.repositoryForDirectory(directory);
        return promise.then(result => {
          expect(result).toBeInstanceOf(GitRepository);
          const dirPath = directory.getRealPathSync();
          expect(result.getPath()).toBe(path.join(dirPath, '.git'));

          // Verify that the result is cached.
          expect(atom.project.repositoryForDirectory(directory)).toBe(promise);
        });
      });
    });

    it('creates a new repository if a previous one with the same directory had been destroyed', () => {
      let repository = null;
      const directory = new Directory(path.join(__dirname, '..'));

      waitsForPromise(() =>
        atom.project.repositoryForDirectory(directory).then(repo => {
          repository = repo;
        })
      );

      runs(() => {
        expect(repository.isDestroyed()).toBe(false);
        repository.destroy();
        expect(repository.isDestroyed()).toBe(true);
      });

      waitsForPromise(() =>
        atom.project.repositoryForDirectory(directory).then(repo => {
          repository = repo;
        })
      );

      runs(() => expect(repository.isDestroyed()).toBe(false));
    });
  });

  describe('.setPaths(paths, options)', () => {
    describe('when path is a file', () => {
      it("sets its path to the file's parent directory and updates the root directory", () => {
        const filePath = require.resolve('./fixtures/dir/a');
        atom.project.setPaths([filePath]);
        expect(atom.project.getPaths()[0]).toEqual(path.dirname(filePath));
        expect(atom.project.getDirectories()[0].path).toEqual(
          path.dirname(filePath)
        );
      });
    });

    describe('when path is a directory', () => {
      it('assigns the directories and repositories', () => {
        const directory1 = temp.mkdirSync('non-git-repo');
        const directory2 = temp.mkdirSync('git-repo1');
        const directory3 = temp.mkdirSync('git-repo2');

        const gitDirPath = fs.absolute(
          path.join(__dirname, 'fixtures', 'git', 'master.git')
        );
        fs.copySync(gitDirPath, path.join(directory2, '.git'));
        fs.copySync(gitDirPath, path.join(directory3, '.git'));

        atom.project.setPaths([directory1, directory2, directory3]);

        const [repo1, repo2, repo3] = atom.project.getRepositories();
        expect(repo1).toBeNull();
        expect(repo2.getShortHead()).toBe('master');
        expect(repo2.getPath()).toBe(
          fs.realpathSync(path.join(directory2, '.git'))
        );
        expect(repo3.getShortHead()).toBe('master');
        expect(repo3.getPath()).toBe(
          fs.realpathSync(path.join(directory3, '.git'))
        );
      });

      it('calls callbacks registered with ::onDidChangePaths', () => {
        const onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy');
        atom.project.onDidChangePaths(onDidChangePathsSpy);

        const paths = [temp.mkdirSync('dir1'), temp.mkdirSync('dir2')];
        atom.project.setPaths(paths);

        expect(onDidChangePathsSpy.callCount).toBe(1);
        expect(onDidChangePathsSpy.mostRecentCall.args[0]).toEqual(paths);
      });

      it('optionally throws an error with any paths that did not exist', () => {
        const paths = [
          temp.mkdirSync('exists0'),
          '/doesnt-exists/0',
          temp.mkdirSync('exists1'),
          '/doesnt-exists/1'
        ];

        try {
          atom.project.setPaths(paths, { mustExist: true });
          expect('no exception thrown').toBeUndefined();
        } catch (e) {
          expect(e.missingProjectPaths).toEqual([paths[1], paths[3]]);
        }

        expect(atom.project.getPaths()).toEqual([paths[0], paths[2]]);
      });
    });

    describe('when no paths are given', () => {
      it('clears its path', () => {
        atom.project.setPaths([]);
        expect(atom.project.getPaths()).toEqual([]);
        expect(atom.project.getDirectories()).toEqual([]);
      });
    });

    it('normalizes the path to remove consecutive slashes, ., and .. segments', () => {
      atom.project.setPaths([
        `${require.resolve('./fixtures/dir/a')}${path.sep}b${path.sep}${
          path.sep
        }..`
      ]);
      expect(atom.project.getPaths()[0]).toEqual(
        path.dirname(require.resolve('./fixtures/dir/a'))
      );
      expect(atom.project.getDirectories()[0].path).toEqual(
        path.dirname(require.resolve('./fixtures/dir/a'))
      );
    });
  });

  describe('.addPath(path, options)', () => {
    it('calls callbacks registered with ::onDidChangePaths', () => {
      const onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy');
      atom.project.onDidChangePaths(onDidChangePathsSpy);

      const [oldPath] = atom.project.getPaths();

      const newPath = temp.mkdirSync('dir');
      atom.project.addPath(newPath);

      expect(onDidChangePathsSpy.callCount).toBe(1);
      expect(onDidChangePathsSpy.mostRecentCall.args[0]).toEqual([
        oldPath,
        newPath
      ]);
    });

    it("doesn't add redundant paths", () => {
      const onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy');
      atom.project.onDidChangePaths(onDidChangePathsSpy);
      const [oldPath] = atom.project.getPaths();

      // Doesn't re-add an existing root directory
      atom.project.addPath(oldPath);
      expect(atom.project.getPaths()).toEqual([oldPath]);
      expect(onDidChangePathsSpy).not.toHaveBeenCalled();

      // Doesn't add an entry for a file-path within an existing root directory
      atom.project.addPath(path.join(oldPath, 'some-file.txt'));
      expect(atom.project.getPaths()).toEqual([oldPath]);
      expect(onDidChangePathsSpy).not.toHaveBeenCalled();

      // Does add an entry for a directory within an existing directory
      const newPath = path.join(oldPath, 'a-dir');
      atom.project.addPath(newPath);
      expect(atom.project.getPaths()).toEqual([oldPath, newPath]);
      expect(onDidChangePathsSpy).toHaveBeenCalled();
    });

    it("doesn't add non-existent directories", () => {
      const previousPaths = atom.project.getPaths();
      atom.project.addPath('/this-definitely/does-not-exist');
      expect(atom.project.getPaths()).toEqual(previousPaths);
    });

    it('optionally throws on non-existent directories', () => {
      expect(() =>
        atom.project.addPath('/this-definitely/does-not-exist', {
          mustExist: true
        })
      ).toThrow();
    });
  });

  describe('.removePath(path)', () => {
    let onDidChangePathsSpy = null;

    beforeEach(() => {
      onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths listener');
      atom.project.onDidChangePaths(onDidChangePathsSpy);
    });

    it('removes the directory and repository for the path', () => {
      const result = atom.project.removePath(atom.project.getPaths()[0]);
      expect(atom.project.getDirectories()).toEqual([]);
      expect(atom.project.getRepositories()).toEqual([]);
      expect(atom.project.getPaths()).toEqual([]);
      expect(result).toBe(true);
      expect(onDidChangePathsSpy).toHaveBeenCalled();
    });

    it("does nothing if the path is not one of the project's root paths", () => {
      const originalPaths = atom.project.getPaths();
      const result = atom.project.removePath(originalPaths[0] + 'xyz');
      expect(result).toBe(false);
      expect(atom.project.getPaths()).toEqual(originalPaths);
      expect(onDidChangePathsSpy).not.toHaveBeenCalled();
    });

    it("doesn't destroy the repository if it is shared by another root directory", () => {
      atom.project.setPaths([__dirname, path.join(__dirname, '..', 'src')]);
      atom.project.removePath(__dirname);
      expect(atom.project.getPaths()).toEqual([
        path.join(__dirname, '..', 'src')
      ]);
      expect(atom.project.getRepositories()[0].isSubmodule('src')).toBe(false);
    });

    it('removes a path that is represented as a URI', () => {
      atom.packages.serviceHub.provide('atom.directory-provider', '0.1.0', {
        directoryForURISync(uri) {
          return {
            getPath() {
              return uri;
            },
            getSubdirectory() {
              return {};
            },
            isRoot() {
              return true;
            },
            existsSync() {
              return true;
            },
            off() {}
          };
        }
      });

      const ftpURI = 'ftp://example.com/some/folder';

      atom.project.setPaths([ftpURI]);
      expect(atom.project.getPaths()).toEqual([ftpURI]);

      atom.project.removePath(ftpURI);
      expect(atom.project.getPaths()).toEqual([]);
    });
  });

  describe('.onDidChangeFiles()', () => {
    let sub;
    let events;
    let checkCallback = () => {};

    beforeEach(() => {
      events = [];
      sub = atom.project.onDidChangeFiles(incoming => {
        events.push(...incoming);
        checkCallback();
      });
    });

    afterEach(() => sub.dispose());

    const waitForEvents = paths => {
      const remaining = new Set(paths.map(p => fs.realpathSync(p)));
      return new Promise((resolve, reject) => {
        let expireTimeoutId;
        checkCallback = () => {
          for (let event of events) {
            remaining.delete(event.path);
          }
          if (remaining.size === 0) {
            clearTimeout(expireTimeoutId);
            resolve();
          }
        };

        const expire = () => {
          checkCallback = () => {};
          console.error('Paths not seen:', remaining);
          reject(
            new Error('Expired before all expected events were delivered.')
          );
        };

        expireTimeoutId = setTimeout(expire, 2000);
        checkCallback();
      });
    };

    it('reports filesystem changes within project paths', async () => {
      jasmine.useRealClock();
      const dirOne = temp.mkdirSync('atom-spec-project-one');
      const fileOne = path.join(dirOne, 'file-one.txt');
      const fileTwo = path.join(dirOne, 'file-two.txt');
      const dirTwo = temp.mkdirSync('atom-spec-project-two');
      const fileThree = path.join(dirTwo, 'file-three.txt');

      // Ensure that all preexisting watchers are stopped
      await stopAllWatchers();

      atom.project.setPaths([dirOne]);
      await atom.project.getWatcherPromise(dirOne);

      expect(atom.project.watcherPromisesByPath[dirTwo]).toEqual(undefined);
      fs.writeFileSync(fileThree, 'three\n');
      fs.writeFileSync(fileTwo, 'two\n');
      fs.writeFileSync(fileOne, 'one\n');
      await waitForEvents([fileOne, fileTwo]);
      expect(events.some(event => event.path === fileThree)).toBeFalsy();
    });
  });

  describe('.onDidAddBuffer()', () => {
    it('invokes the callback with added text buffers', () => {
      const buffers = [];
      const added = [];

      waitsForPromise(() =>
        atom.project
          .buildBuffer(require.resolve('./fixtures/dir/a'))
          .then(o => buffers.push(o))
      );

      runs(() => {
        expect(buffers.length).toBe(1);
        atom.project.onDidAddBuffer(buffer => added.push(buffer));
      });

      waitsForPromise(() =>
        atom.project
          .buildBuffer(require.resolve('./fixtures/dir/b'))
          .then(o => buffers.push(o))
      );

      runs(() => {
        expect(buffers.length).toBe(2);
        expect(added).toEqual([buffers[1]]);
      });
    });
  });

  describe('.observeBuffers()', () => {
    it('invokes the observer with current and future text buffers', () => {
      const buffers = [];
      const observed = [];

      waitsForPromise(() =>
        atom.project
          .buildBuffer(require.resolve('./fixtures/dir/a'))
          .then(o => buffers.push(o))
      );

      waitsForPromise(() =>
        atom.project
          .buildBuffer(require.resolve('./fixtures/dir/b'))
          .then(o => buffers.push(o))
      );

      runs(() => {
        expect(buffers.length).toBe(2);
        atom.project.observeBuffers(buffer => observed.push(buffer));
        expect(observed).toEqual(buffers);
      });

      waitsForPromise(() =>
        atom.project
          .buildBuffer(require.resolve('./fixtures/dir/b'))
          .then(o => buffers.push(o))
      );

      runs(() => {
        expect(observed.length).toBe(3);
        expect(buffers.length).toBe(3);
        expect(observed).toEqual(buffers);
      });
    });
  });

  describe('.observeRepositories()', () => {
    it('invokes the observer with current and future repositories', () => {
      const observed = [];

      const directory1 = temp.mkdirSync('git-repo1');
      const gitDirPath1 = fs.absolute(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
      fs.copySync(gitDirPath1, path.join(directory1, '.git'));

      const directory2 = temp.mkdirSync('git-repo2');
      const gitDirPath2 = fs.absolute(
        path.join(
          __dirname,
          'fixtures',
          'git',
          'repo-with-submodules',
          'git.git'
        )
      );
      fs.copySync(gitDirPath2, path.join(directory2, '.git'));

      atom.project.setPaths([directory1]);

      const disposable = atom.project.observeRepositories(repo =>
        observed.push(repo)
      );
      expect(observed.length).toBe(1);
      expect(observed[0].getReferenceTarget('refs/heads/master')).toBe(
        'ef046e9eecaa5255ea5e9817132d4001724d6ae1'
      );

      atom.project.addPath(directory2);
      expect(observed.length).toBe(2);
      expect(observed[1].getReferenceTarget('refs/heads/master')).toBe(
        'd2b0ad9cbc6f6c4372e8956e5cc5af771b2342e5'
      );

      disposable.dispose();
    });
  });

  describe('.onDidAddRepository()', () => {
    it('invokes callback when a path is added and the path is the root of a repository', () => {
      const observed = [];
      const disposable = atom.project.onDidAddRepository(repo =>
        observed.push(repo)
      );

      const projectRootPath = temp.mkdirSync();
      const fixtureRepoPath = fs.absolute(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
      fs.copySync(fixtureRepoPath, path.join(projectRootPath, '.git'));

      atom.project.addPath(projectRootPath);
      expect(observed.length).toBe(1);
      expect(observed[0].getOriginURL()).toEqual(
        'https://github.com/example-user/example-repo.git'
      );

      disposable.dispose();
    });

    it('invokes callback when a path is added and the path is subdirectory of a repository', () => {
      const observed = [];
      const disposable = atom.project.onDidAddRepository(repo =>
        observed.push(repo)
      );

      const projectRootPath = temp.mkdirSync();
      const fixtureRepoPath = fs.absolute(
        path.join(__dirname, 'fixtures', 'git', 'master.git')
      );
      fs.copySync(fixtureRepoPath, path.join(projectRootPath, '.git'));

      const projectSubDirPath = path.join(projectRootPath, 'sub-dir');
      fs.mkdirSync(projectSubDirPath);

      atom.project.addPath(projectSubDirPath);
      expect(observed.length).toBe(1);
      expect(observed[0].getOriginURL()).toEqual(
        'https://github.com/example-user/example-repo.git'
      );

      disposable.dispose();
    });

    it('does not invoke callback when a path is added and the path is not part of a repository', () => {
      const observed = [];
      const disposable = atom.project.onDidAddRepository(repo =>
        observed.push(repo)
      );

      atom.project.addPath(temp.mkdirSync('not-a-repository'));
      expect(observed.length).toBe(0);

      disposable.dispose();
    });
  });

  describe('.relativize(path)', () => {
    it('returns the path, relative to whichever root directory it is inside of', () => {
      atom.project.addPath(temp.mkdirSync('another-path'));

      let rootPath = atom.project.getPaths()[0];
      let childPath = path.join(rootPath, 'some', 'child', 'directory');
      expect(atom.project.relativize(childPath)).toBe(
        path.join('some', 'child', 'directory')
      );

      rootPath = atom.project.getPaths()[1];
      childPath = path.join(rootPath, 'some', 'child', 'directory');
      expect(atom.project.relativize(childPath)).toBe(
        path.join('some', 'child', 'directory')
      );
    });

    it('returns the given path if it is not in any of the root directories', () => {
      const randomPath = path.join('some', 'random', 'path');
      expect(atom.project.relativize(randomPath)).toBe(randomPath);
    });
  });

  describe('.relativizePath(path)', () => {
    it('returns the root path that contains the given path, and the path relativized to that root path', () => {
      atom.project.addPath(temp.mkdirSync('another-path'));

      let rootPath = atom.project.getPaths()[0];
      let childPath = path.join(rootPath, 'some', 'child', 'directory');
      expect(atom.project.relativizePath(childPath)).toEqual([
        rootPath,
        path.join('some', 'child', 'directory')
      ]);

      rootPath = atom.project.getPaths()[1];
      childPath = path.join(rootPath, 'some', 'child', 'directory');
      expect(atom.project.relativizePath(childPath)).toEqual([
        rootPath,
        path.join('some', 'child', 'directory')
      ]);
    });

    describe("when the given path isn't inside of any of the project's path", () => {
      it('returns null for the root path, and the given path unchanged', () => {
        const randomPath = path.join('some', 'random', 'path');
        expect(atom.project.relativizePath(randomPath)).toEqual([
          null,
          randomPath
        ]);
      });
    });

    describe('when the given path is a URL', () => {
      it('returns null for the root path, and the given path unchanged', () => {
        const url = 'http://the-path';
        expect(atom.project.relativizePath(url)).toEqual([null, url]);
      });
    });

    describe('when the given path is inside more than one root folder', () => {
      it('uses the root folder that is closest to the given path', () => {
        atom.project.addPath(path.join(atom.project.getPaths()[0], 'a-dir'));

        const inputPath = path.join(
          atom.project.getPaths()[1],
          'somewhere/something.txt'
        );

        expect(atom.project.getDirectories()[0].contains(inputPath)).toBe(true);
        expect(atom.project.getDirectories()[1].contains(inputPath)).toBe(true);
        expect(atom.project.relativizePath(inputPath)).toEqual([
          atom.project.getPaths()[1],
          path.join('somewhere', 'something.txt')
        ]);
      });
    });
  });

  describe('.contains(path)', () => {
    it('returns whether or not the given path is in one of the root directories', () => {
      const rootPath = atom.project.getPaths()[0];
      const childPath = path.join(rootPath, 'some', 'child', 'directory');
      expect(atom.project.contains(childPath)).toBe(true);

      const randomPath = path.join('some', 'random', 'path');
      expect(atom.project.contains(randomPath)).toBe(false);
    });
  });

  describe('.resolvePath(uri)', () => {
    it('normalizes disk drive letter in passed path on #win32', () => {
      expect(atom.project.resolvePath('d:\\file.txt')).toEqual('D:\\file.txt');
    });
  });
});
