/** @babel */

import { CompositeDisposable } from 'atom';

let reporter;

function getReporter() {
  if (!reporter) {
    const Reporter = require('./reporter');
    reporter = new Reporter();
  }
  return reporter;
}

export default {
  activate() {
    this.subscriptions = new CompositeDisposable();

    if (!atom.config.get('exception-reporting.userId')) {
      atom.config.set('exception-reporting.userId', require('node-uuid').v4());
    }

    this.subscriptions.add(
      atom.onDidThrowError(({ message, url, line, column, originalError }) => {
        try {
          getReporter().reportUncaughtException(originalError);
        } catch (secondaryException) {
          try {
            console.error(
              'Error reporting uncaught exception',
              secondaryException
            );
            getReporter().reportUncaughtException(secondaryException);
          } catch (error) {}
        }
      })
    );

    if (atom.onDidFailAssertion != null) {
      this.subscriptions.add(
        atom.onDidFailAssertion(error => {
          try {
            getReporter().reportFailedAssertion(error);
          } catch (secondaryException) {
            try {
              console.error(
                'Error reporting assertion failure',
                secondaryException
              );
              getReporter().reportUncaughtException(secondaryException);
            } catch (error) {}
          }
        })
      );
    }
  }
};
