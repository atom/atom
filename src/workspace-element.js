'use strict'

/* global HTMLElement */

const {ipcRenderer} = require('electron')
const path = require('path')
const fs = require('fs-plus')
const {CompositeDisposable} = require('event-kit')
const scrollbarStyle = require('scrollbar-style')

class WorkspaceElement extends HTMLElement {
  attachedCallback () {
    this.focus()
  }

  detachedCallback () {
    this.subscriptions.dispose()
  }

  initializeContent () {
    this.classList.add('workspace')
    this.setAttribute('tabindex', -1)

    this.verticalAxis = document.createElement('atom-workspace-axis')
    this.verticalAxis.classList.add('vertical')

    this.horizontalAxis = document.createElement('atom-workspace-axis')
    this.horizontalAxis.classList.add('horizontal')
    this.horizontalAxis.appendChild(this.verticalAxis)

    this.appendChild(this.horizontalAxis)
  }

  observeScrollbarStyle () {
    this.subscriptions.add(scrollbarStyle.observePreferredScrollbarStyle(style => {
      switch (style) {
        case 'legacy':
          this.classList.remove('scrollbars-visible-when-scrolling')
          this.classList.add('scrollbars-visible-always')
          break
        case 'overlay':
          this.classList.remove('scrollbars-visible-always')
          this.classList.add('scrollbars-visible-when-scrolling')
          break
      }
    }))
  }

  observeTextEditorFontConfig () {
    this.updateGlobalTextEditorStyleSheet()
    this.subscriptions.add(this.config.onDidChange('editor.fontSize', this.updateGlobalTextEditorStyleSheet.bind(this)))
    this.subscriptions.add(this.config.onDidChange('editor.fontFamily', this.updateGlobalTextEditorStyleSheet.bind(this)))
    this.subscriptions.add(this.config.onDidChange('editor.lineHeight', this.updateGlobalTextEditorStyleSheet.bind(this)))
  }

  updateGlobalTextEditorStyleSheet () {
    const styleSheetSource = `atom-text-editor {
  font-size: ${this.config.get('editor.fontSize')}px;
  font-family: ${this.config.get('editor.fontFamily')};
  line-height: ${this.config.get('editor.lineHeight')};
}`
    this.styles.addStyleSheet(styleSheetSource, {sourcePath: 'global-text-editor-styles'})
  }

  initialize (model, {views, workspace, project, config, styles}) {
    this.model = model
    this.views = views
    this.workspace = workspace
    this.project = project
    this.config = config
    this.styles = styles
    if (this.views == null) { throw new Error('Must pass a views parameter when initializing WorskpaceElements') }
    if (this.workspace == null) { throw new Error('Must pass a workspace parameter when initializing WorskpaceElements') }
    if (this.project == null) { throw new Error('Must pass a project parameter when initializing WorskpaceElements') }
    if (this.config == null) { throw new Error('Must pass a config parameter when initializing WorskpaceElements') }
    if (this.styles == null) { throw new Error('Must pass a styles parameter when initializing WorskpaceElements') }

    this.subscriptions = new CompositeDisposable()
    this.initializeContent()
    this.observeScrollbarStyle()
    this.observeTextEditorFontConfig()

    this.paneContainer = this.views.getView(this.model.paneContainer)
    this.verticalAxis.appendChild(this.paneContainer)
    this.addEventListener('focus', this.handleFocus.bind(this))

    this.addEventListener('mousewheel', this.handleMousewheel.bind(this), true)

    this.panelContainers = {
      top: this.views.getView(this.model.panelContainers.top),
      left: this.views.getView(this.model.panelContainers.left),
      right: this.views.getView(this.model.panelContainers.right),
      bottom: this.views.getView(this.model.panelContainers.bottom),
      header: this.views.getView(this.model.panelContainers.header),
      footer: this.views.getView(this.model.panelContainers.footer),
      modal: this.views.getView(this.model.panelContainers.modal)
    }

    this.horizontalAxis.insertBefore(this.panelContainers.left, this.verticalAxis)
    this.horizontalAxis.appendChild(this.panelContainers.right)

    this.verticalAxis.insertBefore(this.panelContainers.top, this.paneContainer)
    this.verticalAxis.appendChild(this.panelContainers.bottom)

    this.insertBefore(this.panelContainers.header, this.horizontalAxis)
    this.appendChild(this.panelContainers.footer)

    this.appendChild(this.panelContainers.modal)

    return this
  }

  getModel () { return this.model }

  handleMousewheel (event) {
    if (event.ctrlKey && this.config.get('editor.zoomFontWhenCtrlScrolling') && (event.target.closest('atom-text-editor') != null)) {
      if (event.wheelDeltaY > 0) {
        this.model.increaseFontSize()
      } else if (event.wheelDeltaY < 0) {
        this.model.decreaseFontSize()
      }
      event.preventDefault()
      event.stopPropagation()
    }
  }

  handleFocus (event) {
    this.model.getActivePane().activate()
  }

  focusPaneViewAbove () { this.paneContainer.focusPaneViewAbove() }

  focusPaneViewBelow () { this.paneContainer.focusPaneViewBelow() }

  focusPaneViewOnLeft () { this.paneContainer.focusPaneViewOnLeft() }

  focusPaneViewOnRight () { this.paneContainer.focusPaneViewOnRight() }

  moveActiveItemToPaneAbove (params) { this.paneContainer.moveActiveItemToPaneAbove(params) }

  moveActiveItemToPaneBelow (params) { this.paneContainer.moveActiveItemToPaneBelow(params) }

  moveActiveItemToPaneOnLeft (params) { this.paneContainer.moveActiveItemToPaneOnLeft(params) }

  moveActiveItemToPaneOnRight (params) { this.paneContainer.moveActiveItemToPaneOnRight(params) }

  runPackageSpecs () {
    const activePaneItem = this.workspace.getActivePaneItem()
    const activePath = activePaneItem && typeof activePaneItem.getPath === 'function' ? activePaneItem.getPath() : null
    let projectPath
    if (activePath != null) {
      [projectPath] = this.project.relativizePath(activePath)
    } else {
      [projectPath] = this.project.getPaths()
    }
    if (projectPath) {
      let specPath = path.join(projectPath, 'spec')
      const testPath = path.join(projectPath, 'test')
      if (!fs.existsSync(specPath) && fs.existsSync(testPath)) {
        specPath = testPath
      }

      ipcRenderer.send('run-package-specs', specPath)
    }
  }

  runBenchmarks () {
    const activePaneItem = this.workspace.getActivePaneItem()
    const activePath = activePaneItem && typeof activePaneItem.getPath === 'function' ? activePaneItem.getPath() : null
    let projectPath
    if (activePath) {
      [projectPath] = this.project.relativizePath(activePath)
    } else {
      [projectPath] = this.project.getPaths()
    }

    if (projectPath) {
      ipcRenderer.send('run-benchmarks', path.join(projectPath, 'benchmarks'))
    }
  }
}

module.exports = document.registerElement('atom-workspace', {prototype: WorkspaceElement.prototype})
