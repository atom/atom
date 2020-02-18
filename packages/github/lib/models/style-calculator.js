import {CompositeDisposable} from 'event-kit';

import {autobind} from '../helpers';

export default class StyleCalculator {
  constructor(styles, config) {
    autobind(this, 'updateStyles');

    this.styles = styles;
    this.config = config;
  }

  startWatching(sourcePath, configsToWatch, getStylesheetFn) {
    const subscriptions = new CompositeDisposable();
    const updateStyles = () => {
      this.updateStyles(sourcePath, getStylesheetFn);
    };
    configsToWatch.forEach(configToWatch => {
      subscriptions.add(
        this.config.onDidChange(configToWatch, updateStyles),
      );
    });
    updateStyles();
    return subscriptions;
  }

  updateStyles(sourcePath, getStylesheetFn) {
    const stylesheet = getStylesheetFn(this.config);
    this.styles.addStyleSheet(stylesheet, {sourcePath, priority: 0});
  }
}
