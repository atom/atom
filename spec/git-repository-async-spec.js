'use babel'

import fs from 'fs-plus'
import path from 'path'
import temp from 'temp'
import Git from 'nodegit'

import {it, beforeEach, afterEach} from './async-spec-helpers'

import GitRepositoryAsync from '../src/git-repository-async'
import Project from '../src/project'

temp.track()

function openFixture (fixture) {
  return GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
}

function copyRepository () {
  let workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  return fs.realpathSync(workingDirPath)
}

describe('GitRepositoryAsync', () => {
  let repo

  afterEach(() => {
    if (repo != null) repo.destroy()
  })

  describe('@open(path)', () => {
    it('repo is null when no repository is found', async () => {
      repo = GitRepositoryAsync.open(path.join(temp.dir, 'nogit.txt'))

      let threw = false
      try {
        await repo.repoPromise
      } catch (e) {
        threw = true
      }

      expect(threw).toBeTruthy()
      expect(repo.repo).toBe(null)
    })
  })

  describe('.getPath()', () => {
    it('returns the repository path for a repository path', async () => {
      repo = openFixture('master.git')
      const repoPath = await repo.getPath()
      expect(repoPath).toBe(path.join(__dirname, 'fixtures', 'git', 'master.git'))
    })
  })

  describe('.isPathIgnored(path)', () => {
    let repo

    beforeEach(() => {
      repo = openFixture('ignore.git')
    })

    it('resolves true for an ignored path', async () => {
      const ignored = await repo.isPathIgnored('a.txt')
      expect(ignored).toBeTruthy()
    })

    it('resolves false for a non-ignored path', async () => {
      const ignored = await repo.isPathIgnored('b.txt')
      expect(ignored).toBeFalsy()
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
        expect(modified).toBeFalsy()
      })

      it('resolves true if the path is modified', async () => {
        fs.writeFileSync(filePath, 'change')
        const modified = await repo.isPathModified(filePath)
        expect(modified).toBeTruthy()
      })

      it('resolves false if the path is new', async () => {
        const modified = await repo.isPathModified(newPath)
        expect(modified).toBeFalsy()
      })

      it('resolves false if the path is invalid', async () => {
        const modified = await repo.isPathModified(emptyPath)
        expect(modified).toBeFalsy()
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
        expect(isNew).toBeTruthy()
      })

      it("returns false if the path isn't new", async () => {
        const modified = await repo.isPathModified(newPath)
        expect(modified).toBeFalsy()
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
      expect(modified).toBeFalsy()

      fs.writeFileSync(filePath, 'ch ch changes')

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeTruthy()

      await repo.checkoutHead(filePath)

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeFalsy()
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
      const status = Git.Status.STATUS.WT_MODIFIED
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
    let newPath, modifiedPath, cleanPath

    beforeEach(() => {
      const workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      modifiedPath = path.join(workingDirectory, 'file.txt')
      newPath = path.join(workingDirectory, 'untracked.txt')
      cleanPath = path.join(workingDirectory, 'other.txt')
      fs.writeFileSync(cleanPath, 'Full of text')
      fs.writeFileSync(newPath, '')
      newPath = fs.absolute(newPath) // specs could be running under symbol path.
    })

    it('returns status information for all new and modified files', async () => {
      fs.writeFileSync(modifiedPath, 'making this path modified')
      await repo.refreshStatus()

      expect(await repo.getCachedPathStatus(cleanPath)).toBeUndefined()
      expect(repo.isStatusNew(await repo.getCachedPathStatus(newPath))).toBeTruthy()
      expect(repo.isStatusModified(await repo.getCachedPathStatus(modifiedPath))).toBeTruthy()
    })
  })

  describe('buffer events', () => {
    let repository

    beforeEach(() => {
      const workingDirectory = copyRepository()
      atom.project.setPaths([workingDirectory])

      // When the path is added to the project, the repository is refreshed. We
      // need to wait for that to complete before the tests continue so that
      // we're in a known state.
      repository = atom.project.getRepositories()[0].async
      waitsFor(() => !repository._isRefreshing())
    })

    it('emits a status-changed event when a buffer is saved', async () => {
      const editor = await atom.workspace.open('other.txt')

      editor.insertNewline()

      let called
      repository.onDidChangeStatus(c => called = c)
      editor.save()

      waitsFor(() => Boolean(called))
      runs(() => expect(called).toEqual({path: editor.getPath(), pathStatus: 256}))
    })

    it('emits a status-changed event when a buffer is reloaded', async () => {
      const editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      const statusHandler = jasmine.createSpy('statusHandler')
      repository.onDidChangeStatus(statusHandler)
      editor.getBuffer().reload()

      waitsFor(() => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBeGreaterThan(0)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})
      })
    })

    it("emits a status-changed event when a buffer's path changes", async () => {
      const editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      const statusHandler = jasmine.createSpy('statusHandler')
      repository.onDidChangeStatus(statusHandler)
      editor.getBuffer().emitter.emit('did-change-path')

      waitsFor(() => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBeGreaterThan(0)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

        const pathHandler = jasmine.createSpy('pathHandler')
        const buffer = editor.getBuffer()
        buffer.onDidChangePath(pathHandler)
        buffer.emitter.emit('did-change-path')

        waitsFor(() => pathHandler.callCount > 0)
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
      waitsFor(() => !repository._isRefreshing())
    })

    afterEach(() => {
      if (project2) project2.destroy()
    })

    it('subscribes to all the serialized buffers in the project', async () => {
      await atom.workspace.open('file.txt')

      project2 = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
      project2.deserialize(atom.project.serialize(), atom.deserializers)

      const repo = project2.getRepositories()[0].async
      waitsFor(() => !repo._isRefreshing())
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
  })
})
