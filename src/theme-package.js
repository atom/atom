const path = require('path');
const Package = require('./package');

module.exports = class ThemePackage extends Package {
  getType() {
    return 'theme';
  }

  getStyleSheetPriority() {
    return 1;
  }

  enable() {
    this.config.unshiftAtKeyPath('core.themes', this.name);
  }

  disable() {
    this.config.removeAtKeyPath('core.themes', this.name);
  }

  preload() {
    this.loadTime = 0;
    this.configSchemaRegisteredOnLoad = this.registerConfigSchemaFromMetadata();
  }

  finishLoading() {
    this.path = path.join(this.packageManager.resourcePath, this.path);
  }

  load() {
    this.loadTime = 0;
    this.configSchemaRegisteredOnLoad = this.registerConfigSchemaFromMetadata();
    return this;
  }

  activate() {
    if (this.activationPromise == null) {
      this.activationPromise = new Promise((resolve, reject) => {
        this.resolveActivationPromise = resolve;
        this.rejectActivationPromise = reject;
        this.measure('activateTime', () => {
          try {
            this.loadStylesheets();
            this.activateNow();
          } catch (error) {
            this.handleError(
              `Failed to activate the ${this.name} theme`,
              error
            );
          }
        });
      });
    }

    return this.activationPromise;
  }
};
