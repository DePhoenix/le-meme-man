class ChatHandler
  attr_accessor :triggers, :ignorelist
  
  def initialize
    @triggers = []
    @ignorelist = []
  end
  
  def self.make_info message, ws
    info = {where: message[1], ws: ws}
    
    info.merge!(if info[:where] == 'c'
      {
        room: message[0][1..-2],
        who: message[2][1..-1],
        what: message[3],
      }
    elsif info[:where] == 'pm'
      {
        what: message[4],
        to: message[3][1..-1],
        who: message[2][1..-1],
      }
    elsif info[:where] = 's'
      {
        room: $room,
        who: $login[:name],
        what: message[1],
      }
    end)
    
    info
  end
  
  
  def handle message, ws
    m_info = self.class.make_info(message, ws)
    @ignorelist.map(&:downcase).index(m_info[:who].downcase) and return
    @triggers.each do |t|
      t[:off] and next
      result = t.is_match?(m_info)
      
      if result
        m_info[:result] = result
        m_info[:respond] = if m_info[:where] == 'c' || m_info[:where] == 's'
          proc { |mtext| m_info[:ws].send("#{m_info[:room]}|#{mtext}") }
        elsif m_info[:where] == 'pm'
          proc { |mtext| m_info[:ws].send("|/pm #{m_info[:who]},#{mtext}") } 
        end 
        
        # log the action
        if t[:id] && !t[:nolog] # only log triggers with IDs
          $usage_log.info("#{m_info[:who]} tripped trigger id:#{t[:id]}")
        end
        
        t.do_act(m_info)
        
      end
      
    end
  end
  
  def turn_by_id id, on
    @triggers.each do |t|
      if t[:id] == id
        t[:off] = !on
        return true
      end
    end
    
    false
  end
  
  def << trigger
    @triggers.push(trigger)
    self
  end

end

class Trigger
  
  def initialize &blk
    @vars = {}
    yield self
  end
  
  def match &blk
    @match = blk
  end
  
  def act &blk
    @action = blk
  end
  
  def is_match? m_info
    @match.call(m_info)
  end
  
  def do_act m_info
    @action.call(m_info)
  end
  
  def get var
    @vars[var]
  end
  
  def set var, to
    @vars[var] = to
  end
  
  alias_method :[], :get
  alias_method :[]=, :set
end


FileUtils.touch("ignored.txt")
$chat = ChatHandler.new
$chat.ignorelist = IO.readlines("ignored.txt")

# require all trigger files here

require './statcalc/statcalc_trigger.rb'
require './pokemon-related/randbats_trigger.rb'
require './fsymbols/fsymbols_trigger.rb'
require './bread/bread_trigger.rb'
require './bread/battle_reporter_trigger.rb'
require './friendcode/fc_trigger.rb'