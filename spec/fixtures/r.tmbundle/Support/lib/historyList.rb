def extract_command(string)
  return "" if string.nil?
  return string.gsub(/^>\s*|\s*\z/,"")
end
class HistoryList
  attr_reader :list, :last_line, :text
  def initialize(text)
    @text = text.split("\n")
    @last_line = @text.pop
    @list = @text.grep(/^>(.*)$/).map{|m| extract_command(m)}.grep(/./)
    @list = @list.reverse.uniq.reverse
  end
  def next_item(command)
    cmd = extract_command(command)
    return @list[0] if cmd.empty?
    if i=@list.index(cmd)  and i<=@list.length then
      return @list[i+1]
    end
    return nil
  end
  def previous_item(command)
    cmd = extract_command(command)
    return @list.last if cmd.empty?
    if i=@list.index(cmd) and i>=1 then
      return @list[i-1]
    end
    return nil
  end
  def text
    @text.join("\n") + "\n"
  end
  def add_line(line)
    self.text + "> #{extract_command(line)}"
  end
  def move_up
    add_line(previous_item(@last_line))
  end
  def move_down
    add_line(next_item(@last_line))
  end
  def self.move_up(text)
    self.new(text).move_up
  end
  def self.move_down(text)
    self.new(text).move_down
  end
end
