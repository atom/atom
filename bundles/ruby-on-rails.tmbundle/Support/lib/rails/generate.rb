
class Generator
  @@list = []
  attr_accessor :name, :question, :default_answer

  def initialize(name, question, default_answer = "")
    @@list << self
    @name, @question, @default_answer = name, question, default_answer
  end

  def self.[](name, question, default_answer = "")
    g = new(name, question, default_answer)
  end

  def self.setup
    @@list = setup_generators
  end

  # Collect the names from each generator
  def self.names
    @@list.map { |g| g.name.capitalize }
  end

  def self.generators
    @@list
  end

  def self.setup_generators
    known_generator_names = known_generators.map { |gen| gen.name }
    new_generator_names = find_generator_names - known_generator_names
    known_generators + new_generator_names.map do |name|
      Generator[name, "Arguments for #{name} generator:", ""]
    end
  end

  # Runs the script/generate command and extracts generator names from output
  def self.find_generator_names
    list = nil
    FileUtils.chdir(RailsPath.new.rails_root) do
      output = ruby 'script/generate | grep "^  [A-Z]" | sed -e "s/  //"'
      list = output.split(/[,\s]+/).reject {|f| f =~ /:/}
    end
    list
  end

  def self.known_generators
    [
      Generator["scaffold",   "Name of the model to scaffold:", "User"],
      Generator["controller", "Name the new controller:",       "admin/user_accounts"],
      Generator["model",      "Name the new model:",            "User"],
      Generator["mailer",     "Name the new mailer:",           "Notify"],
      Generator["migration",  "Name the new migration:",        "CreateUserTable"],
      Generator["plugin",     "Name the new plugin:",           "ActsAsPlugin"]
    ]
  end
end
