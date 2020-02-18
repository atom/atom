import {CompositeDisposable} from 'event-kit';
import Switchboard from '../lib/switchboard';

describe('Switchboard', function() {
  let switchboard;

  beforeEach(function() {
    switchboard = new Switchboard();
  });

  describe('events', function() {
    let sub;

    afterEach(function() {
      sub && sub.dispose();
    });

    it('synchronously broadcasts events', function() {
      let observed = 0;
      sub = switchboard.onDid('test', () => observed++);

      assert.equal(observed, 0);
      switchboard.did('test');
      assert.equal(observed, 1);
    });
  });

  describe('promises', function() {
    it('creates and resolves a Promise for an event', async function() {
      const promise = switchboard.getPromise('testing');

      const payload = {};
      switchboard.did('testing', payload);

      const result = await promise;
      assert.strictEqual(result, payload);
    });

    it('supports multiple consumers of the same Promise', async function() {
      const promise0 = switchboard.getPromise('testing');
      const promise1 = switchboard.getPromise('testing');
      assert.strictEqual(promise0, promise1);

      const payload = {};
      switchboard.did('testing', payload);

      assert.strictEqual(await promise0, payload);
      assert.strictEqual(await promise1, payload);
    });

    it('creates new Promises for repeated events', async function() {
      const promise0 = switchboard.getPromise('testing');

      switchboard.did('testing', 0);
      assert.equal(await promise0, 0);

      const promise1 = switchboard.getPromise('testing');

      switchboard.did('testing', 1);
      assert.equal(await promise1, 1);
    });

    it('"resolves" an event that has no Promise', function() {
      switchboard.did('anybody-there', {});
    });
  });

  // Ensure that all of the `didXyz`, `onDidXyz`, and `getXyzPromise` method triplets are aligned correctly.
  describe('function triplets', function() {
    const baseNames = Object.getOwnPropertyNames(Switchboard.prototype)
      .map(methodName => /^did(.+)$/.exec(methodName))
      .filter(match => match !== null)
      .map(match => match[1]);
    let functionTriples;

    beforeEach(function() {
      functionTriples = baseNames.map(baseName => {
        return {
          baseName,
          subscriber: switchboard[`onDid${baseName}`].bind(switchboard),
          getter: switchboard[`get${baseName}Promise`].bind(switchboard),
          resolver: switchboard[`did${baseName}`].bind(switchboard),
        };
      });
    });

    baseNames.forEach(baseName => {
      it(`resolves the correct Promise for ${baseName}`, async function() {
        const allPromises = [];
        const positiveResults = [];
        const negativeResults = [];

        let positiveResolver = null;
        const negativeResolvers = [];

        const subscriptions = new CompositeDisposable();

        for (let i = 0; i < functionTriples.length; i++) {
          const functionTriple = functionTriples[i];

          if (functionTriple.baseName === baseName) {
            const positivePromise = functionTriple.getter().then(payload => {
              positiveResults.push(payload);
            });
            allPromises.push(positivePromise);

            positiveResolver = functionTriple.resolver;

            const positiveSubscription = functionTriple.subscriber(payload => positiveResults.push(payload));
            subscriptions.add(positiveSubscription);
          } else {
            const negativePromise = functionTriple.getter().then(payload => {
              negativeResults.push(payload);
            });
            allPromises.push(negativePromise);

            negativeResolvers.push(functionTriple.resolver);

            const negativeSubscription = functionTriple.subscriber(payload => negativeResults.push(payload));
            subscriptions.add(negativeSubscription);
          }
        }

        // Resolve positive resolvers with "yes" and negative resolvers with "no"
        positiveResolver('yes');
        negativeResolvers.forEach(resolver => resolver('no'));

        await Promise.all(allPromises);

        subscriptions.dispose();

        assert.lengthOf(positiveResults, 2);
        assert.isTrue(positiveResults.every(result => result === 'yes'));

        assert.lengthOf(negativeResults, (baseNames.length - 1) * 2);
        assert.isTrue(negativeResults.every(result => result === 'no'));
      });
    });
  });
});
