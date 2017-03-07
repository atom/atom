/* global HTMLElement */

let WorkspaceElement
const {ipcRenderer} = require('electron')
const path = require('path')
const fs = require('fs-plus')
const {CompositeDisposable} = require('event-kit')
const scrollbarStyle = require('scrollbar-style')

module.exports =
__initClass__(WorkspaceElement = class WorkspaceElement extends HTMLElement {
  static initClass () {
    this.prototype.globalTextEditorStyleSheet = null
  }

  attachedCallback () {
    return this.focus()
  }

  detachedCallback () {
    return this.subscriptions.dispose()
  }

  initializeContent () {
    this.classList.add('workspace')
    this.setAttribute('tabindex', -1)

    this.verticalAxis = document.createElement('atom-workspace-axis')
    this.verticalAxis.classList.add('vertical')

    this.horizontalAxis = document.createElement('atom-workspace-axis')
    this.horizontalAxis.classList.add('horizontal')
    this.horizontalAxis.appendChild(this.verticalAxis)

    return this.appendChild(this.horizontalAxis)
  }

  observeScrollbarStyle () {
    return this.subscriptions.add(scrollbarStyle.observePreferredScrollbarStyle(style => {
      switch (style) {
        case 'legacy':
          this.classList.remove('scrollbars-visible-when-scrolling')
          return this.classList.add('scrollbars-visible-always')
        case 'overlay':
          this.classList.remove('scrollbars-visible-always')
          return this.classList.add('scrollbars-visible-when-scrolling')
      }
    }
    )
    )
  }

  observeTextEditorFontConfig () {
    this.updateGlobalTextEditorStyleSheet()
    this.subscriptions.add(this.config.onDidChange('editor.fontSize', this.updateGlobalTextEditorStyleSheet.bind(this)))
    this.subscriptions.add(this.config.onDidChange('editor.fontFamily', this.updateGlobalTextEditorStyleSheet.bind(this)))
    return this.subscriptions.add(this.config.onDidChange('editor.lineHeight', this.updateGlobalTextEditorStyleSheet.bind(this)))
  }

  updateGlobalTextEditorStyleSheet () {
    const styleSheetSource = `\
atom-text-editor {
  font-size: ${this.config.get('editor.fontSize')}px
  font-family: ${this.config.get('editor.fontFamily')}
  line-height: ${this.config.get('editor.lineHeight')}
}\
`
    this.styles.addStyleSheet(styleSheetSource, {sourcePath: 'global-text-editor-styles'})
    return this.views.performDocumentPoll()
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
      return event.stopPropagation()
    }
  }

  handleFocus (event) {
    return this.model.getActivePane().activate()
  }

  focusPaneViewAbove () { return this.paneContainer.focusPaneViewAbove() }

  focusPaneViewBelow () { return this.paneContainer.focusPaneViewBelow() }

  focusPaneViewOnLeft () { return this.paneContainer.focusPaneViewOnLeft() }

  focusPaneViewOnRight () { return this.paneContainer.focusPaneViewOnRight() }

  moveActiveItemToPaneAbove (params) { return this.paneContainer.moveActiveItemToPaneAbove(params) }

  moveActiveItemToPaneBelow (params) { return this.paneContainer.moveActiveItemToPaneBelow(params) }

  moveActiveItemToPaneOnLeft (params) { return this.paneContainer.moveActiveItemToPaneOnLeft(params) }

  moveActiveItemToPaneOnRight (params) { return this.paneContainer.moveActiveItemToPaneOnRight(params) }

  runPackageSpecs () {
    let activePath, projectPath
    if ((activePath = __guardMethod__(this.workspace.getActivePaneItem(), 'getPath', o => o.getPath()))) {
      [projectPath] = Array.from(this.project.relativizePath(activePath))
    } else {
      [projectPath] = Array.from(this.project.getPaths())
    }
    if (projectPath) {
      let specPath = path.join(projectPath, 'spec')
      const testPath = path.join(projectPath, 'test')
      if (!fs.existsSync(specPath) && fs.existsSync(testPath)) {
        specPath = testPath
      }

      return ipcRenderer.send('run-package-specs', specPath)
    }
  }

  runBenchmarks () {
    let activePath, projectPath
    if ((activePath = __guardMethod__(this.workspace.getActivePaneItem(), 'getPath', o => o.getPath()))) {
      [projectPath] = Array.from(this.project.relativizePath(activePath))
    } else {
      [projectPath] = Array.from(this.project.getPaths())
    }

    if (projectPath) {
      return ipcRenderer.send('run-benchmarks', path.join(projectPath, 'benchmarks'))
    }
  }
})

module.exports = WorkspaceElement = document.registerElement('atom-workspace', {prototype: WorkspaceElement.prototype})

function __initClass__ (c) {
  c.initClass()
  return c
}
function __guardMethod__ (obj, methodName, transform) {
  if (typeof obj !== 'undefined' && obj !== null && typeof obj[methodName] === 'function') {
    return transform(obj, methodName)
  } else {
    return undefined
  }
}
