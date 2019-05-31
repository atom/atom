const { userAgent } = process.env;
const [compileCachePath, taskPath] = process.argv.slice(2);

const CompileCache = require('./compile-cache');
CompileCache.setCacheDirectory(compileCachePath);
CompileCache.install(`${process.resourcesPath}`, require);

const setupGlobals = function() {
  global.attachEvent = function() {};
  const console = {
    warn() {
      return global.emit('task:warn', ...arguments);
    },
    log() {
      return global.emit('task:log', ...arguments);
    },
    error() {
      return global.emit('task:error', ...arguments);
    },
    trace() {}
  };
  global.__defineGetter__('console', () => console);

  global.document = {
    createElement() {
      return {
        setAttribute() {},
        getElementsByTagName() {
          return [];
        },
        appendChild() {}
      };
    },
    documentElement: {
      insertBefore() {},
      removeChild() {}
    },
    getElementById() {
      return {};
    },
    createComment() {
      return {};
    },
    createDocumentFragment() {
      return {};
    }
  };

  global.emit = (event, ...args) => process.send({ event, args });
  global.navigator = { userAgent };
  return (global.window = global);
};

const handleEvents = function() {
  process.on('uncaughtException', error =>
    console.error(error.message, error.stack)
  );

  return process.on('message', function({ event, args } = {}) {
    if (event !== 'start') {
      return;
    }

    let isAsync = false;
    const async = function() {
      isAsync = true;
      return result => global.emit('task:completed', result);
    };
    const result = handler.bind({ async })(...args);
    if (!isAsync) {
      return global.emit('task:completed', result);
    }
  });
};

const setupDeprecations = function() {
  const Grim = require('grim');
  return Grim.on('updated', function() {
    const deprecations = Grim.getDeprecations().map(deprecation =>
      deprecation.serialize()
    );
    Grim.clearDeprecations();
    return global.emit('task:deprecations', deprecations);
  });
};

setupGlobals();
handleEvents();
setupDeprecations();
const handler = require(taskPath);
