# coding: utf-8

class Parser < Lexer
  def initialize(string, lookup)
    super(string)
    @lookup = lookup
  end

  def self.parse(string, lookup)
    Parser.new(string, lookup).parse
  end

  def parse
    # Check if first token is a group
    if scan /^\s*(.+?)\s+(.+?)$/i
      group = self[1]
      if @lookup.is_group? group
        rest = StringScanner.new self[2]

        # Invite
        if rest.scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+(.+?)$/i
          return InviteNode.new :group => group, :users => rest[1].split.without_prefix!('+')
        end

        # Block
        if rest.scan /^\s*(?:#|\.)*?\s*block\s+(\S+)$/i
          return BlockNode.new :group => group, :user => rest[1]
        end

        # Owner
        if rest.scan /^\s*(?:#|\.)*?\s*(?:owner|.owner|.ow|#owner|#ow)\s+(\S+)$/i
          return OwnerNode.new :group => group, :user => rest[1]
        elsif rest.scan /^\s*\$\s*(\S+)$/i
          return OwnerNode.new :group => group, :user => rest[1]
        end

        return MessageNode.new :targets => [group], :body => rest.string
      end

      unscan
    end

    # Help
    if scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s*$/i
      return HelpNode.new
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(owner|group\s+owner|owner\s+group|.ow|#ow|\.owner|#owner)\s*$/i
      return HelpNode.new :node => OwnerNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(block)\s*$/i
      return HelpNode.new :node => BlockNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(lang|_)\s*$/i
      return HelpNode.new :node => LanguageNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:create\s+group|create|creategroup|cg|\*)\s*$/i
      return HelpNode.new :node => CreateGroupNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:join\s+group|join|joingroup|j|>)\s*$/i
      return HelpNode.new :node => JoinNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:leave\s+group|leave|leavegroup|l|<)\s*$/i
      return HelpNode.new :node => LeaveNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:login|log\s+in|li|iam|i\s+am|i'm|im|\()\s*$/i
      return HelpNode.new :node => LoginNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(logout|log\s*out|lo|bye|\))\s*$/i
      return HelpNode.new :node => LogoutNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(stop|off)\s*$/i
      return HelpNode.new :node => OffNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(start|on)\s*$/i
      return HelpNode.new :node => OnNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(name|n)\s*$/i
      return HelpNode.new :node => SignupNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(whois|wh)\s*$/i
      return HelpNode.new :node => WhoIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(whereis|wi)\s*$/i
      return HelpNode.new :node => WhereIsNode
    end

    # Message with location
    if scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+)(?:\s*°\s*|\s+)(\d+)?(?:\s*'\s*|\s+)(\d+)?(?:\s*''\s*|\s*)(N|S)?\s*\*?\s*(E|W)?\s*((?:\+|\-)?\s*\d+)(?:\s*°\s*|\s*)(\d+)?(?:\s*'\s*|\s*)(\d+)?(?:\s*''\s*|\s*)(E|W)?\s*$/i
      sign0 = self[1] == 'S' || self[5] == 'S' ? -1 : 1
      sign1 = self[6] == 'W' || self[10] == 'W' ? -1 : 1
      loc = location(self[2].gsub(/\s/, ''), self[3], self[4], self[7].gsub(/\s/, ''), self[8], self[9])
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      return MessageNode.new :location => loc
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*(N|S)?(?:\s*\*\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*(E|W)?\s*$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = [self[2].gsub(/\s/, '').to_f, self[5].gsub(/\s/, '').to_f]
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      return MessageNode.new :location => loc
    elsif scan /^\s*(?:at|l:)\s+(.+?)(?:\s*\*)?\s*$/i
      return MessageNode.new :location => self[1]
    elsif scan /^\s*(.+?)\s*\*\s*$/i
      return MessageNode.new :location => self[1]
    end

    # Signup
    if scan /^\s*(?:#|\.)*?\s*(?:name|n)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => SignupNode
    elsif scan /^\s*(?:#|\.)*?\s*name\s*@?(.+?)\s*$/i
      return new_signup self[1].strip
    elsif scan /^\s*(?:#|\.)+\s*n\s*@?(.+?)\s*$/i
      return new_signup self[1].strip
    elsif scan /^\s*'(.+)'?$/i
      str = self[1].strip
      str = str[0 ... -1] if str[-1] == "'"
      return new_signup str.strip
    end

    # Login
    if scan /^\s*(?:#|\.)*?\s*(?:login|log\s+in|li|iam|i\s+am|i'm|im|\()(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => LoginNode
    elsif scan /^\s*(?:#|\.)*?\s*(?:login|log\s+in|li|iam|i\s+am|i'm|im|\()\s*(?:@\s*)?(.+?)\s+(.+?)\s*$/i
      return LoginNode.new :login => self[1], :password => self[2]
    elsif scan /^\s*(?:#|\.)*?\s*(.im)(\s+\S+)?\s*$/i
      return HelpNode.new :node => LoginNode
    end

    # Logout
    if scan /^\s*(?:#|\.)*?\s*(logout|log\s*out|lo|bye|\))\s+(help|\?)\s*$/i
      return HelpNode.new :node => LogoutNode
    elsif scan /^\s*(?:#|\.)*?\s*(logout|log\s*out|lo|bye)\s*$/i
      return LogoutNode.new
    elsif scan /^\s*\)\s*$/i
      return LogoutNode.new
    end

    # On
    if scan /^\s*(?:#|\.)*?\s*(on|start)\s+(help|\?)\s*$/i
      return HelpNode.new :node => OnNode
    elsif scan /^\s*(?:#|\.)*?\s*(on|start)\s*/i
      return OnNode.new
    elsif scan /^\s*\!\s*$/i
      return OnNode.new
    end

    # Off
    if scan /^\s*(?:#|\.)*?\s*(off|stop)\s+(help|\?)\s*$/i
      return HelpNode.new :node => OffNode
    elsif scan /^\s*(?:#|\.)*?\s*(off|stop)\s*$/i
      return OffNode.new
    elsif scan /^\s*-\s*$/i
      return OffNode.new
    end

    # Create group
    if scan /^\s*(?:#|\.)*?\s*(?:create\s+group|create|creategroup|cg|\*)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => CreateGroupNode
    elsif scan /^\s*(?:#|\.)*?\s*(?:create\s+group|create|creategroup|cg)\s+(?:@\s*)?(.+?)(\s+.+?)?$/i
      return new_create_group self[1], self[2]
    elsif scan /^\s*\*\s*(?:@\s*)?(.+?)(\s+.+?)?$/i
      return new_create_group self[1], self[2]
    end

    # Invite
    if scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => InviteNode
    elsif scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+\+?(\d+\s+\+?\d+\s+.+?)$/i
      users = self[1].split.without_prefix! '+'
      return InviteNode.new :users => users
    elsif scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+\+?(\d+)\s+(?:@\s*)?(.+?)$/i
      return InviteNode.new :users => [self[1].strip], :group => self[2].strip
    elsif scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+(?:@\s*)?(.+?)\s+\+?(\d+\s*.*?)$/i
      group = self[1].strip
      users = self[2].split.without_prefix! '+'
      return InviteNode.new :users => users, :group => group
    elsif scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+@\s*(.+?)\s+(.+?)$/i
      users = [self[1].strip]
      group = self[2].strip
      return InviteNode.new :users => users, :group => group
    elsif scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+(.+?)$/i
      pieces = self[1].split.without_prefix! '@'
      group, *users = pieces
      group, users = nil, [group] if users.empty?
      return InviteNode.new :users => users, :group => group
    elsif scan /^\s*@\s*(.+?)\s+(?:invite|\.invite|\#invite|\.i|\#i)\s+(.+?)$/i
      users = self[2].split
      return InviteNode.new :users => users, :group => self[1].strip
    elsif scan /^\s*\+\s*(.+?)$/i
      return InviteNode.new :users => self[1].split
    elsif scan /^\s*@\s*(.+?)\s+\+\s*(.+?)$/i
      return InviteNode.new :users => self[2].split, :group => self[1].strip
    end

    # Join
    if scan /^\s*(?:join|join\s+group|\.\s*j|\.\s*join|\#\s*j|\#\s*join|>)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => JoinNode
    elsif scan /^\s*(?:join|join\s+group|\.\s*j|\.\s*join|\#\s*j|\#\s*join)\s+(?:@\s*)?(\S+)$/i
      return JoinNode.new :group => self[1]
    elsif scan /^\s*>\s*(?:@\s*)?(\S+)$/i
      return JoinNode.new :group => self[1]
    end

    # Leave
    if scan /^\s*(?:leave|leave\s+group|\.\s*l|\.\s*leave|\#\s*l|\#\s*leave|<)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => LeaveNode
    elsif scan /^\s*(?:leave|leave\s+group|\.\s*l|\.\s*leave|\#\s*l|\#\s*leave)\s+(?:@\s*)?(\S+)$/i
      return LeaveNode.new :group => self[1]
    elsif scan /^\s*<\s*(?:@\s*)?(\S+)$/i
      return LeaveNode.new :group => self[1]
    end

    # Block
    if scan /^\s*(?:#|\.)*?\s*block(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => BlockNode
    elsif scan /^\s*(?:#|\.)*?\s*block\s+(?:@\s*)?(\S+)$/i
      return BlockNode.new :user => self[1]
    elsif scan /^\s*(?:#|\.)*?\s*block\s+(\S+)\s+(\S+)$/i
      return BlockNode.new :user => self[1], :group => self[2]
    elsif scan /^\s*@\s*(\S+)\s*(?:#|\.)*?\s*block\s+(\S+)$/i
      return BlockNode.new :user => self[2], :group => self[1]
    end

    # Owner
    if scan /^\s*(?:#|\.)*?\s*(?:owner|ow)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => OwnerNode
    elsif scan /^\s*(?:#|\.)*?\s*(?:owner|ow)\s+(?:@\s*)?(\S+)$/i
      return OwnerNode.new :user => self[1]
    elsif scan /^\s*(?:#|\.)*?\s*(?:owner|ow)\s+(?:@\s*)?(\S+)\s+(?:\+\s*)?(\d+)$/i
      return OwnerNode.new :user => self[2], :group => self[1]
    elsif scan /^\s*(?:#|\.)*?\s*(?:owner|ow)\s+(?:@\s*)?(\S+)\s+(?:@\s*)?(\S+)$/i
      return OwnerNode.new :user => self[1], :group => self[2]
    elsif scan /^\s*@\s*(\S+)\s*(?:#|\.)*?\s*(?:owner|ow)\s+(\S+)$/i
      return OwnerNode.new :user => self[2], :group => self[1]
    elsif scan /^\s*\$\s*(\S+)\s*$/i
      return OwnerNode.new :user => self[1]
    elsif scan /^\s*\$\s*(\S+)\s+(\S+)\s*$/i
      return OwnerNode.new :user => self[1], :group => self[2]
    end

    # My
    if scan /^\s*(?:#|\.)*\s*my\s*$/i
      return HelpNode.new :node => MyNode
    elsif scan /^\s*(?:#|\.)*\s*my\s+groups\s*$/i
      return MyNode.new :key => MyNode::Groups
    elsif scan /^\s*(?:#|\.)*\s*my\s+(?:group|g)\s*$/i
      return MyNode.new :key => MyNode::Group
    elsif scan /^\s*(?:#|\.)*\s*my\s+(?:group|g)\s+(?:@\s*)?(\S+)\s*$/i
      return MyNode.new :key => MyNode::Group, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my\s+name\s*$/i
      return MyNode.new :key => MyNode::Name
    elsif scan /^\s*(?:#|\.)*\s*my\s+name\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Name, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my\s+email\s*$/i
      return MyNode.new :key => MyNode::Email
    elsif scan /^\s*(?:#|\.)*\s*my\s+email\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Email, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my\s+(number|phone|phonenumber|phone\s+number|mobile|mobilenumber|mobile\s+number)\s*$/i
      return MyNode.new :key => MyNode::Number
    elsif scan /^\s*(?:#|\.)*\s*my\s+location\s*$/i
      return MyNode.new :key => MyNode::Location
    elsif scan /^\s*(?:#|\.)*\s*my\s+location\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Location, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my\s+login\s*$/i
      return MyNode.new :key => MyNode::Login
    elsif scan /^\s*(?:#|\.)*\s*my\s+login\s+(\S+)\s*$/i
      return MyNode.new :key => MyNode::Login, :value => self[1]
    elsif scan /^\s*(?:#|\.)*\s*my\s+password\s*$/i
      return MyNode.new :key => MyNode::Password
    elsif scan /^\s*(?:#|\.)*\s*my\s+password\s+(\S+)\s*$/i
      return MyNode.new :key => MyNode::Password, :value => self[1]
    end

    # Who is
    if scan /^\s*(?:#|\.)*\s*(?:whois|wi)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => WhoIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:whois|wi)\s+(?:@\s*)?(.+?)\s*\??\s*$/i
      return WhoIsNode.new :user => self[1].strip
    end

    # Where is
    if scan /^\s*(?:#|\.)*\s*(?:whereis|wh)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => WhereIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:whereis|wh)\s+(?:@\s*)?(.+?)\s*\??\s*$/i
      return WhereIsNode.new :user => self[1].strip
    end

    # Language
    if scan /^\s*(?:#|\.)*\s*(?:lang|_)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => LanguageNode
    end


    # Message
    if scan /^\s*@\s*(.+?)\s+(.+?)$/i
      return MessageNode.new :body => self[2], :targets => [self[1]]
    end

    MessageNode.new :body => string
  end

  def new_signup(string)
    SignupNode.new :display_name => string, :suggested_login => string.gsub(/\s/, '_')
  end

  def new_create_group(group_alias, pieces)
    options = {:group => self[1], :public => false, :nochat => false}
    if pieces
      pieces = pieces.split
      in_name = false
      name = nil
      pieces.each do |piece|
        down = piece.downcase
        case down
        when 'name'
          in_name = true
          name = ''
        when 'nochat', 'alert'
          options[:nochat] = true
          in_name = false
        when 'public', 'nohide', 'visible'
          options[:public] = true
          in_name = false
        when 'chat', 'chatroom', 'hide', 'private'
          in_name = false
        else
          name << piece
          name << ' '
        end
      end
    end
    options[:name] = name.strip if name
    CreateGroupNode.new options
  end

  def location(*args)
    [deg(*args[0 .. 2]), deg(*args[3 .. 5])]
  end

  def deg(*args)
    first = args[0].to_f
    if first < 0
      -(-first + args[1].to_f / 60.0 + args[2].to_f / 3600.0)
    else
      first + args[1].to_f / 60.0 + args[2].to_f / 3600.0
    end
  end
end

class Node
  def initialize(attrs = {})
    attrs.each do |k, v|
      send "#{k}=", v
    end
  end
end

class SignupNode < Node
  attr_accessor :display_name
  attr_accessor :suggested_login
end

class LoginNode < Node
  attr_accessor :login
  attr_accessor :password
end

class LogoutNode < Node
end

class OnNode < Node
end

class OffNode < Node
end

class CreateGroupNode < Node
  attr_accessor :group
  attr_accessor :public
  attr_accessor :nochat
  attr_accessor :name
end

class InviteNode < Node
  attr_accessor :group
  attr_accessor :users
end

class JoinNode < Node
  attr_accessor :group
end

class LeaveNode < Node
  attr_accessor :group
end

class MessageNode < Node
  attr_accessor :body
  attr_accessor :targets
  attr_accessor :location
end

class HelpNode < Node
  attr_accessor :node
end

class BlockNode < Node
  attr_accessor :user
  attr_accessor :group
end

class OwnerNode < Node
  attr_accessor :user
  attr_accessor :group
end

class MyNode < Node
  attr_accessor :key
  attr_accessor :value

  Groups = :groups
  Group = :group
  Name = :name
  Email = :email
  Login = :login
  Password = :password
  Number = :number
  Location = :location
end

class WhoIsNode < Node
  attr_accessor :user
end

class WhereIsNode < Node
  attr_accessor :user
end

class LanguageNode < Node
  attr_accessor :name
end
