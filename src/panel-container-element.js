'use strict'

/* global HTMLElement */

const {CompositeDisposable} = require('event-kit')

class PanelContainerElement extends HTMLElement {
  createdCallback () {
    this.subscriptions = new CompositeDisposable()
  }

  initialize (model, {views}) {
    this.model = model
    this.views = views
    if (this.views == null) {
      throw new Error('Must pass a views parameter when initializing PanelContainerElements')
    }

    this.subscriptions.add(this.model.onDidAddPanel(this.panelAdded.bind(this)))
    this.subscriptions.add(this.model.onDidDestroy(this.destroyed.bind(this)))
    this.classList.add(this.model.getLocation())
    return this
  }

  getModel () { return this.model }

  panelAdded ({panel, index}) {
    const panelElement = this.views.getView(panel)
    panelElement.classList.add(this.model.getLocation())
    if (this.model.isModal()) {
      panelElement.classList.add('overlay', 'from-top')
    } else {
      panelElement.classList.add('tool-panel', `panel-${this.model.getLocation()}`)
    }

    if (index >= this.childNodes.length) {
      this.appendChild(panelElement)
    } else {
      const referenceItem = this.childNodes[index]
      this.insertBefore(panelElement, referenceItem)
    }

    if (this.model.isModal()) {
      this.hideAllPanelsExcept(panel)
      this.subscriptions.add(panel.onDidChangeVisible(visible => {
        if (visible) { this.hideAllPanelsExcept(panel) }
      }))
    }
  }

  destroyed () {
    this.subscriptions.dispose()
    if (this.parentNode != null) {
      this.parentNode.removeChild(this)
    }
  }

  hideAllPanelsExcept (excludedPanel) {
    for (let panel of this.model.getPanels()) {
      if (panel !== excludedPanel) { panel.hide() }
    }
  }
}

module.exports = document.registerElement('atom-panel-container', {prototype: PanelContainerElement.prototype})
