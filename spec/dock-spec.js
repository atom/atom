describe('Dock', () => {
  describe('when a pane in a dock is activated', () => {
    it('opens the dock', () => {
      const item = {
        getDefaultLocation() { return 'left' }
      }

      atom.workspace.open(item, {activatePane: false})
      expect(atom.workspace.getLeftDock().isOpen()).toBe(false)

      atom.workspace.getLeftDock().getPanes()[0].activate()
      expect(atom.workspace.getLeftDock().isOpen()).toBe(true)
    })
  })
})