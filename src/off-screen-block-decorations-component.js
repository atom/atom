module.exports = class OffScreenBlockDecorationsComponent {
  constructor ({presenter, views}) {
    this.presenter = presenter
    this.views = views
    this.newState = {offScreenBlockDecorations: {}, width: 0}
    this.oldState = {offScreenBlockDecorations: {}, width: 0}
    this.domNode = document.createElement('div')
    this.domNode.style.visibility = 'hidden'
    this.domNode.style.position = 'absolute'
    this.blockDecorationNodesById = {}
  }

  getDomNode () {
    return this.domNode
  }

  updateSync (state) {
    this.newState = state.content

    if (this.newState.width !== this.oldState.width) {
      this.domNode.style.width = `${this.newState.width}px`
      this.oldState.width = this.newState.width
    }

    for (const id of Object.keys(this.oldState.offScreenBlockDecorations)) {
      if (!this.newState.offScreenBlockDecorations.hasOwnProperty(id)) {
        const {topRuler, blockDecoration, bottomRuler} = this.blockDecorationNodesById[id]
        topRuler.remove()
        blockDecoration.remove()
        bottomRuler.remove()
        delete this.blockDecorationNodesById[id]
        delete this.oldState.offScreenBlockDecorations[id]
      }
    }

    for (const id of Object.keys(this.newState.offScreenBlockDecorations)) {
      const decoration = this.newState.offScreenBlockDecorations[id]
      if (!this.oldState.offScreenBlockDecorations.hasOwnProperty(id)) {
        const topRuler = document.createElement('div')
        this.domNode.appendChild(topRuler)
        const blockDecoration = this.views.getView(decoration.getProperties().item)
        this.domNode.appendChild(blockDecoration)
        const bottomRuler = document.createElement('div')
        this.domNode.appendChild(bottomRuler)

        this.blockDecorationNodesById[id] = {topRuler, blockDecoration, bottomRuler}
      }

      this.oldState.offScreenBlockDecorations[id] = decoration
    }
  }

  measureBlockDecorations () {
    for (const id of Object.keys(this.blockDecorationNodesById)) {
      const {topRuler, blockDecoration, bottomRuler} = this.blockDecorationNodesById[id]
      const width = blockDecoration.offsetWidth
      const height = bottomRuler.offsetTop - topRuler.offsetTop
      const decoration = this.newState.offScreenBlockDecorations[id]
      this.presenter.setBlockDecorationDimensions(decoration, width, height)
    }
  }
}
