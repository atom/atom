'use strict'

const focusTrap = require('focus-trap')
const {CompositeDisposable} = require('event-kit')

class PanelContainerElement extends HTMLElement {
  createdCallback () {
    this.subscriptions = new CompositeDisposable()
  }

  attachedCallback () {
    if (this.model.dock) {
      this.model.dock.elementAttached()
    }
  }

  initialize (model, viewRegistry) {
    this.model = model
    this.viewRegistry = viewRegistry

    this.subscriptions.add(this.model.onDidAddPanel(this.panelAdded.bind(this)))
    this.subscriptions.add(this.model.onDidDestroy(this.destroyed.bind(this)))
    this.classList.add(this.model.getLocation())

    // Add the dock.
    if (this.model.dock != null) {
      this.appendChild(this.model.dock.getElement())
    }

    return this
  }

  getModel () { return this.model }

  panelAdded ({panel, index}) {
    const panelElement = panel.getElement()
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

      if (panel.autoFocus) {
        const modalFocusTrap = focusTrap(panelElement, {
          // focus-trap will attempt to give focus to the first tabbable element
          // on activation. If there aren't any tabbable elements,
          // give focus to the panel element itself
          fallbackFocus: panelElement,
          // closing is handled by core Atom commands and this already deactivates
          // on visibility changes
          escapeDeactivates: false
        })

        this.subscriptions.add(panel.onDidChangeVisible(visible => {
          if (visible) {
            modalFocusTrap.activate()
          } else {
            modalFocusTrap.deactivate()
          }
        }))
      }
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
