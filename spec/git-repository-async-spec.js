'use babel'

const fs = require('fs-plus')
const path = require('path')
const temp = require('temp')
const Git = require('nodegit')
const CompositeDisposable = require('event-kit').CompositeDisposable

temp.track()

const GitRepositoryAsync = require('../src/git-repository-async')

function openFixture(fixture) {
  return GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
}

function copyRepository() {
  let workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  return fs.realpathSync(workingDirPath)
}

function asyncIt(name, fn) {
  it(name, () => {
    waitsForPromise(fn)
  })
}

function fasyncIt(name, fn) {
  fit(name, () => {
    waitsForPromise(fn)
  })
}

function xasyncIt(name, fn) {
  xit(name, () => {
    waitsForPromise(fn)
  })
}

fdescribe('GitRepositoryAsync-js', () => {
  let repo

  afterEach(() => {
    if (repo != null) repo.destroy()
  })

  describe('@open(path)', () => {
    asyncIt('repo is null when no repository is found', async () => {
      repo = GitRepositoryAsync.open(path.join(temp.dir, 'nogit.txt'))

      let threw = false
      try {
        await repo.repoPromise
      } catch(e) {
        threw = true
      }

      expect(threw).toBeTruthy()
      expect(repo.repo).toBe(null)
    })
  })

  describe('.getPath()', () => {
    xit('returns the repository path for a .git directory path')

    asyncIt('returns the repository path for a repository path', async () => {
      repo = openFixture('master.git')
      let repoPath = await repo.getPath()
      expect(repoPath).toBe(path.join(__dirname, 'fixtures', 'git', 'master.git'))
    })
  })

  describe('.isPathIgnored(path)', () => {
    asyncIt('resolves true for an ignored path', async () => {
      repo = openFixture('ignore.git')
      let ignored = await repo.isPathIgnored('a.txt')
      expect(ignored).toBeTruthy()
    })

    asyncIt('resolves false for a non-ignored path', async () => {
      repo = openFixture('ignore.git')
      let ignored = await repo.isPathIgnored('b.txt')
      expect(ignored).toBeFalsy()
    })
  })

  describe('.isPathModified(path)', () => {
    let filePath, newPath, emptyPath

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
      emptyPath = path.join(workingDirPath, 'empty-path.txt')
    })

    describe('when the path is unstaged', () => {
      asyncIt('resolves false if the path has not been modified', async () => {
        let modified = await repo.isPathModified(filePath)
        expect(modified).toBeFalsy()
      })

      asyncIt('resolves true if the path is modified', async () => {
        fs.writeFileSync(filePath, "change")
        let modified = await repo.isPathModified(filePath)
        expect(modified).toBeTruthy()
      })

      asyncIt('resolves false if the path is new', async () => {
        let modified = await repo.isPathModified(newPath)
        expect(modified).toBeFalsy()
      })

      asyncIt('resolves false if the path is invalid', async () => {
        let modified = await repo.isPathModified(emptyPath)
        expect(modified).toBeFalsy()
      })
    })
  })

  describe('.isPathNew(path)', () => {
    let filePath, newPath

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
    })

    describe('when the path is unstaged', () => {
      asyncIt('returns true if the path is new', async () => {
        let isNew = await repo.isPathNew(newPath)
        expect(isNew).toBeTruthy()
      })

      asyncIt("returns false if the path isn't new", async () => {
        let modified = await repo.isPathModified(newPath)
        expect(modified).toBeFalsy()
      })
    })
  })

  describe('.checkoutHead(path)', () => {
    let filePath

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
    })

    asyncIt('no longer reports a path as modified after checkout', async () => {
      let modified = await repo.isPathModified(filePath)
      expect(modified).toBeFalsy()

      fs.writeFileSync(filePath, 'ch ch changes')

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeTruthy()

      await repo.checkoutHead(filePath)

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeFalsy()
    })

    asyncIt('restores the contents of the path to the original text', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')
      await repo.checkoutHead(filePath)
      expect(fs.readFileSync(filePath, 'utf8')).toBe('')
    })

    asyncIt('fires a did-change-status event if the checkout completes successfully', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')

      await repo.getPathStatus(filePath)

      let statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus(statusHandler)

      await repo.checkoutHead(filePath)

      expect(statusHandler.callCount).toBe(1)
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: 0})

      await repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  xdescribe('.checkoutHeadForEditor(editor)', () => {
    let filePath, editor

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      fs.writeFileSync(filePath, 'ch ch changes')

      waitsForPromise(() => atom.workspace.open(filePath))
      runs(() => editor = atom.workspace.getActiveTextEditor())
    })

    xit('displays a confirmation dialog by default', () => {
      spyOn(atom, 'confirm').andCallFake(buttons, () => buttons[0].OK())
      atom.config.set('editor.confirmCheckoutHeadRevision', true)

      waitsForPromise(() => repo.checkoutHeadForEditor(editor))
      runs(() => expect(fs.readFileSync(filePath, 'utf8')).toBe(''))
    })

    xit('does not display a dialog when confirmation is disabled', () => {
      spyOn(atom, 'confirm')
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      waitsForPromise(() => repo.checkoutHeadForEditor(editor))
      runs(() => {
        expect(fs.readFileSync(filePath, 'utf8')).toBe('')
        expect(atom.confirm).not.toHaveBeenCalled()
      })
    })
  })

  describe('.getPathStatus(path)', () => {
    let filePath

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      filePath = path.join(workingDirectory, 'file.txt')
    })

    asyncIt('trigger a status-changed event when the new status differs from the last cached one', async () => {
      let statusHandler = jasmine.createSpy("statusHandler")
      repo.onDidChangeStatus(statusHandler)
      fs.writeFileSync(filePath, '')

      await repo.getPathStatus(filePath)

      expect(statusHandler.callCount).toBe(1)
      let status = Git.Status.STATUS.WT_MODIFIED
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: status})
      fs.writeFileSync(filePath, 'abc')

      await repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  describe('.getDirectoryStatus(path)', () => {
    let directoryPath, filePath

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      directoryPath = path.join(workingDirectory, 'dir')
      filePath = path.join(directoryPath, 'b.txt')
    })

    asyncIt('gets the status based on the files inside the directory', async () => {
      await repo.checkoutHead(filePath)

      let result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(false)

      fs.writeFileSync(filePath, 'abc')

      result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(true)
    })
  })

  describe('.refreshStatus()', () => {
    let newPath, modifiedPath, cleanPath, originalModifiedPathText

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      modifiedPath = path.join(workingDirectory, 'file.txt')
      newPath = path.join(workingDirectory, 'untracked.txt')
      cleanPath = path.join(workingDirectory, 'other.txt')
      fs.writeFileSync(cleanPath, 'Full of text')
      fs.writeFileSync(newPath, '')
      newPath = fs.absolute(newPath) // specs could be running under symbol path.
    })

    asyncIt('returns status information for all new and modified files', async () => {
      fs.writeFileSync(modifiedPath, 'making this path modified')
      await repo.refreshStatus()

      expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined()
      expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy()
      expect(repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))).toBeTruthy()
    })
  })

  describe('buffer events', () => {
    beforeEach(() => {
      // This is sync, should be fine in a beforeEach
      atom.project.setPaths([copyRepository()])
    })

    asyncIt('emits a status-changed event when a buffer is saved', async () => {
      let editor = await atom.workspace.open('other.txt')

      editor.insertNewline()

      let repository = atom.project.getRepositories()[0].async
      let called
      repository.onDidChangeStatus(c => called = c)
      editor.save()

      waitsFor(() => Boolean(called))
      runs(() => expect(called).toEqual({path: editor.getPath(), pathStatus: 256}))
    })

    asyncIt('emits a status-changed event when a buffer is reloaded', async () => {
      let statusHandler = jasmine.createSpy('statusHandler')
      let reloadHandler = jasmine.createSpy('reloadHandler')

      let editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      let repository = atom.project.getRepositories()[0].async
      repository.onDidChangeStatus(statusHandler)
      editor.getBuffer().reload()

      waitsFor(() => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBe(1)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

        let buffer = editor.getBuffer()
        buffer.onDidReload(reloadHandler)
        buffer.reload()

        waitsFor(() => reloadHandler.callCount > 0)
        runs(() => expect(statusHandler.callCount).toBe(1))
      })
    })

    asyncIt("emits a status-changed event when a buffer's path changes", async () => {
      let editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      let statusHandler = jasmine.createSpy('statusHandler')
      let repository = atom.project.getRepositories()[0].async
      repository.onDidChangeStatus(statusHandler)
      editor.getBuffer().emitter.emit('did-change-path')
      waitsFor(() => statusHandler.callCount > 0)
      runs(() => {
        expect(statusHandler.callCount).toBe(1)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

        let pathHandler = jasmine.createSpy('pathHandler')
        let buffer = editor.getBuffer()
        buffer.onDidChangePath(pathHandler)
        buffer.emitter.emit('did-change-path')

        waitsFor(() => pathHandler.callCount > 0)
        runs(() => expect(statusHandler.callCount).toBe(1))
      })
    })

    xasyncIt('stops listening to the buffer when the repository is destroyed (regression)', async () => {
      let editor = await atom.workspace.open('other.txt')
      atom.project.getRepositories()[0].destroy()
      expect(() => editor.save()).not.toThrow()
    })
  })

  xdescribe('GitRepositoryAsync::relativize(filePath)')

})
