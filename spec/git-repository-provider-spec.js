const path = require('path');
const fs = require('fs-plus');
const temp = require('temp').track();
const { Directory } = require('pathwatcher');
const GitRepository = require('../src/git-repository');
const GitRepositoryProvider = require('../src/git-repository-provider');

describe('GitRepositoryProvider', () => {
  let provider;

  beforeEach(() => {
    provider = new GitRepositoryProvider(
      atom.project,
      atom.config,
      atom.confirm
    );
  });

  afterEach(() => {
    if (provider) {
      Object.keys(provider.pathToRepository).forEach(key => {
        provider.pathToRepository[key].destroy();
      });
    }
  });

  describe('.repositoryForDirectory(directory)', () => {
    describe('when specified a Directory with a Git repository', () => {
      it('resolves with a GitRepository', async () => {
        const directory = new Directory(
          path.join(__dirname, 'fixtures', 'git', 'master.git')
        );
        const result = await provider.repositoryForDirectory(directory);
        expect(result).toBeInstanceOf(GitRepository);
        expect(provider.pathToRepository[result.getPath()]).toBeTruthy();
        expect(result.getType()).toBe('git');

        // Refresh should be started
        await new Promise(resolve => result.onDidChangeStatuses(resolve));
      });

      it('resolves with the same GitRepository for different Directory objects in the same repo', async () => {
        const firstRepo = await provider.repositoryForDirectory(
          new Directory(path.join(__dirname, 'fixtures', 'git', 'master.git'))
        );
        const secondRepo = await provider.repositoryForDirectory(
          new Directory(
            path.join(__dirname, 'fixtures', 'git', 'master.git', 'objects')
          )
        );

        expect(firstRepo).toBeInstanceOf(GitRepository);
        expect(firstRepo).toBe(secondRepo);
      });
    });

    describe('when specified a Directory without a Git repository', () => {
      it('resolves with null', async () => {
        const directory = new Directory(temp.mkdirSync('dir'));
        const repo = await provider.repositoryForDirectory(directory);
        expect(repo).toBe(null);
      });
    });

    describe('when specified a Directory with an invalid Git repository', () => {
      it('resolves with null', async () => {
        const dirPath = temp.mkdirSync('dir');
        fs.writeFileSync(path.join(dirPath, '.git', 'objects'), '');
        fs.writeFileSync(path.join(dirPath, '.git', 'HEAD'), '');
        fs.writeFileSync(path.join(dirPath, '.git', 'refs'), '');

        const directory = new Directory(dirPath);
        const repo = await provider.repositoryForDirectory(directory);
        expect(repo).toBe(null);
      });
    });

    describe('when specified a Directory with a valid gitfile-linked repository', () => {
      it('returns a Promise that resolves to a GitRepository', async () => {
        const gitDirPath = path.join(
          __dirname,
          'fixtures',
          'git',
          'master.git'
        );
        const workDirPath = temp.mkdirSync('git-workdir');
        fs.writeFileSync(
          path.join(workDirPath, '.git'),
          `gitdir: ${gitDirPath}\n`
        );

        const directory = new Directory(workDirPath);
        const result = await provider.repositoryForDirectory(directory);
        expect(result).toBeInstanceOf(GitRepository);
        expect(provider.pathToRepository[result.getPath()]).toBeTruthy();
        expect(result.getType()).toBe('git');
      });
    });

    describe('when specified a Directory without exists()', () => {
      let directory;

      beforeEach(() => {
        // An implementation of Directory that does not implement existsSync().
        const subdirectory = {};
        directory = {
          getSubdirectory() {},
          isRoot() {
            return true;
          }
        };
        spyOn(directory, 'getSubdirectory').andReturn(subdirectory);
      });

      it('returns a Promise that resolves to null', async () => {
        const repo = await provider.repositoryForDirectory(directory);
        expect(repo).toBe(null);
        expect(directory.getSubdirectory).toHaveBeenCalledWith('.git');
      });
    });
  });

  describe('.repositoryForDirectorySync(directory)', () => {
    describe('when specified a Directory with a Git repository', () => {
      it('resolves with a GitRepository', async () => {
        const directory = new Directory(
          path.join(__dirname, 'fixtures', 'git', 'master.git')
        );
        const result = provider.repositoryForDirectorySync(directory);
        expect(result).toBeInstanceOf(GitRepository);
        expect(provider.pathToRepository[result.getPath()]).toBeTruthy();
        expect(result.getType()).toBe('git');

        // Refresh should be started
        await new Promise(resolve => result.onDidChangeStatuses(resolve));
      });

      it('resolves with the same GitRepository for different Directory objects in the same repo', () => {
        const firstRepo = provider.repositoryForDirectorySync(
          new Directory(path.join(__dirname, 'fixtures', 'git', 'master.git'))
        );
        const secondRepo = provider.repositoryForDirectorySync(
          new Directory(
            path.join(__dirname, 'fixtures', 'git', 'master.git', 'objects')
          )
        );

        expect(firstRepo).toBeInstanceOf(GitRepository);
        expect(firstRepo).toBe(secondRepo);
      });
    });

    describe('when specified a Directory without a Git repository', () => {
      it('resolves with null', () => {
        const directory = new Directory(temp.mkdirSync('dir'));
        const repo = provider.repositoryForDirectorySync(directory);
        expect(repo).toBe(null);
      });
    });

    describe('when specified a Directory with an invalid Git repository', () => {
      it('resolves with null', () => {
        const dirPath = temp.mkdirSync('dir');
        fs.writeFileSync(path.join(dirPath, '.git', 'objects'), '');
        fs.writeFileSync(path.join(dirPath, '.git', 'HEAD'), '');
        fs.writeFileSync(path.join(dirPath, '.git', 'refs'), '');

        const directory = new Directory(dirPath);
        const repo = provider.repositoryForDirectorySync(directory);
        expect(repo).toBe(null);
      });
    });

    describe('when specified a Directory with a valid gitfile-linked repository', () => {
      it('returns a Promise that resolves to a GitRepository', () => {
        const gitDirPath = path.join(
          __dirname,
          'fixtures',
          'git',
          'master.git'
        );
        const workDirPath = temp.mkdirSync('git-workdir');
        fs.writeFileSync(
          path.join(workDirPath, '.git'),
          `gitdir: ${gitDirPath}\n`
        );

        const directory = new Directory(workDirPath);
        const result = provider.repositoryForDirectorySync(directory);
        expect(result).toBeInstanceOf(GitRepository);
        expect(provider.pathToRepository[result.getPath()]).toBeTruthy();
        expect(result.getType()).toBe('git');
      });
    });

    describe('when specified a Directory without existsSync()', () => {
      let directory;

      beforeEach(() => {
        // An implementation of Directory that does not implement existsSync().
        const subdirectory = {};
        directory = {
          getSubdirectory() {},
          isRoot() {
            return true;
          }
        };
        spyOn(directory, 'getSubdirectory').andReturn(subdirectory);
      });

      it('returns null', () => {
        const repo = provider.repositoryForDirectorySync(directory);
        expect(repo).toBe(null);
        expect(directory.getSubdirectory).toHaveBeenCalledWith('.git');
      });
    });
  });
});
