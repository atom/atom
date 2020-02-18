// Danger! Danger! Metaprogramming bullshit ahead.

import {DeferredSpecBuilder} from './builder';

export {createSpecBuilderClass} from './create-spec-builder';
export {createUnionBuilderClass} from './create-union-builder';
export {createConnectionBuilderClass} from './create-connection-builder';

// Resolve circular dependencies among SpecBuilder classes by replacing one of the imports with a defer() call. The
// deferred Builder it returns will lazily require and locate the linked builder at first use.
export function defer(modulePath, className) {
  return new DeferredSpecBuilder(modulePath, className);
}
