import ActionPipelineManager, {ActionPipeline} from '../lib/action-pipeline';

describe('ActionPipelineManager', function() {
  it('manages pipelines for a set of actions', function() {
    const actionNames = ['ONE', 'TWO'];
    const manager = new ActionPipelineManager({actionNames});

    assert.ok(manager.getPipeline(manager.actionKeys.ONE));
    assert.ok(manager.getPipeline(manager.actionKeys.TWO));
    assert.throws(() => manager.getPipeline(manager.actionKeys.THREE), /not a known action/);

    const pipeline = manager.getPipeline(manager.actionKeys.ONE);
    assert.equal(manager.actionKeys.ONE, pipeline.actionKey);
  });
});

describe('ActionPipeline', function() {
  let pipeline;
  beforeEach(function() {
    pipeline = new ActionPipeline(Symbol('TEST_ACTION'));
  });

  it('runs actions with no middleware', async function() {
    const base = (a, b) => {
      return Promise.resolve(a + b);
    };
    const result = await pipeline.run(base, null, 1, 2);
    assert.equal(result, 3);
  });

  it('requires middleware to have a name', function() {
    assert.throws(() => pipeline.addMiddleware(null, () => null), /must be registered with a unique middleware name/);
  });

  it('only allows a single instance of a given middleware based on name', function() {
    pipeline.addMiddleware('testMiddleware', () => null);
    assert.throws(() => pipeline.addMiddleware('testMiddleware', () => null), /testMiddleware.*already registered/);
  });

  it('registers middleware to run around the function', async function() {
    const capturedArgs = [];
    const capturedResults = [];
    const options = {a: 1, b: 2};

    pipeline.addMiddleware('testMiddleware1', (next, model, opts) => {
      capturedArgs.push([opts.a, opts.b]);
      opts.a += 1;
      opts.b += 2;
      const result = next();
      capturedResults.push(result);
      return result + 1;
    });

    pipeline.addMiddleware('testMiddleware2', (next, model, opts) => {
      capturedArgs.push([opts.a, opts.b]);
      opts.a += 'a';
      opts.b += 'b';
      const result = next();
      capturedResults.push(result);
      return result + 'c';
    });

    const base = ({a, b}) => a + b;
    const result = await pipeline.run(base, null, options);
    assert.deepEqual(capturedArgs, [[1, 2], [2, 4]]);
    assert.deepEqual(capturedResults, ['2a4b', '2a4bc']);
    assert.equal(result, '2a4bc1');
  });
});
