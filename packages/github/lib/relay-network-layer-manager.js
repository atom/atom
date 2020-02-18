import util from 'util';
import {Environment, Network, RecordSource, Store} from 'relay-runtime';
import moment from 'moment';

const LODASH_ISEQUAL = 'lodash.isequal';
let isEqual = null;

const relayEnvironmentPerURL = new Map();
const tokenPerURL = new Map();
const fetchPerURL = new Map();

const responsesByQuery = new Map();

function logRatelimitApi(headers) {
  const remaining = headers.get('x-ratelimit-remaining');
  const total = headers.get('x-ratelimit-limit');
  const resets = headers.get('x-ratelimit-reset');
  const resetsIn = moment.unix(parseInt(resets, 10)).from();

  // eslint-disable-next-line no-console
  console.debug(`GitHub API Rate Limit: ${remaining}/${total} — resets ${resetsIn}`);
}

export function expectRelayQuery(operationPattern, response) {
  let resolve, reject;
  const handler = typeof response === 'function' ? response : () => ({data: response});

  const promise = new Promise((resolve0, reject0) => {
    resolve = resolve0;
    reject = reject0;
  });

  const existing = responsesByQuery.get(operationPattern.name) || [];
  existing.push({
    promise,
    handler,
    variables: operationPattern.variables || {},
    trace: operationPattern.trace,
  });
  responsesByQuery.set(operationPattern.name, existing);

  const disable = () => responsesByQuery.delete(operationPattern.name);

  return {promise, resolve, reject, disable};
}

export function clearRelayExpectations() {
  responsesByQuery.clear();
  relayEnvironmentPerURL.clear();
  tokenPerURL.clear();
  fetchPerURL.clear();
  responsesByQuery.clear();
}

function createFetchQuery(url) {
  if (atom.inSpecMode()) {
    return function specFetchQuery(operation, variables, _cacheConfig, _uploadables) {
      const expectations = responsesByQuery.get(operation.name) || [];
      const match = expectations.find(expectation => {
        if (isEqual === null) {
          // Lazily require lodash.isequal so we can keep it as a dev dependency.
          // Require indirectly to trick electron-link into not following this.
          isEqual = require(LODASH_ISEQUAL);
        }

        return isEqual(expectation.variables, variables);
      });

      if (!match) {
        // eslint-disable-next-line no-console
        console.log(
          `GraphQL query ${operation.name} was:\n  ${operation.text.replace(/\n/g, '\n  ')}\n` +
          util.inspect(variables),
        );

        const e = new Error(`Unexpected GraphQL query: ${operation.name}`);
        e.rawStack = e.stack;
        throw e;
      }

      const responsePromise = match.promise.then(() => {
        return match.handler(operation);
      });

      if (match.trace) {
        // eslint-disable-next-line no-console
        console.log(`[Relay] query "${operation.name}":\n${operation.text}`);
        responsePromise.then(result => {
          // eslint-disable-next-line no-console
          console.log(`[Relay] response "${operation.name}":`, result);
        }, err => {
          // eslint-disable-next-line no-console
          console.error(`[Relay] error "${operation.name}":\n${err.stack || err}`);
          throw err;
        });
      }

      return responsePromise;
    };
  }

  return async function fetchQuery(operation, variables, _cacheConfig, _uploadables) {
    const currentToken = tokenPerURL.get(url);

    let response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'Authorization': `bearer ${currentToken}`,
          'Accept': 'application/vnd.github.antiope-preview+json',
        },
        body: JSON.stringify({
          query: operation.text,
          variables,
        }),
      });
    } catch (e) {
      // A network error was encountered. Mark it so that QueryErrorView and ErrorView can distinguish these, because
      // the errors from "fetch" are TypeErrors without much information.
      e.network = true;
      e.rawStack = e.stack;
      throw e;
    }

    try {
      atom && atom.inDevMode() && logRatelimitApi(response.headers);
    } catch (_e) { /* do nothing */ }

    if (response.status !== 200) {
      const e = new Error(`GraphQL API endpoint at ${url} returned ${response.status}`);
      e.response = response;
      e.responseText = await response.text();
      e.rawStack = e.stack;
      throw e;
    }

    const payload = await response.json();

    if (payload && payload.errors && payload.errors.length > 0) {
      const e = new Error(`GraphQL API endpoint at ${url} returned an error for query ${operation.name}.`);
      e.response = response;
      e.errors = payload.errors;
      e.rawStack = e.stack;
      throw e;
    }

    return payload;
  };
}

export default class RelayNetworkLayerManager {
  static getEnvironmentForHost(endpoint, token) {
    const url = endpoint.getGraphQLRoot();
    let {environment, network} = relayEnvironmentPerURL.get(url) || {};
    tokenPerURL.set(url, token);
    if (!environment) {
      if (!token) {
        throw new Error(`You must authenticate to ${endpoint.getHost()} first.`);
      }

      const source = new RecordSource();
      const store = new Store(source);
      network = Network.create(this.getFetchQuery(endpoint, token));
      environment = new Environment({network, store});

      relayEnvironmentPerURL.set(url, {environment, network});
    }
    return environment;
  }

  static getFetchQuery(endpoint, token) {
    const url = endpoint.getGraphQLRoot();
    tokenPerURL.set(url, token);
    let fetch = fetchPerURL.get(url);
    if (!fetch) {
      fetch = createFetchQuery(url);
      fetchPerURL.set(fetch);
    }
    return fetch;
  }
}
