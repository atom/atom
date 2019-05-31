const etch = require('etch');
const EtchComponent = require('../etch-component');
const UpdateManager = require('../update-manager');

const $ = etch.dom;

module.exports = class UpdateView extends EtchComponent {
  constructor(props) {
    super(props);

    if (
      this.props.updateManager.getAutoUpdatesEnabled() &&
      this.props.updateManager.getState() === UpdateManager.State.Idle
    ) {
      this.props.updateManager.checkForUpdate();
    }
  }

  handleAutoUpdateCheckbox(e) {
    atom.config.set('core.automaticallyUpdate', e.target.checked);
  }

  shouldUpdateActionButtonBeDisabled() {
    let { state } = this.props.updateManager;
    return (
      state === UpdateManager.State.CheckingForUpdate ||
      state === UpdateManager.State.DownloadingUpdate
    );
  }

  executeUpdateAction() {
    if (
      this.props.updateManager.state ===
      UpdateManager.State.UpdateAvailableToInstall
    ) {
      this.props.updateManager.restartAndInstallUpdate();
    } else {
      this.props.updateManager.checkForUpdate();
    }
  }

  renderUpdateStatus() {
    let updateStatus = '';

    switch (this.props.updateManager.state) {
      case UpdateManager.State.Idle:
        updateStatus = $.div(
          {
            className:
              'about-updates-item is-shown about-default-update-message'
          },
          this.props.updateManager.getAutoUpdatesEnabled()
            ? 'Atom will check for updates automatically'
            : 'Automatic updates are disabled please check manually'
        );
        break;
      case UpdateManager.State.CheckingForUpdate:
        updateStatus = $.div(
          { className: 'about-updates-item app-checking-for-updates' },
          $.span(
            { className: 'about-updates-label icon icon-search' },
            'Checking for updates...'
          )
        );
        break;
      case UpdateManager.State.DownloadingUpdate:
        updateStatus = $.div(
          { className: 'about-updates-item app-downloading-update' },
          $.span({ className: 'loading loading-spinner-tiny inline-block' }),
          $.span({ className: 'about-updates-label' }, 'Downloading update')
        );
        break;
      case UpdateManager.State.UpdateAvailableToInstall:
        updateStatus = $.div(
          { className: 'about-updates-item app-update-available-to-install' },
          $.span(
            { className: 'about-updates-label icon icon-squirrel' },
            'New update'
          ),
          $.span(
            { className: 'about-updates-version' },
            this.props.availableVersion
          ),
          $.a(
            {
              className: 'about-updates-release-notes',
              onclick: this.props.viewUpdateReleaseNotes
            },
            'Release Notes'
          )
        );
        break;
      case UpdateManager.State.UpToDate:
        updateStatus = $.div(
          { className: 'about-updates-item app-up-to-date' },
          $.span({ className: 'icon icon-check' }),
          $.span(
            { className: 'about-updates-label is-strong' },
            'Atom is up to date!'
          )
        );
        break;
      case UpdateManager.State.Unsupported:
        updateStatus = $.div(
          { className: 'about-updates-item app-unsupported' },
          $.span(
            { className: 'about-updates-label is-strong' },
            'Your system does not support automatic updates'
          ),
          $.a(
            {
              className: 'about-updates-instructions',
              onclick: this.props.viewUpdateInstructions
            },
            'How to update'
          )
        );
        break;
      case UpdateManager.State.Error:
        updateStatus = $.div(
          { className: 'about-updates-item app-update-error' },
          $.span({ className: 'icon icon-x' }),
          $.span(
            { className: 'about-updates-label app-error-message is-strong' },
            this.props.updateManager.getErrorMessage()
          )
        );
        break;
    }

    return updateStatus;
  }

  render() {
    return $.div(
      { className: 'about-updates group-start' },
      $.div(
        { className: 'about-updates-box' },
        $.div({ className: 'about-updates-status' }, this.renderUpdateStatus()),
        $.button(
          {
            className: 'btn about-update-action-button',
            disabled: this.shouldUpdateActionButtonBeDisabled(),
            onclick: this.executeUpdateAction.bind(this),
            style: {
              display:
                this.props.updateManager.state ===
                UpdateManager.State.Unsupported
                  ? 'none'
                  : 'block'
            }
          },
          this.props.updateManager.state === 'update-available'
            ? 'Restart and install'
            : 'Check now'
        )
      ),
      $.div(
        {
          className: 'about-auto-updates',
          style: {
            display:
              this.props.updateManager.state === UpdateManager.State.Unsupported
                ? 'none'
                : 'block'
          }
        },
        $.label(
          {},
          $.input({
            className: 'input-checkbox',
            type: 'checkbox',
            checked: this.props.updateManager.getAutoUpdatesEnabled(),
            onchange: this.handleAutoUpdateCheckbox.bind(this)
          }),
          $.span({}, 'Automatically download updates')
        )
      )
    );
  }
};
