'use babel'

import fs from 'fs-plus'
import path from 'path'
import temp from 'temp'

import {it, beforeEach, afterEach} from './async-spec-helpers'

import GitRepositoryAsync from '../src/git-repository-async'
import Project from '../src/project'

temp.track()

function openFixture (fixture) {
  return GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
}

function copyRepository (name = 'working-dir') {
  const workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', name), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  return fs.realpathSync(workingDirPath)
}

function copySubmoduleRepository () {
  const workingDirectory = copyRepository('repo-with-submodules')
  const reGit = (name) => {
    fs.renameSync(path.join(workingDirectory, name, 'git.git'), path.join(workingDirectory, name, '.git'))
  }
  reGit('jstips')
  reGit('You-Dont-Need-jQuery')

  return workingDirectory
}

fdescribe('GitRepositoryAsync', () => {
  let repo

  afterEach(() => {
    if (repo != null) repo.destroy()
  })

  describe('@open(path)', () => {
    it('should throw when no repository is found', async () => {
      repo = GitRepositoryAsync.open(path.join(temp.dir, 'nogit.txt'))

      let threw = false
      try {
        await repo.getRepo()
      } catch (e) {
        threw = true
      }

      expect(threw).toBe(true)
    })
  })

  describe('openedPath', () => {
    it('is the path passed to .open', () => {
      const workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      expect(repo.openedPath).toBe(workingDirPath)
    })
  })

  describe('.getRepo()', () => {
    beforeEach(() => {
      const workingDirectory = copySubmoduleRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      waitsForPromise(() => repo.refreshStatus())
    })

    it('returns the repository when not given a path', async () => {
      const nodeGitRepo1 = await repo.getRepo()
      const nodeGitRepo2 = await repo.getRepo()
      expect(nodeGitRepo1.workdir()).toBe(nodeGitRepo2.workdir())
    })

    it('returns the repository when given a non-submodule path', async () => {
      const nodeGitRepo1 = await repo.getRepo()
      const nodeGitRepo2 = await repo.getRepo('README')
      expect(nodeGitRepo1.workdir()).toBe(nodeGitRepo2.workdir())
    })

    it('returns the submodule repository when given a submodule path', async () => {
      const nodeGitRepo1 = await repo.getRepo()
      const nodeGitRepo2 = await repo.getRepo('jstips')
      expect(nodeGitRepo1.workdir()).not.toBe(nodeGitRepo2.workdir())

      const nodeGitRepo3 = await repo.getRepo('jstips/README.md')
      expect(nodeGitRepo1.workdir()).not.toBe(nodeGitRepo3.workdir())
      expect(nodeGitRepo2.workdir()).toBe(nodeGitRepo3.workdir())
    })
  })

  describe('.openRepository()', () => {
    it('returns a new repository instance', async () => {
      repo = openFixture('master.git')

      const originalRepo = await repo.getRepo()
      expect(originalRepo).not.toBeNull()

      const nodeGitRepo = repo.openRepository()
      expect(nodeGitRepo).not.toBeNull()
      expect(originalRepo).not.toBe(nodeGitRepo)
    })
  })

  describe('.getPath()', () => {
    it('returns the repository path for a repository path', async () => {
      repo = openFixture('master.git')
      const repoPath = await repo.getPath()
      expect(repoPath).toEqualPath(path.join(__dirname, 'fixtures', 'git', 'master.git'))
    })
  })

  describe('.isPathIgnored(path)', () => {
    beforeEach(() => {
      repo = openFixture('ignore.git')
    })

    it('resolves true for an ignored path', async () => {
      const ignored = await repo.isPathIgnored('a.txt')
      expect(ignored).toBe(true)
    })

    it('resolves false for a non-ignored path', async () => {
      const ignored = await repo.isPathIgnored('b.txt')
      expect(ignored).toBe(false)
    })
  })

  describe('.isPathModified(path)', () => {
    let filePath, newPath, emptyPath

    beforeEach(() => {
      const workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
      emptyPath = path.join(workingDirPath, 'empty-path.txt')
    })

    describe('when the path is unstaged', () => {
      it('resolves false if the path has not been modified', async () => {
        const modified = await repo.isPathModified(filePath)
        expect(modified).toBe(false)
      })

      it('resolves true if the path is modified', async () => {
        fs.writeFileSync(filePath, 'change')
        const modified = await repo.isPathModified(filePath)
        expect(modified).toBe(true)
      })

      it('resolves false if the path is new', async () => {
        const modified = await repo.isPathModified(newPath)
        expect(modified).toBe(false)
      })

      it('resolves false if the path is invalid', async () => {
        const modified = await repo.isPathModified(emptyPath)
        expect(modified).toBe(false)
      })
    })
  })

  describe('.isPathNew(path)', () => {
    let newPath

    beforeEach(() => {
      const workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
    })

    describe('when the path is unstaged', () => {
      it('returns true if the path is new', async () => {
        const isNew = await repo.isPathNew(newPath)
        expect(isNew).toBe(true)
      })

      it("returns false if the path isn't new", async () => {
        const modified = await repo.isPathModified(newPath)
        expect(modified).toBe(false)
      })
    })
  })

  describe('.checkoutHead(path)', () => {
    let filePath

    beforeEach(() => {
      const workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
    })

    it('no longer reports a path as modified after checkout', async () => {
      let modified = await repo.isPathModified(filePath)
      expect(modified).toBe(false)

      fs.writeFileSync(filePath, 'ch ch changes')

      modified = await repo.isPathModified(filePath)
      expect(modified).toBe(true)

      await repo.checkoutHead(filePath)

      modified = await repo.isPathModified(filePath)
      expect(modified).toBe(false)
    })

    it('restores the contents of the path to the original text', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')
      await repo.checkoutHead(filePath)
      expect(fs.readFileSync(filePath, 'utf8')).toBe('')
    })

    it('fires a did-change-status event if the checkout completes successfully', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')

      await repo.getPathStatus(filePath)

      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)

      await repo.checkoutHead(filePath)

      expect(statusHandler.callCount).toBe(1)
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: 0})

      await repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  describe('.checkoutHeadForEditor(editor)', () => {
    let filePath
    let editor

    beforeEach(async () => {
      spyOn(atom, 'confirm')

      const workingDirPath = copyRepository()
      repo = new GitRepositoryAsync(workingDirPath, {project: atom.project, config: atom.config, confirm: atom.confirm})
      filePath = path.join(workingDirPath, 'a.txt')
      fs.writeFileSync(filePath, 'ch ch changes')

      editor = await atom.workspace.open(filePath)
    })

    it('displays a confirmation dialog by default', async () => {
      atom.confirm.andCallFake(({buttons}) => buttons.OK())
      atom.config.set('editor.confirmCheckoutHeadRevision', true)

      await repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe('')
    })

    it('does not display a dialog when confirmation is disabled', async () => {
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      await repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe('')
      expect(atom.confirm).not.toHaveBeenCalled()
    })
  })

  describe('.destroy()', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('throws an exception when any method is called after it is called', async () => {
      repo.destroy()

      let error = null
      try {
        await repo.getShortHead()
      } catch (e) {
        error = e
      }

      expect(error.name).toBe(GitRepositoryAsync.DestroyedErrorName)

      repo = null
    })
  })

  describe('.getPathStatus(path)', () => {
    let filePath

    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      filePath = path.join(workingDirectory, 'file.txt')
    })

    it('trigger a status-changed event when the new status differs from the last cached one', async () => {
      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)
      fs.writeFileSync(filePath, '')

      await repo.getPathStatus(filePath)

      expect(statusHandler.callCount).toBe(1)
      const status = GitRepositoryAsync.Git.Status.STATUS.WT_MODIFIED
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: status})
      fs.writeFileSync(filePath, 'abc')

      await repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  describe('.getDirectoryStatus(path)', () => {
    let directoryPath, filePath

    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      directoryPath = path.join(workingDirectory, 'dir')
      filePath = path.join(directoryPath, 'b.txt')
    })

    it('gets the status based on the files inside the directory', async () => {
      await repo.checkoutHead(filePath)

      let result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(false)

      fs.writeFileSync(filePath, 'abc')

      result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(true)
    })
  })

  describe('.refreshStatus()', () => {
    let newPath, modifiedPath, cleanPath, workingDirectory

    beforeEach(() => {
      workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      modifiedPath = path.join(workingDirectory, 'file.txt')
      newPath = path.join(workingDirectory, 'untracked.txt')
      cleanPath = path.join(workingDirectory, 'other.txt')
      fs.writeFileSync(cleanPath, 'Full of text')
      fs.writeFileSync(newPath, '')
      fs.writeFileSync(modifiedPath, 'making this path modified')
      newPath = fs.absolute(newPath) // specs could be running under symbol path.
    })

    it('returns status information for all new and modified files', async () => {
      await repo.refreshStatus()

      expect(await repo.getCachedPathStatus(cleanPath)).toBeUndefined()
      expect(repo.isStatusNew(await repo.getCachedPathStatus(newPath))).toBe(true)
      expect(repo.isStatusModified(await repo.getCachedPathStatus(modifiedPath))).toBe(true)
    })

    describe('in a repository with submodules', () => {
      beforeEach(() => {
        workingDirectory = copySubmoduleRepository()
        repo = GitRepositoryAsync.open(workingDirectory)
        modifiedPath = path.join(workingDirectory, 'jstips', 'README.md')
        newPath = path.join(workingDirectory, 'You-Dont-Need-jQuery', 'untracked.txt')
        cleanPath = path.join(workingDirectory, 'jstips', 'CONTRIBUTING.md')
        fs.writeFileSync(newPath, '')
        fs.writeFileSync(modifiedPath, 'making this path modified')
        newPath = fs.absolute(newPath) // specs could be running under symbol path.
      })

      it('returns status information for all new and modified files', async () => {
        await repo.refreshStatus()

        expect(await repo.getCachedPathStatus(cleanPath)).toBeUndefined()
        expect(repo.isStatusNew(await repo.getCachedPathStatus(newPath))).toBe(true)
        expect(repo.isStatusModified(await repo.getCachedPathStatus(modifiedPath))).toBe(true)
      })
    })

    it('caches the proper statuses when a subdir is open', async () => {
      const subDir = path.join(workingDirectory, 'dir')
      fs.mkdirSync(subDir)

      const filePath = path.join(subDir, 'b.txt')
      fs.writeFileSync(filePath, '')

      atom.project.setPaths([subDir])

      await atom.workspace.open('b.txt')

      const repo = atom.project.getRepositories()[0].async

      await repo.refreshStatus()

      const status = await repo.getCachedPathStatus(filePath)
      expect(repo.isStatusModified(status)).toBe(false)
      expect(repo.isStatusNew(status)).toBe(false)
    })

    it('caches the proper statuses when multiple project are open', async () => {
      const otherWorkingDirectory = copyRepository()

      atom.project.setPaths([workingDirectory, otherWorkingDirectory])

      await atom.workspace.open('b.txt')

      const repo = atom.project.getRepositories()[0].async

      await repo.refreshStatus()

      const subDir = path.join(workingDirectory, 'dir')
      fs.mkdirSync(subDir)

      const filePath = path.join(subDir, 'b.txt')
      fs.writeFileSync(filePath, 'some content!')

      const status = await repo.getCachedPathStatus(filePath)
      expect(repo.isStatusModified(status)).toBe(true)
      expect(repo.isStatusNew(status)).toBe(false)
    })

    it('emits did-change-statuses if the status changes', async () => {
      const someNewPath = path.join(workingDirectory, 'MyNewJSFramework.md')
      fs.writeFileSync(someNewPath, '')

      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatuses(statusHandler)

      await repo.refreshStatus()

      waitsFor('the onDidChangeStatuses handler to be called', () => statusHandler.callCount > 0)
    })

    it('emits did-change-statuses if the branch changes', async () => {
      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatuses(statusHandler)

      repo._refreshBranch = jasmine.createSpy('_refreshBranch').andCallFake(() => {
        return Promise.resolve(true)
      })

      await repo.refreshStatus()

      waitsFor('the onDidChangeStatuses handler to be called', () => statusHandler.callCount > 0)
    })

    it('emits did-change-statuses if the ahead/behind changes', async () => {
      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatuses(statusHandler)

      repo._refreshAheadBehindCount = jasmine.createSpy('_refreshAheadBehindCount').andCallFake(() => {
        return Promise.resolve(true)
      })

      await repo.refreshStatus()

      waitsFor('the onDidChangeStatuses handler to be called', () => statusHandler.callCount > 0)
    })
  })

  describe('.isProjectAtRoot()', () => {
    it('returns true when the repository is at the root', async () => {
      const workingDirectory = copyRepository()
      atom.project.setPaths([workingDirectory])
      const repo = atom.project.getRepositories()[0].async

      const atRoot = await repo.isProjectAtRoot()
      expect(atRoot).toBe(true)
    })

    it("returns false when the repository wasn't created with a project", async () => {
      const workingDirectory = copyRepository()
      const repo = GitRepositoryAsync.open(workingDirectory)

      const atRoot = await repo.isProjectAtRoot()
      expect(atRoot).toBe(false)
    })
  })

  describe('buffer events', () => {
    let repo

    beforeEach(() => {
      const workingDirectory = copyRepository()
      atom.project.setPaths([workingDirectory])

      // When the path is added to the project, the repository is refreshed. We
      // need to wait for that to complete before the tests continue so that
      // we're in a known state.
      repo = atom.project.getRepositories()[0].async
      waitsForPromise(() => repo.refreshStatus())
    })

    it('emits a status-changed event when a buffer is saved', async () => {
      const editor = await atom.workspace.open('other.txt')

      editor.insertNewline()

      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)
      editor.save()

      waitsFor('the onDidChangeStatus handler to be called', () => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBeGreaterThan(0)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})
      })
    })

    it('emits a status-changed event when a buffer is reloaded', async () => {
      const editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)
      editor.getBuffer().reload()

      waitsFor('the onDidChangeStatus handler to be called', () => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBeGreaterThan(0)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})
      })
    })

    it("emits a status-changed event when a buffer's path changes", async () => {
      const editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      const statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)
      editor.getBuffer().emitter.emit('did-change-path')

      waitsFor('the onDidChangeStatus handler to be called', () => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBeGreaterThan(0)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

        const pathHandler = jasmine.createSpy('pathHandler')
        const buffer = editor.getBuffer()
        buffer.onDidChangePath(pathHandler)
        buffer.emitter.emit('did-change-path')

        waitsFor('the onDidChangePath handler to be called', () => pathHandler.callCount > 0)
        runs(() => expect(pathHandler.callCount).toBeGreaterThan(0))
      })
    })

    it('stops listening to the buffer when the repository is destroyed (regression)', async () => {
      const editor = await atom.workspace.open('other.txt')
      const repo = atom.project.getRepositories()[0]
      repo.destroy()
      expect(() => editor.save()).not.toThrow()
    })
  })

  describe('when a project is deserialized', () => {
    let project2

    beforeEach(() => {
      atom.project.setPaths([copyRepository()])

      // See the comment in the 'buffer events' beforeEach for why we need to do
      // this.
      const repository = atom.project.getRepositories()[0].async
      waitsForPromise(() => repository.refreshStatus())
    })

    afterEach(() => {
      if (project2) project2.destroy()
    })

    it('subscribes to all the serialized buffers in the project', async () => {
      await atom.workspace.open('file.txt')

      project2 = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm, applicationDelegate: atom.applicationDelegate})
      project2.deserialize(atom.project.serialize({isUnloading: true}))

      const repo = project2.getRepositories()[0].async
      waitsForPromise(() => repo.refreshStatus())
      runs(() => {
        const buffer = project2.getBuffers()[0]

        waitsFor(() => buffer.loaded)
        runs(() => {
          buffer.append('changes')

          const statusHandler = jasmine.createSpy('statusHandler')
          repo.onDidChangeStatus(statusHandler)
          buffer.save()

          waitsFor(() => statusHandler.callCount > 0)
          runs(() => {
            expect(statusHandler.callCount).toBeGreaterThan(0)
            expect(statusHandler).toHaveBeenCalledWith({path: buffer.getPath(), pathStatus: 256})
          })
        })
      })
    })
  })

  describe('GitRepositoryAsync::relativize(filePath, workdir)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    // This is a change in implementation from the git-utils version
    it('just returns path if workdir is not provided', () => {
      const _path = '/foo/bar/baz.txt'
      const relPath = repo.relativize(_path)
      expect(_path).toEqual(relPath)
    })

    it('relativizes a repo path', () => {
      const workdir = '/tmp/foo/bar/baz/'
      const relativizedPath = repo.relativize(`${workdir}a/b.txt`, workdir)
      expect(relativizedPath).toBe('a/b.txt')
    })

    it("doesn't require workdir to end in a slash", () => {
      const workdir = '/tmp/foo/bar/baz'
      const relativizedPath = repo.relativize(`${workdir}/a/b.txt`, workdir)
      expect(relativizedPath).toBe('a/b.txt')
    })

    it('preserves file case', () => {
      repo.isCaseInsensitive = true

      const workdir = '/tmp/foo/bar/baz/'
      const relativizedPath = repo.relativize(`${workdir}a/README.txt`, workdir)
      expect(relativizedPath).toBe('a/README.txt')
    })
  })

  describe('.getShortHead(path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the human-readable branch name', async () => {
      const head = await repo.getShortHead()
      expect(head).toBe('master')
    })

    describe('in a submodule', () => {
      beforeEach(() => {
        const workingDirectory = copySubmoduleRepository()
        repo = GitRepositoryAsync.open(workingDirectory)
      })

      it('returns the human-readable branch name', async () => {
        await repo.refreshStatus()

        const head = await repo.getShortHead('jstips')
        expect(head).toBe('test')
      })
    })
  })

  describe('.isSubmodule(path)', () => {
    beforeEach(() => {
      const workingDirectory = copySubmoduleRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it("returns false for a path that isn't a submodule", async () => {
      const isSubmodule = await repo.isSubmodule('README')
      expect(isSubmodule).toBe(false)
    })

    it('returns true for a path that is a submodule', async () => {
      const isSubmodule = await repo.isSubmodule('jstips')
      expect(isSubmodule).toBe(true)
    })
  })

  describe('.getAheadBehindCount(reference, path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns 0, 0 for a branch with no upstream', async () => {
      const {ahead, behind} = await repo.getAheadBehindCount('master')
      expect(ahead).toBe(0)
      expect(behind).toBe(0)
    })
  })

  describe('.getCachedUpstreamAheadBehindCount(path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns 0, 0 for a branch with no upstream', async () => {
      await repo.refreshStatus()

      const {ahead, behind} = await repo.getCachedUpstreamAheadBehindCount()
      expect(ahead).toBe(0)
      expect(behind).toBe(0)
    })

    describe('in a submodule', () => {
      beforeEach(() => {
        const workingDirectory = copySubmoduleRepository()
        repo = GitRepositoryAsync.open(workingDirectory)
      })

      it('returns 1, 0 for a branch which is ahead by 1', async () => {
        await repo.refreshStatus()

        const {ahead, behind} = await repo.getCachedUpstreamAheadBehindCount('You-Dont-Need-jQuery')
        expect(ahead).toBe(1)
        expect(behind).toBe(0)
      })
    })
  })

  describe('.getDiffStats(path)', () => {
    let workingDirectory
    beforeEach(() => {
      workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the diff stat', async () => {
      const filePath = path.join(workingDirectory, 'a.txt')
      fs.writeFileSync(filePath, 'change')

      const {added, deleted} = await repo.getDiffStats('a.txt')
      expect(added).toBe(1)
      expect(deleted).toBe(0)
    })
  })

  describe('.hasBranch(branch)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('resolves true when the branch exists', async () => {
      const hasBranch = await repo.hasBranch('master')
      expect(hasBranch).toBe(true)
    })

    it("resolves false when the branch doesn't exist", async () => {
      const hasBranch = await repo.hasBranch('trolleybus')
      expect(hasBranch).toBe(false)
    })
  })

  describe('.getReferences(path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the heads, remotes, and tags', async () => {
      const {heads, remotes, tags} = await repo.getReferences()
      expect(heads.length).toBe(1)
      expect(remotes.length).toBe(0)
      expect(tags.length).toBe(0)
    })
  })

  describe('.getReferenceTarget(reference, path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the SHA target', async () => {
      const SHA = await repo.getReferenceTarget('refs/heads/master')
      expect(SHA).toBe('8a9c86f1cb1f14b8f436eb91f4b052c8802ca99e')
    })
  })

  describe('.getConfigValue(key, path)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('looks up the value for the key', async () => {
      const bare = await repo.getConfigValue('core.bare')
      expect(bare).toBe('false')
    })

    it("resolves to null if there's no value", async () => {
      const value = await repo.getConfigValue('my.special.key')
      expect(value).toBeNull()
    })
  })

  describe('.checkoutReference(reference, create)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('can create new branches', () => {
      let success = false
      let threw = false
      waitsForPromise(() => repo.checkoutReference('my-b', true)
        .then(_ => success = true)
        .catch(_ => threw = true))
      runs(() => {
        expect(success).toBe(true)
        expect(threw).toBe(false)
      })
    })
  })

  describe('.getLineDiffs(path, text)', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the old and new lines of the diff', async () => {
      const [{oldStart, newStart, oldLines, newLines}] = await repo.getLineDiffs('a.txt', 'hi there')
      expect(oldStart).toBe(0)
      expect(oldLines).toBe(0)
      expect(newStart).toBe(1)
      expect(newLines).toBe(1)
    })
  })

  describe('GitRepositoryAsync::relativizeToWorkingDirectory(_path)', () => {
    let workingDirectory

    beforeEach(() => {
      workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('relativizes the given path to the working directory of the repository', async () => {
      let absolutePath = path.join(workingDirectory, 'a.txt')
      expect(await repo.relativizeToWorkingDirectory(absolutePath)).toBe('a.txt')
      absolutePath = path.join(workingDirectory, 'a/b/c.txt')
      expect(await repo.relativizeToWorkingDirectory(absolutePath)).toBe('a/b/c.txt')
      expect(await repo.relativizeToWorkingDirectory('a.txt')).toBe('a.txt')
      expect(await repo.relativizeToWorkingDirectory('/not/in/workdir')).toBe('/not/in/workdir')
      expect(await repo.relativizeToWorkingDirectory(null)).toBe(null)
      expect(await repo.relativizeToWorkingDirectory()).toBe(undefined)
      expect(await repo.relativizeToWorkingDirectory('')).toBe('')
      expect(await repo.relativizeToWorkingDirectory(workingDirectory)).toBe('')
    })

    describe('when the opened path is a symlink', () => {
      it('relativizes against both the linked path and real path', async () => {
        // Symlinks require admin privs on windows so we just skip this there,
        // done in git-utils as well
        if (process.platform === 'win32') {
          return
        }

        const linkDirectory = path.join(temp.mkdirSync('atom-working-dir-symlink'), 'link')
        fs.symlinkSync(workingDirectory, linkDirectory)
        const linkedRepo = GitRepositoryAsync.open(linkDirectory)
        expect(await linkedRepo.relativizeToWorkingDirectory(path.join(workingDirectory, 'test1'))).toBe('test1')
        expect(await linkedRepo.relativizeToWorkingDirectory(path.join(linkDirectory, 'test2'))).toBe('test2')
        expect(await linkedRepo.relativizeToWorkingDirectory(path.join(linkDirectory, 'test2/test3'))).toBe('test2/test3')
        expect(await linkedRepo.relativizeToWorkingDirectory('test2/test3')).toBe('test2/test3')
      })

      it('handles case insensitive filesystems', async () => {
        repo.isCaseInsensitive = true
        expect(await repo.relativizeToWorkingDirectory(path.join(workingDirectory.toUpperCase(), 'a.txt'))).toBe('a.txt')
        expect(await repo.relativizeToWorkingDirectory(path.join(workingDirectory.toUpperCase(), 'a/b/c.txt'))).toBe('a/b/c.txt')
      })
    })
  })

  describe('.getOriginURL()', () => {
    beforeEach(() => {
      const workingDirectory = copyRepository('repo-with-submodules')
      repo = GitRepositoryAsync.open(workingDirectory)
    })

    it('returns the origin URL', async () => {
      const url = await repo.getOriginURL()
      expect(url).toBe('git@github.com:atom/some-repo-i-guess.git')
    })
  })

  describe('.getUpstreamBranch()', () => {
    it('returns null when there is no upstream branch', async () => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)

      const upstream = await repo.getUpstreamBranch()
      expect(upstream).toBe(null)
    })

    it('returns the upstream branch', async () => {
      const workingDirectory = copyRepository('repo-with-submodules')
      repo = GitRepositoryAsync.open(workingDirectory)

      const upstream = await repo.getUpstreamBranch()
      expect(upstream).toBe('refs/remotes/origin/master')
    })
  })
})
