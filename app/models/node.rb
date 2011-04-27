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

    # Declare the help method
    class << self;
      def help
        T.send("help_#{name.underscore[0 .. -6]}")
      end
    end
  end

  def self.command_after_group(&block)
    CommandsAfterGroup << self
    command(&block)

    attr_accessor :group
  end

  def self.names
    self::Command.names
  end

  def self.requires_user_to_be_logged_in
    metaclass = class << self; self; end
    metaclass.send :define_method, :requires_user_to_be_logged_in? do
      true
    end
  end

  def self.requires_user_to_be_logged_in?
    false
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

    # Check channel activation
    if context[:channel] && context[:channel].activation_pending?
      return check_activation_code context
    end

    setup_get_target context

    node = Parser.parse(message[:body], context, :parse_signup_and_join => !context[:user])
    node.context = context

    I18n.with_locale node.current_locale do
      node.turn_on_channel_if_needed

      if !node.current_user && node.class.requires_user_to_be_logged_in?
        node.reply T.you_are_not_signed_in
      else
        node.process
      end

      node.messages
    end
  end

  def self.setup_get_target(context)
    def context.get_target(name)
      if self[:user]
        group = self[:user].groups.find_by_alias(name)
        return GroupTarget.new(name, :group => group) if group

        invite = Invite.joins(:group).where('user_id = ? and groups.alias = ?', self[:user].id, name).first
        return GroupTarget.new(name, :group => invite.group, :invite => invite) if invite
      end

      nil
    end
  end

  def self.check_activation_code(context)
    node = Node.new :context => context
    if context[:channel].activate context[:message][:body]
      node.reply T.you_can_now_send_and_receive_messages_via_this_channel(context[:user].login)
    else
      node.reply T.incorrect_activation_code(context[:message][:body])
    end
    return node.messages
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

  def current_locale
    current_user.try(:locale) || :en
  end

  def address
    @context[:address]
  end

  def message
    @context[:message]
  end

  def join_and_welcome(user, group)
    user.join group
    send_message_to_user user, :welcome_to_group, :args => [user, group]
  end

  def reply(msg, options = {})
    msg = check_symbol_message msg, options
    send_message :to => @context[:from], :body => msg
  end

  def reply_in_group(group, msg, options = {})
    msg = check_symbol_message msg, options
    send_message :group => group.alias, :to => @context[:from], :body => msg
  end

  def check_symbol_message(message, options)
    if message.is_a? Symbol
      if options[:args]
        T.send message, *options[:args]
      else
        T.send message
      end
    else
      message
    end
  end

  def notify_join_request(group)
    send_message_to_group_owners group, :invitation_pending_for_approval, :args => [current_user, group]
    reply T.group_requires_approval(group)
  end

  def send_message_to_group(group, msg, options = {})
    options = options.merge :group => group

    group.users.includes(:channels).reject{|x| x.id == current_user.id}.each do |user|
      send_message_to_user user, msg, options
    end
  end

  def send_message_to_group_owners(group, msg, options = {})
    options = options.merge :group => group

    targets = group.owners
    targets.reject!{|x| options[:except].include?(x)} if options[:except]
    targets.each do |user|
      send_message_to_user user, msg, options
    end
  end

  def send_message_to_user(user, msg, options = {})
    return reply msg, options if user == current_user

    # This check is here so that we don't forget to translate messages that are sent to
    # others users that are not the current user.
    if !msg.is_a?(Symbol) && !options[:dont_translate]
      raise "Message must be a symbol in order to be internationalized for the user"
    end

    I18n.with_locale user.locale do
      msg = check_symbol_message msg, options
      user.active_channels.each do |channel|
        send_message_to_channel user, channel, msg, options
      end
    end
  end

  def send_message_to_channel(user, channel, msg, options = {})
    message_properties = {}

    prefix = ""

    if options[:group]
      group = options[:group]
      if group.id != user.default_group_id && user.groups_count > 1
        prefix << "[#{group.alias}] "
      end
      message_properties[:group] = group.alias
    end

    if options[:sender]
      if options[:receivers]
        if options[:private]
          prefix << T.message_only_to_you(options[:sender], options[:receivers])
        else
          prefix << T.message_only_to_users(options[:sender], options[:receivers])
        end
      else
        prefix << options[:sender].login
      end
    end

    prefix << ": " if prefix.present?

    if options[:location]
      location_info = T.at_place current_user.location, current_user.location_info
      if msg.blank?
        msg_with_location = "#{location_info}"
      else
        msg_with_location = "#{msg} (#{location_info})"
      end

      # If we are sending a message to a mobile phone and it contains a location update,
      # check if it fits in 140 characters including the location update. If not, split
      # in two messages: the location update and the message.
      if channel.protocol == 'sms'
        full_msg = "#{prefix}#{msg_with_location}"
        if full_msg.length > 140
          send_message_to_channel user, channel, "#{prefix}#{location_info}"
          send_message_to_channel user, channel, "#{prefix}#{msg}"
          return
        end
      end

      msg = msg_with_location
    end

    msg = "#{prefix}#{msg}"

    message_properties[:to] = channel.full_address
    message_properties[:body] = msg

    send_message message_properties
  end

  def send_message(options = {})
    options[:from] = 'geochat://system'
    @messages << options
  end

  def update_current_user_location_to(location, group = nil)
    if location.is_a?(String)
      custom_location = current_user.find_custom_location(location)
      custom_location = group.find_custom_location(location) if !custom_location && group
      if custom_location
        place, coords, short_url = custom_location.location, custom_location.coords, custom_location.location_short_url
      else
        result = Geokit::Geocoders::GoogleGeocoder.geocode(location)
        if result.success?
          coords = result.lat, result.lng
          place = result.full_address
        else
          reply T.location_not_found(location)
          return false
        end
        short_url = Googl.shorten_location place
      end
    else
      result = Geokit::Geocoders::GoogleGeocoder.reverse_geocode(location)
      if result.success?
        coords = location
        place = result.full_address
      else
        reply T.location_not_found(location.join ', ')
        return false
      end
      short_url = Googl.shorten_location coords
    end

    current_user.location = place
    current_user.coords = coords
    current_user.location_short_url = short_url
    current_user.save!

    reply T.location_successfuly_updated(place, current_user.location_info)

    custom_location || true
  end

  def create_channel_for(user)
    @context[:protocol].to_channel.create! :address => @context[:address], :user => user, :status => :on
  end

  def default_group(options = {})
    group = current_user.default_group
    return group if group

    case current_user.groups_count
    when 0
      reply T.you_dont_belong_to_any_group_yet
    when 1
      return current_user.groups.all.first
    else
      reply options[:no_default_group_message]
    end

    nil
  end
end

# Load all nodes
Dir["#{Rails.root}/app/models/nodes/*"].each do |file|
  eval(ActiveSupport::Inflector.camelize(file[file.rindex('/') + 1 .. -4]))
end
