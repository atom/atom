/**
 * Manages a task hierarchy. Each Task belongs to a manager,
 * and many of it's methods delegate to this manager. This
 * is not entirely necessary right now, but should make
 * tracking concurrent task execution easier.
 *
 * This should be constructed and the `subtask` method used
 * to get a root task object. Other methods are internal and
 * only for use by the private Task methods. There is no need
 * to use this further after creating the root task.
 */
class TaskManager {
  constructor() {
    this.active = new Set();
    this.focus = undefined;
    this.concurrentTasks = false;
  }

  subtask(parent) {
    return new Task(this, parent);
  }

  start(task) {
    this.active.add(task);

    if (this.focus === undefined) {
      this.focus = task;
    } else if (this.focus === task.parent) {
      this.focus = task;
    } else {
      this.concurrentTasks = true;
    }

    if (task.depth === 0) {
      this.print(task, '', `Running: ${task.name}`);
    } else if (task.depth === 1) {
      this.print(task, '##[group]', task.name);
    } else {
      task.log(`Starting '${task.name}' subtask`);
    }
  }

  done(task) {
    this.active.delete(task);
    if (task.parent) {
      task.parent.remove(task);
    }

    if (task.depth === 0) {
      this.print(task, '', `Finished: ${task.name}`);
    } else if (task.depth === 1) {
      this.print(task, '##[endgroup]', '');
    } else {
      task.log(`Finished '${task.name}' subtask`);
    }

    if (task === this.focus) {
      this.focus = task.parent;
    } else if (!this.concurrentTasks) {
      console.error('INCONSISTENT TASK STATE: Done task is not focused');
    }

    for (const child of task.children) {
      if (!child.complete) {
        console.error('INCONSISTENT TASK STATE: Child not done');
      }
    }
  }

  print(task, prefix, msg) {
    console.log(prefix + ' ' + msg);
  }

  debug() {
    console.log(`TaskManager stats:`);
    console.log(`Active tasks: ${this.active.size}`);
    console.log(`Is concurrent: ${this.concurrentTasks}`);
    for (const task of this.active) {
      let info = `- ${task.debug()}`;
      if (this.focus === task) {
        info += ' (focused)';
      }
      console.log(info);
    }
  }
}

/**
 * A lightweight interface to units of work. Primarily provides
 * a uniform interface for different logging methods. Do not
 * construct directly, rather use the `subtask` method to build
 * a child task or get a root task from a TaskManager.
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
  constructor(manager, parent = undefined) {
    this.manager = manager;
    this.parent = parent;
    this.children = [];
    this.name = 'Unnamed';
    this.complete = false;

    if (!this.parent) {
      this.depth = 0;
    } else {
      this.depth = this.parent.depth + 1;
    }
  }

  /**
   * Internal method to debug the task state
   */
  debug() {
    let info = `Name: ${this.name}, Children: ${this.children.length}`;
    if (!this.parent) {
      info += ' (root)';
    }
    return info;
  }

  /**
   * Create a subtask with this one as a parent. Note that
   * creation does not imply activaton. You must call the
   * `start` method with the task name to have it be active.
   *
   * @return {Task} Child task
   */
  subtask() {
    const child = this.manager.subtask(this);
    this.children.push(child);
    return child;
  }

  /**
   * Remove a child task from the active children list.
   *
   * @param  {Task} child Child task of this task
   */
  remove(child) {
    const index = this.children.indexOf(child);
    if (index < 0) {
      this.error('Invalid task state');
      return;
    }
    this.children.splice(index, 1);
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
    this.manager.start(this);
  }

  /**
   * Mark this task as done. A task should be marked done
   * when it has no further work associated with it. For
   * async work, this means it should be called after all
   * promises have resolved. A task must no longer use the
   * logging methods after calling this method.
   */
  done() {
    this.complete = true;
    this.manager.done(this);
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
    this.print('##[debug]', msg.join(' '));
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
    this.print('##[debug]', msg);
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
    this.print('##[warning]', msg);
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
    this.print('##[error]', msg);
  }

  /**
   * @private Internal method to print a message.
   * Delegates to the TaskManager.
   *
   * @param  {String} prefix Prefix of log entry
   * @param  {String} msg    Message for log entry
   */
  print(prefix, msg) {
    this.manager.print(this, prefix, msg);
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
  Task,
  TaskManager
};
