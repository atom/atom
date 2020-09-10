class TaskManager {
  constructor() {
    this.active = new Set();
    this.focus = undefined;
    this.concurrentTasks = false;
  }

  subtask(parent) {
    const subtask = new Task(this, parent);
    return subtask;
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

    this.print(task, '##[group]', task.name);
  }

  done(task) {
    this.active.delete(task);
    if (task.parent) {
      task.parent.remove(task);
    }

    this.print(task, '##[endgroup]', '');

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
    console.log(prefix + msg);
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
 * a uniform interface for different logging methods.
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

  debug() {
    let info = `Name: ${this.name}, Children: ${this.children.length}`;
    if (!this.parent) {
      info += ' (root)';
    }
    return info;
  }

  subtask() {
    const child = this.manager.subtask(this);
    this.children.push(child);
    return child;
  }

  remove(child) {
    const index = this.children.indexOf(child);
    if (index < 0) {
      this.error('Invalid task state');
      return;
    }
    this.children.splice(index, 1);
  }

  start(name) {
    this.name = name;
    this.manager.start(this);
  }

  done() {
    this.complete = true;
    this.manager.done(this);
  }

  verbose(msg) {
    this.print('##[debug]', msg);
  }

  log(...msg) {
    this.info(msg.join(' '));
  }

  info(msg) {
    this.print('##[debug]', msg);
  }

  warn(msg) {
    this.warning(msg);
  }

  warning(msg) {
    this.print('##[warning]', msg);
  }

  error(msg) {
    this.print('##[error]', msg);
  }

  print(prefix, msg) {
    this.manager.print(this, prefix, msg);
  }
}

module.exports = {
  Task,
  TaskManager
};
