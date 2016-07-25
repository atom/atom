# Open a sub-process and return 3 IO objects: stdin, stdout, stderr
# Unlike Open3::popen3, it produces a child, not a grandchild
def popen3(*args)
  stdin, stdout, stderr = [IO.pipe, IO.pipe, IO.pipe]
  fork do
    stdin[1].close
    STDIN.reopen(stdin[0])
    stdin[0].close
    
    stdout[0].close
    STDOUT.reopen(stdout[1])
    stdout[1].close
    
    stderr[0].close
    STDERR.reopen(stderr[1])
    stderr[1].close
    
    exec(*args)
  end
  stdin[0].close
  stdout[1].close
  stderr[1].close
  [stdin[1], stdout[0], stderr[0]]
end
