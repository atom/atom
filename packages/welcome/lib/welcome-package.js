/** @babel */

import { CompositeDisposable } from 'atom';
import ReporterProxy from './reporter-proxy';

let WelcomeView, GuideView, ConsentView;

const WELCOME_URI = 'atom://welcome/welcome';
const GUIDE_URI = 'atom://welcome/guide';
const CONSENT_URI = 'atom://welcome/consent';

export default class WelcomePackage {
  constructor() {
    this.reporterProxy = new ReporterProxy();
  }

  async activate() {
    this.subscriptions = new CompositeDisposable();

    this.subscriptions.add(
      atom.workspace.addOpener(filePath => {
        if (filePath === WELCOME_URI) {
          return this.createWelcomeView({ uri: WELCOME_URI });
        }
      })
    );

    this.subscriptions.add(
      atom.workspace.addOpener(filePath => {
        if (filePath === GUIDE_URI) {
          return this.createGuideView({ uri: GUIDE_URI });
        }
      })
    );

    this.subscriptions.add(
      atom.workspace.addOpener(filePath => {
        if (filePath === CONSENT_URI) {
          return this.createConsentView({ uri: CONSENT_URI });
        }
      })
    );

    this.subscriptions.add(
      atom.commands.add('atom-workspace', 'welcome:show', () => this.show())
    );

    if (atom.config.get('core.telemetryConsent') === 'undecided') {
      await atom.workspace.open(CONSENT_URI);
    }

    if (atom.config.get('welcome.showOnStartup')) {
      await this.show();
      this.reporterProxy.sendEvent('show-on-initial-load');
    }
  }

  show() {
    return Promise.all([
      atom.workspace.open(WELCOME_URI, { split: 'left' }),
      atom.workspace.open(GUIDE_URI, { split: 'right' })
    ]);
  }

  consumeReporter(reporter) {
    return this.reporterProxy.setReporter(reporter);
  }

  deactivate() {
    this.subscriptions.dispose();
  }

  createWelcomeView(state) {
    if (WelcomeView == null) WelcomeView = require('./welcome-view');
    return new WelcomeView({ reporterProxy: this.reporterProxy, ...state });
  }

  createGuideView(state) {
    if (GuideView == null) GuideView = require('./guide-view');
    return new GuideView({ reporterProxy: this.reporterProxy, ...state });
  }

  createConsentView(state) {
    if (ConsentView == null) ConsentView = require('./consent-view');
    return new ConsentView({ reporterProxy: this.reporterProxy, ...state });
  }
}
