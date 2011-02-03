# coding: utf-8

require 'strscan'

class Parser < StringScanner
  def initialize(string, lookup = nil, options = {})
    super(string)
    @lookup = lookup
    @parse_signup_and_join = options[:parse_signup_and_join]
  end

  def self.parse(string, lookup = nil, options = {})
    Parser.new(string, lookup, options).parse
  end

  def parse
    node = parse_node
    if node.is_a?(MessageNode) && node.body
      # Check mentions
      node.body.scan /\s+@\s*(\S+)/ do |match|
        node.mentions ||= []
        node.mentions << match.first
      end

      # Check tags
      node.body.scan /#\s*(\S+)/ do |match|
        node.tags ||= []
        node.tags << match.first
      end

      # Check locations
      node.body.scan /\s+\/[^\/]+\/|\s+\/\S+/ do |match|
        match = match.strip
        match = match[1 .. -1] if match.start_with?('/')
        ['/', ',', '.', ';'].each do |char|
          match = match[0 .. -2] if match.end_with?(char)
        end
        if match.present?
          node.locations ||= []
          node.locations << match
        end
      end

      # Check numeric locations
      node.locations.map!{|x| check_numeric_location x} if node.locations
    end
    node
  end

  def parse_node
    # Ping
    if scan /^\s*(?:#|\.)*?\s*ping\s*$/i
      return PingNode.new :text => nil
    elsif scan /^\s*(?:#|\.)*?\s*ping\s+(.+?)\s*$/i
      return PingNode.new :text => self[1].strip
    end

    options = {}
    options[:blast] = check_blast

    # Check if first token is a group
    if scan /^\s*(@)?\s*(.+?)\s+(.+?)$/i
      group = self[2]
      if (self[1] && target = UnknownTarget.new(group)) || (@lookup && target = @lookup.get_target(group))
        options[:targets] = [target]

        rest = StringScanner.new self[3]

        if !target.is_a?(UserTarget)
          # Invite
          if rest.scan /^\s*(?:invite|\.invite|\#invite|\.i|\#i)\s+(.+?)$/i
            return InviteNode.new :group => group, :users => rest[1].split.without_prefix!('+')
          elsif rest.scan /^\s*\+\s*(.+?)$/i
            return InviteNode.new :users => rest[1].split.without_prefix!('+'), :group => group
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
        end

        while rest.scan /^\s*(@)?\s*(.+?)\s+(.+?)$/i
          if rest[1]
            options[:targets] << UnknownTarget.new(rest[2])
            rest = StringScanner.new rest[3]
          elsif @lookup
            target = @lookup.get_target rest[2]
            if target
              options[:targets] << target
              rest = StringScanner.new rest[3]
            else
              unscan
            end
          else
            unscan
          end
        end

        self.string = rest.string

        node = parse_message_with_location options
        return node if node

        return MessageNode.new options.merge(:body => string)
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
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:create\s*group|create|cg|\*)\s*$/i
      return HelpNode.new :node => CreateGroupNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:join\s*group|join|j|>)\s*$/i
      return HelpNode.new :node => JoinNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:leave\s*group|leave|l|<)\s*$/i
      return HelpNode.new :node => LeaveNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(?:log\s*in|li|iam|i\s+am|i'm|im|\()\s*$/i
      return HelpNode.new :node => LoginNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(log\s*out|log\s*off|lo|bye|\))\s*$/i
      return HelpNode.new :node => LogoutNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(stop|off)\s*$/i
      return HelpNode.new :node => OffNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(start|on)\s*$/i
      return HelpNode.new :node => OnNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(name|n|signup)\s*$/i
      return HelpNode.new :node => SignupNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(whois|wh)\s*$/i
      return HelpNode.new :node => WhoIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(whereis|wi|w)\s*$/i
      return HelpNode.new :node => WhereIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(my)\s*$/i
      return HelpNode.new :node => MyNode
    elsif scan /^\s*(?:#|\.)*\s*(?:help|h|\?)\s+(?:#|\.)*\s*(i|invite)\s*$/i
      return HelpNode.new :node => InviteNode
    end

    node = parse_message_with_location options
    return node if node

    # Signup and join
    if scan /^\s*(.+?)\s*>\s*(\S+)\s*$/i
      return new_signup self[1].strip, self[2]
    end

    if @parse_signup_and_join && scan(/^\s*(.+?)\s*(?:join|\!)\s*(\S+)\s*$/i)
      return new_signup self[1].strip, self[2]
    end

    # Signup
    if scan /^\s*(?:#|\.)*?\s*(?:name|n|signup)(\s+(help|\?))?\s*$/i
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
    if scan /^\s*(?:#|\.)*?\s*(?:log\s*in|li|iam|i\s+am|i'm|im|\()(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => LoginNode
    elsif scan /^\s*(?:#|\.)*?\s*(?:log\s*in|iam|i\s+am|i'm|im|\()\s*(?:@\s*)?(\S+)\s+(\S+)\s*$/i
      return LoginNode.new :login => self[1], :password => self[2]
    elsif scan /^\s*(?:#|\.)+\s*li\s*(?:@\s*)?(.+?)\s+(.+?)\s*$/i
      return LoginNode.new :login => self[1], :password => self[2]
    elsif scan /^\s*(?:#|\.)*?\s*(.im)(\s+\S+)?\s*$/i
      return HelpNode.new :node => LoginNode
    end

    # Logout
    if scan /^\s*(?:#|\.)*?\s*(log\s*out|log\s*off|lo|bye|\))\s+(help|\?)\s*$/i
      return HelpNode.new :node => LogoutNode
    elsif scan /^\s*(?:#|\.)*?\s*(log\s*out|log\s*off|log\s*out|lo|bye)\s*$/i
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
    if scan /^\s*(?:#|\.)*?\s*(?:create\s*group|create|cg|\*)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => CreateGroupNode
    elsif scan /^\s*(?:#|\.)*?\s*(?:create\s*group|create|cg)\s+(?:@\s*)?(.+?)(\s+.+?)?$/i
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
    if scan /^\s*(?:join|join\s*group|\.\s*j|\.\s*join|\#\s*j|\#\s*join|>)(\s+(help|\?))?\s*$/i
      return HelpNode.new :node => JoinNode
    elsif scan /^\s*(?:join|join\s*group|\.\s*j|\.\s*join|\#\s*j|\#\s*join)\s+(?:@\s*)?(\S+)$/i
      return JoinNode.new :group => self[1]
    elsif scan /^\s*>\s*(?:@\s*)?(\S+)$/i
      return JoinNode.new :group => self[1]
    end

    # Leave
    if scan /^\s*(?:leave|leave\s*group|\.\s*l|\.\s*leave|\#\s*l|\#\s*leave|<)(\s+(help|\?))?\s*$/i
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
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)(help|\?)\s*$/i
      return HelpNode.new :node => MyNode
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)groups\s*$/i
      return MyNode.new :key => MyNode::Groups
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)(?:group|g)\s*$/i
      return MyNode.new :key => MyNode::Group
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)(?:group|g)\s+(?:@\s*)?(\S+)\s*$/i
      return MyNode.new :key => MyNode::Group, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)name\s*$/i
      return MyNode.new :key => MyNode::Name
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)name\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Name, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)email\s*$/i
      return MyNode.new :key => MyNode::Email
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)email\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Email, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)(number|phone|phonenumber|phone\s+number|mobile|mobilenumber|mobile\s+number)\s*$/i
      return MyNode.new :key => MyNode::Number
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)(number|phone|phonenumber|phone\s+number|mobile|mobilenumber|mobile\s+number)\s*(.+?)\s*$/i
      return MyNode.new :key => MyNode::Number, :value => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)location\s*$/i
      return MyNode.new :key => MyNode::Location
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)location\s+(.+?)\s*$/i
      return MyNode.new :key => MyNode::Location, :value => check_numeric_location(self[1].strip)
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)login\s*$/i
      return MyNode.new :key => MyNode::Login
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)login\s+(\S+)\s*$/i
      return MyNode.new :key => MyNode::Login, :value => self[1]
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)password\s*$/i
      return MyNode.new :key => MyNode::Password
    elsif scan /^\s*(?:#|\.)*\s*my(?:\s+|_*)password\s+(\S+)\s*$/i
      return MyNode.new :key => MyNode::Password, :value => self[1]
    end

    # Who is
    if scan /^\s*(?:#|\.)*\s*(?:whois|wi)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => WhoIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:whois|wi)\s+(?:@\s*)?(.+?)\s*\??\s*$/i
      return WhoIsNode.new :user => self[1].strip
    end

    # Where is
    if scan /^\s*(?:#|\.)*\s*(?:whereis|wh|w)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => WhereIsNode
    elsif scan /^\s*(?:#|\.)*\s*(?:whereis|wh|w)\s+(?:@\s*)?(.+?)\s*\??\s*$/i
      return WhereIsNode.new :user => self[1].strip
    end

    # Language
    if scan /^\s*(?:#|\.)*\s*(?:lang|_)(\s+(?:help|\?))?\s*$/i
      return HelpNode.new :node => LanguageNode
    elsif scan /^\s*(?:#|\.)*\s*(?:lang)\s+(.+?)\s*$/i
      return LanguageNode.new :name => self[1].strip
    elsif scan /^\s*(?:#|\.)*\s*_+\s*(.+?)\s*$/i
      return LanguageNode.new :name => self[1].strip
    end

    # Unknown command
    if scan /^\s*(#|\.)+\s*(\S+)\s*(?:.+?)?$/i
      trigger = self[1][0 ... 1]
      command = self[2]
      return UnknownCommandNode.new :trigger => trigger, :command => command
    end

    MessageNode.new options.merge(:body => string)
  end

  def parse_message_with_location(options = {})
    if scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+\.\d+\.\d+)\s*°?\s*(N|S)?(?:\s*\*?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+\.\d+\.\d+)\s*°?\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = location(* self[2].gsub(/\s/, '').split('.') + self[5].gsub(/\s/, '').split('.'))
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+\,\d+\,\d+)\s*°?\s*(N|S)?(?:\s*\*?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+\,\d+\,\d+)\s*°?\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = location(* self[2].gsub(/\s/, '').split(',') + self[5].gsub(/\s/, '').split(','))
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+\.\d+\.\d+\.\d+)\s*°?\s*(N|S)?(?:\s*\*?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+\.\d+\.\d+\.\d+)\s*°?\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = location(* self[2].gsub(/\s/, '').split('.') + self[5].gsub(/\s/, '').split('.'))
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+\,\d+\,\d+\,\d+)\s*°?\s*(N|S)?(?:\s*\*?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+\,\d+\,\d+\,\d+)\s*°?\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = location(* self[2].gsub(/\s/, '').split(',') + self[5].gsub(/\s/, '').split(','))
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*°\s*(N|S)?(?:\s*(?:\*|,)?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*°\s*(E|W)?\s*\*?\s*([^\s\d].+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = [self[2].gsub(/\s/, '').to_f, self[5].gsub(/\s/, '').to_f]
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)(?:\s*°\s*|\s+)(\d+)?(?:\s*'\s*|\s+)(\d+)?(?:\s*''\s*)?\s*(N|S)?(?:\s*(?:\*|,)?\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)(?:\s*°\s*|\s*)(\d+)?(?:\s*'\s*|\s*)(\d+)?(?:\s*''\s*)?\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[5] == 'S' ? -1 : 1
      sign1 = self[6] == 'W' || self[10] == 'W' ? -1 : 1
      loc = location(self[2].gsub(/\s/, ''), self[3], self[4], self[7].gsub(/\s/, ''), self[8], self[9])
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[11].try(:strip))
    elsif scan /^\s*(?:at|l:)?\s*(N|S)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*(N|S)?(?:\s*(?:\*|,)\s*|\s+)(E|W)?\s*((?:\+|\-)?\s*\d+(?:\.\d+)?)\s*(E|W)?\s*\*?\s*(.+?)?$/i
      sign0 = self[1] == 'S' || self[3] == 'S' ? -1 : 1
      sign1 = self[4] == 'W' || self[6] == 'W' ? -1 : 1
      loc = [self[2].gsub(/\s/, '').to_f, self[5].gsub(/\s/, '').to_f]
      loc[0] = loc[0] * sign0
      loc[1] = loc[1] * sign1
      MessageNode.new options.merge(:location => loc, :body => self[7].try(:strip))
    elsif scan /^\s*(?:at|l:)\s+\/?(.+?)\/?\s*\*\s*([^\/]+)?$/i
      MessageNode.new options.merge(:location => self[1], :body => self[2].try(:strip))
    elsif scan /^\s*(?:at|l:)\s+\/(.+?)\/\s*(!)?\s*(.+?)?$/i
      MessageNode.new options.merge(:location => self[1], :body => self[3].try(:strip), :blast => self[2] ? true : options[:blast])
    elsif scan /^\s*\/?(.+?)\/?\s*\*\s*([^\/]+)?$/i
      MessageNode.new options.merge(:location => self[1], :body => self[2].try(:strip))
    elsif scan /^\s*(?:(?:at|l:)\s+)?\s*\/([^\/]+)$/i
      pieces = self[1].split ' ', 2
      if pieces[1] && pieces[1].start_with?('!')
        options[:blast] = true
        pieces[1] = pieces[1][1 .. -1].strip
      end
      MessageNode.new options.merge(:location => pieces[0], :body => pieces[1])
    elsif scan /^\s*(?:at|l:)\s+\/?(.+?)\/?$/i
      MessageNode.new options.merge(:location => self[1])
    elsif scan /^\s*\/(.+?)\/\s*(!)?\s*(.+?)?$/i
      MessageNode.new options.merge(:location => self[1], :body => self[3].try(:strip), :blast => self[2] ? true : options[:blast])
    else
      nil
    end
  end

  def check_blast
    if scan /\s*!\s*(.+?)$/i
      self.string = self[1]
      true
    else
      nil
    end
  end

  def check_numeric_location(string)
    if string =~ /^\s*(\d+(?:(?:\.|,)\d+)?)(?:\s+|\s*(?:,|\.|\*)\s*)(\d+(?:(?:\.|,)\d+)?)\s*$/
      location($1, $2)
    else
      string
    end
  end

  def new_signup(string, group = nil)
    SignupNode.new :display_name => string, :suggested_login => string.gsub(/\s/, ''), :group => group
  end

  def new_create_group(group_alias, pieces)
    options = {:alias => self[1], :public => false, :nochat => false}
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
    if args.length == 2
      args.map{|x| x.gsub(',', '.').to_f}
    elsif args.length == 6
      [deg(*args[0 .. 2]), deg(*args[3 .. 5])]
    elsif args.length == 8
      [deg(*args[0 .. 3]), deg(*args[4 .. 7])]
    end
  end

  def deg(*args)
    if args.length == 4
      args = [args[0], args[1], "#{args[2]}.#{args[3]}"]
    end
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
  attr_accessor :group
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
  attr_accessor :alias
  attr_accessor :public
  attr_accessor :nochat
  attr_accessor :name
end

class InviteNode < Node
  attr_accessor :group
  attr_accessor :users

  def fix_group
    if self.group
      group = Group.find_by_alias self.group
      if !group
        group = Group.find_by_alias self.users.first
        if group
          self.users = [self.group]
        else
          self.users.insert 0, self.group
        end
      end
    end
    group
  end
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
  attr_accessor :locations
  attr_accessor :mentions
  attr_accessor :tags
  attr_accessor :blast

  def location
    @locations.try(:first)
  end

  def location=(value)
    @locations = [value]
  end

  def target
    @targets.try(:first)
  end

  def target=(value)
    @targets = [value]
  end

  def second_target
    @targets.try(:second)
  end
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

class PingNode < Node
  attr_accessor :text
end

class UnknownCommandNode < Node
  attr_accessor :trigger
  attr_accessor :command
  attr_accessor :suggestion
end

class Target
  attr_accessor :name
  attr_accessor :payload
  def initialize(name, payload = nil)
    @name = name
    @payload = payload
  end

  def ==(other)
    self.class == other.class && self.name == other.name
  end
end

class GroupTarget < Target
end

class UserTarget < Target
end

class UnknownTarget < Target
end
