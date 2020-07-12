/**
 * A lightweight wrapper around units of work. Provides a uniform interface and set of logging tools,
 * allowing them to be composed into more complicated sequences with configurable output.
 *
 * The same Task instance is typically shared between all invocations of the Task, so do not store state
 * on the instance itself.
 *
 * A Task takes in arguments passed to start, and returns the result of that Task as a promise that resolves to
 * the return value of that Task, or the return value itself if it is already a promise.
 *
 * It is an error to use logging methods when it is possible different tasks are also logging. For example,
 * launching two Tasks without waiting for the first to finish will result in jumbled output. Concurrent
 * Task execution is not yet implemented.
 *
 * Any external required modules should be fetched inside the Task `run` method. Tasks are intended to be used
 * even for bootstrapping, so pulling in dependencies outside of the Task body may cause exceptions if they
 * have not been installed yet.
 */
class Task {
  constructor(name) {
    /** A human readable name for what this Task does. */
    this.name = name;

    /** A prefix to apply to all print operations. Adjusted appropriately when this is called by a parent Task. */
    this.indent = "";
  }

  /** Indicate that execution may continue if this Task throws an error. */
  canFail() {
    return false;
  }

  /** Indicate that this Task should be skipped. Passed the same arguments as `run` would be. Returning a string will print that string as the reason for skipping. May be a value instead. Must be synchronous. */
  skip() {
    return false;
  }

  /** The body of execution for the Task. Override this when defining a new Task. Do not call directly, use `start` instead. Arguments may be passed via the `start` method. */
  run() {
    throw new Error("Task must override `run` method");
  }

  /** The way to make a Task start running. Arguments passed here will be given to the `run` method. The return value of the `run` method will be wrapped in a promise and returned. */
  async start(...args) {
    let skip = this.skip;
    if (typeof skip === "function") {
      skip = skip(...args);
    }

    if (skip) {
      if (typeof skip === "string") {
        this.print(`Skipping ${this.name}: ${skip}`, "?");
      } else {
        this.print(`Skipping ${this.name}`, "?");
      }
      return;
    }

    this.print(`Running ${this.name}`, ">");

    try {
      return this.run(...args);
    } catch (e) {
      if ((typeof this.canFail === "function" && this.canFail(e)) || this.canFail) {
        this.warn(`Task failed: ${e.msg}`);
        return;
      }
      throw e;
    }
  }

  /** Used to launch a Task inside this Task's `run` method. The first argument is the task to launch, the others and return value are the same as `start`. */
  async subtask(task, ...args) {
    const oldIndent = task.indent;
    task.indent = this.indent + "  ";
    const result = task.start(...args);
    result.finally(() => task.indent = oldIndent);
    return result;
  }

  /** Log information that is gratuitous. */
  silly(msg) {
    this.print(msg, "  :");
  }

  /** Log information that is possibly useful to debug the task, but not needed on normal runs. */
  verbose(msg) {
    this.print(msg, "  *");
  }

  /** Log information that is useful to see during execution. */
  info(msg) {
    this.print(msg, "  -");
  }

  /** Indicate that a recoverable problem occurred. E.g., an expected file was missing, but might not be needed anyways. */
  warn(msg) {
    this.print(msg, "!");
  }

  /** Indicate that an unrecoverable problem occurred. See `canFail` to indicate if this should propagate to the parent Task (as an exception), or silently resolve this Task. */
  error(msg) {
    this.print(msg, "  !!!");
  }

  /** Log the current work being done by this Task. Typically for work that is not a Task itself. */
  update(msg) {
    this.print(msg, "  >>");
  }

  /** Raw method to log to console. Not intended for direct use, see the `info`, `warn`, `update`, etc. methods instead. */
  print(msg, point=">") {
    console.log(`${this.indent}${point} ${msg}`);
  }
}

/**
 * Convenience function to convert existing function based work to Task based.
 * Takes the name of the new Task, and the function that will be uses as it's
 * `run` method. Also takes a third parameter to set other properties like `skip`
 * and `canFail`.
 *
 * The context of the `run` argument will be bound to the Task instance. Note that
 * lambda functions have lexical this scope and will not be bound correctly.
 */
function taskify(name, run, other={}) {
  const task = new Task(name);
  task.run = run.bind(task);
  if (typeof other.skip === "function") {
    task.skip = other.skip.bind(task);
  }
  if (other.canFail) {
    task.canFail = other.canFail;
  }
  return task;
}

module.exports = {Task, TaskGroup, taskify};
