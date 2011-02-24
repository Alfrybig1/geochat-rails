class Node
  Commands = []
  CommandsAfterGroup = []

  def self.command(&block)
    # Insert into Commands array
    if Commands.last.try(:name) == 'UnknownNode'
      Commands.insert(Commands.length - 1, self)
    else
      Commands << self
    end

    if block_given?
      if block.arity == 0
        # Delcare Command constant
        self.const_set :Command, ::Command.new(self, &block)

        # Declare attr_accessors for the parameters
        self::Command.args.each do |args|
          args[:args].each do |arg|
            attr_accessor arg
          end
        end
      else
        metaclass = class << self; self; end
        metaclass.send :define_method, :scan, &block
      end
    end

    # Declare the Help constant
    self.const_set :Help, T.send("help_#{name.underscore[0 .. -6]}") unless self.name == 'UnknownNode'
  end

  def self.command_after_group(&block)
    CommandsAfterGroup << self
    command(&block)

    attr_accessor :group
  end

  def self.names
    self::Command.names
  end

  attr_accessor :matched_name
  attr_accessor :context
  attr_accessor :messages

  def initialize(attrs = {})
    attrs.each do |k, v|
      send "#{k}=", v
    end
    @messages = []
  end

  def self.scan(strscan)
    self::Command.scan(strscan)
  end

  def after_scan
  end

  def after_scan_with_group
    after_scan
  end

  def self.process(message = {})
    message = message.with_indifferent_access

    context = {}
    context[:message] = message
    context[:from] = message[:from]
    context[:protocol], context[:address] = message[:from].split '://', 2
    context[:channel] = Channel.find_by_protocol_and_address context[:protocol], context[:address]
    context[:user] = context[:channel].try(:user)

    def context.get_target(name)
      if self[:user]
        group = self[:user].groups.find_by_alias(name)
        return GroupTarget.new(name, :group => group) if group

        invite = Invite.joins(:group).where('user_id = ? and groups.alias = ?', self[:user].id, name).first
        return GroupTarget.new(name, :group => invite.group, :invite => invite) if invite
      end

      nil
    end

    node = Parser.parse(message[:body], context, :parse_signup_and_join => !context[:user])
    node.context = context
    node.turn_on_channel_if_needed
    node.process
    node.messages
  end

  def turn_on_channel_if_needed
    return if self.is_a?(OnNode) || self.is_a?(OffNode) || current_channel.try(:status) != :off

    current_channel.turn :on
    reply T.we_have_turned_on_updates_on_this_channel(current_channel)
  end

  def current_user
    @context[:user]
  end

  def current_user=(user)
    @context[:user] = user
  end

  def current_channel
    @context[:channel]
  end

  def current_channel=(channel)
    @context[:current_channel] = channel
  end

  def address
    @context[:address]
  end

  def message
    @context[:message]
  end

  def join_and_welcome(user, group)
    user.join group
    send_message_to_user user, T.welcome_to_group(user, group)
  end

  def reply_not_logged_in
    reply T.you_are_not_signed_in
  end

  def reply_user_does_not_exist(user)
    reply T.user_does_not_exist(user)
  end

  def reply_group_does_not_exist(group)
    reply T.group_does_not_exist(group)
  end

  def reply_dont_belong_to_any_group
    reply T.you_dont_belong_to_any_group_yet
  end

  def reply(message)
    send_message :to => @context[:from], :body => message
  end

  def notify_join_request(group)
    send_message_to_group_owners group, T.invitation_pending_for_approval(current_user, group)
    reply T.group_requires_approval(group)
  end

  def send_message_to_group(group, msg)
    group.users.includes(:channels).reject{|x| x.id == current_user.id}.each do |user|
      send_message_to_user_in_group user, group, msg
    end
  end

  def send_message_to_group_owners(group, msg, options = {})
    targets = group.owners
    targets.reject!{|x| x == options[:except]} if options[:except]
    targets.each do |user|
      send_message_to_user_in_group user, group, msg
    end
  end

  def send_message_to_user_in_group(user, group, msg)
    if group.id == user.default_group_id || user.memberships.count == 1
      send_message_to_user user, msg
    else
      send_message_to_user user, "[#{group.alias}] #{msg}"
    end
  end

  def send_message_to_user(user, msg)
    if user == current_user
      reply msg
    else
      user.active_channels.each do |channel|
        send_message_to_channel channel, msg
      end
    end
  end

  def send_message_to_channel(channel, msg)
    send_message :to => channel.full_address, :body => msg
  end

  def send_message(options = {})
    @messages << options
  end

  def update_current_user_location_to(location)
    if location.is_a?(String)
      result = Geocoder.locate(location)
      if result
        coords = result[:lat], result[:lon]
        place = result[:location]
      else
        reply T.location_not_found(location)
        return false
      end

      short_url = Googl.shorten "http://maps.google.com/?q=#{CGI.escape place}"
    else
      place, coords = Geocoder.reverse(location), location
      short_url = Googl.shorten "http://maps.google.com/?q=#{coords.join ','}"
    end

    current_user.location = place
    current_user.coords = coords
    current_user.location_short_url = short_url
    current_user.save!

    reply T.location_successfuly_updated(place, current_user_location_info)

    true
  end

  def create_channel_for(user)
    Channel.create! :protocol => @context[:protocol], :address => @context[:address], :user => user, :status => :on
  end

  def current_user_location_info
    user_location_info current_user
  end

  def user_location_info(user)
    str = "lat: #{user.lat}, lon: #{user.lon}"
    if user.location_short_url.present?
      str << ", url: #{user.location_short_url}"
    end
    str
  end

  def default_group(options = {})
    group = current_user.default_group
    return group if group

    groups = current_user.groups.to_a
    if groups.empty?
      reply_dont_belong_to_any_group
    elsif groups.length == 1
      return groups.first
    else
      reply options[:no_default_group_message]
    end

    nil
  end
end
