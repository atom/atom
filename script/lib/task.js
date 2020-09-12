/**
 * A lightweight interface to units of work. Primarily provides
 * a uniform interface for different logging methods.
 *
 * Typical usage is as follows:
  ```
  function generateData(task) {
    task.start('Generate data');
    let data = [];

    task.log('Generating JS and CS data');
    data.push(...generateJsData(task.subtask()));
    data.push(...generateCsData(task.subtask()));

    if (data.length === 0) {
      task.warn('No data was generated');
    } else {
      task.log(`Generated ${data.length} datas`);
    }

    task.done();
    return data;
  }
  ```
 */
class Task {
  constructor({
    stack = [],
    parallel = false,
    format = undefined,
    childId = undefined
  } = {}) {
    /** Mark if this task has been started yet */
    this.started = false;

    /** Mark if this task has been declared done */
    this.finished = false;

    /** Count the number of child tasks derived from this one */
    this.numChildren = 0;

    /** Specifies how log levels are formatted, etc. */
    this.format = format || this.defaultFormat();

    /** Task stack (list of parent names, root task first) */
    this.stack = stack;

    /** Is this task running in parallel with other tasks */
    this.parallel = parallel;

    /** Name of this task (properly set when started) */
    this.name = 'child' + (childId !== undefined ? childId : '(unnamed)');
  }

  defaultFormat() {
    return {
      /** Minimum priority of messages to log. 0 is verbose, 3 is error. */
      minPriority: 1,

      /** Prepended to each log, repeated task depth times */
      indent: '',

      /** Prefix for verbose logs */
      verbose: '##[debug]',

      /** Prefix for info logs */
      info: '##[debug]',

      /** Prefix for warning logs */
      warn: '##[warning]',

      /** Prefix for error logs */
      error: '##[error]',

      /** Prefix for starting a new task */
      start: '##[group]',

      /** Prefix for ending a task */
      end: '##[endgroup]',

      /** Only use start and end prefixes for top level groups (not including root) */
      flat: true
    };
  }

  /**
   * @private Serialize this Task to a JSON format. This allows
   * it to be passed virtually anywhere, including worker threads
   * if necessary. It is also used as the parameters to making a
   * sub task.
   *
   * @return {JSON} JSON serialization of this Task
   */
  serialize() {
    return {
      stack: [...this.stack, this.name],
      parallel: this.parallel,
      format: this.format,
      childId: this.numChildren++
    };
  }

  /**
   * Create a subtask with this one as a parent. Note that
   * creation does not imply activaton. You must call the
   * `start` method with the task name to have it be active.
   *
   * @param params {{parallel: boolean}}
   *    - parallel: If the child task will be run in parallel
   *                with other tasks
   *
   * @return {Task} Child task
   */
  subtask({ parallel = false } = {}) {
    const sub = new Task(this.serialize());
    sub.parallel |= parallel;
    return sub;
  }

  /**
   * Start this task. This corresponds to printing
   * the task name to the log, and then further logging
   * is allowed via the `log`, `warn`, etc., methods.
   *
   * @param {String} name Name of this task
   */
  start(name) {
    this.name = name;
    this.started = true;
    this.printStart();
  }

  printStart() {
    if (!this.parallel && (!this.format.flat || this.stack.length === 1)) {
      this.print(Infinity, this.format.start, this.name);
    } else {
      this.print(Infinity, this.format.info, `Starting ${this.name}`);
    }
  }

  /**
   * Mark this task as done. A task should be marked done
   * when it has no further work associated with it. For
   * async work, this means it should be called after all
   * promises have resolved. A task must no longer use the
   * logging methods after calling this method.
   */
  done() {
    this.printDone();
    this.finished = true;
  }

  printDone() {
    if (!this.parallel && (!this.format.flat || this.stack.length === 1)) {
      this.print(Infinity, this.format.end, this.name);
    } else {
      this.print(Infinity, this.format.info, `Finished ${this.name}`);
    }
  }

  /**
   * Log a verbose message. This is something that
   * is not useful in regular builds, but could be
   * useful in identifying an error in the build
   * script.
   *
   * Multiple arguments will be joined by a space.
   *
   * @param  {...String} msg Message to log
   */
  verbose(...msg) {
    this.print(0, this.format.verbose, msg.join(' '));
  }

  /**
   * Log a 'plain' message. This is something that is
   * interesting, such as a status update on what a
   * task is doing, but does not indicate a problem.
   *
   * Synonym for `info`.
   * Multiple arguments will be joined by a space.
   *
   * @param  {...String} msg Message to log
   */
  log(...msg) {
    this.info(msg.join(' '));
  }

  /**
   * Log a 'plain' message. This is something that is
   * interesting, such as a status update on what a
   * task is doing, but does not indicate a problem.
   *
   * Synonym for `log`.
   * Multiple arguments will be joined by a space.
   *
   * @param  {...String} msg Message to log
   */
  info(msg) {
    this.print(1, this.format.info, msg);
  }

  /**
   * Log a warning message. This is something that is
   * potentially a problem, such as a program version
   * being outside of known good versions or a build
   * step having no items to work on.
   *
   * Multiple arguments will be joined by a space.
   *
   * @param  {...String} msg Warning to log
   */
  warn(msg) {
    this.print(2, this.format.warn, msg);
  }

  /**
   * Log an error message. This is something that is
   * definitely a problem, such that the build cannot
   * succeed if it occurs. Note this interface does
   * not actually stop anything; it is just a way of
   * logging the error.
   *
   * Multiple arguments will be joined by a space.
   *
   * @param  {...String} msg Error to log
   */
  error(msg) {
    this.print(3, this.format.error, msg);
  }

  /**
   * @private Internal method to print a message. Right
   * now just uses console.log, but could be changed to
   * log to a file instead, or do both.
   *
   * @param  {String} prefix Prefix of log entry
   * @param  {String} msg    Message for log entry
   */
  print(priority, prefix, msg) {
    if (priority < this.format.minPriority) {
      return;
    }

    if (!this.started || this.finished) {
      console.error('Invalid task state');
    }

    let out = this.format.indent.repeat(this.stack.length) + prefix;

    if (this.parallel) {
      out += ' ' + this.stack.join(':') + ':' + this.name + ':';
    }

    out += ' ' + msg;

    console.log(out);
  }
}

class DefaultTask {
  subtask() {
    return this;
  }

  start(_name) {
    // ignore
  }

  done() {
    // ignore
  }

  verbose(..._msg) {
    // ignore
  }

  info(...msg) {
    console.info(...msg);
  }

  log(...msg) {
    console.log(...msg);
  }

  warn(...msg) {
    console.warn(...msg);
  }

  error(...msg) {
    console.error(...msg);
  }
}

module.exports = {
  DefaultTask,
  Task
};
