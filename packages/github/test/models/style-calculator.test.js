import {Disposable} from 'event-kit';

import dedent from 'dedent-js';

import StyleCalculator from '../../lib/models/style-calculator';

describe('StyleCalculator', function(done) {
  it('updates a stylesheet based on configuration', function() {
    const configChangeCallbacks = {};

    const stylesMock = {
      addStyleSheet: sinon.stub(),
    };

    const configMock = {
      onDidChange: sinon.spy((configKey, callback) => {
        configChangeCallbacks[configKey] = callback;
        return new Disposable(() => {});
      }),
      get: configKey => `config-val-${configKey}`,
    };

    const expectedCss = dedent`
      .my-thing {
        config1: config-val-config1;
        config2: config-val-config2;
      }
    `.trim();

    const styleCalculator = new StyleCalculator(stylesMock, configMock);
    styleCalculator.startWatching(
      'my-source-path',
      ['config1', 'config2'],
      config => {
        return dedent`
          .my-thing {
            config1: ${config.get('config1')};
            config2: ${config.get('config2')};
          }
        `.trim();
      },
    );

    assert.deepEqual(Object.keys(configChangeCallbacks), ['config1', 'config2']);
    assert.equal(stylesMock.addStyleSheet.callCount, 1);
    assert.deepEqual(stylesMock.addStyleSheet.getCall(0).args, [
      expectedCss, {sourcePath: 'my-source-path', priority: 0},
    ]);

    configChangeCallbacks.config1();
    assert.equal(stylesMock.addStyleSheet.callCount, 2);
    assert.deepEqual(stylesMock.addStyleSheet.getCall(1).args, [
      expectedCss, {sourcePath: 'my-source-path', priority: 0},
    ]);

    configChangeCallbacks.config2();
    assert.equal(stylesMock.addStyleSheet.callCount, 3);
    assert.deepEqual(stylesMock.addStyleSheet.getCall(2).args, [
      expectedCss, {sourcePath: 'my-source-path', priority: 0},
    ]);
  });
});
