class Group < ActiveRecord::Base
  include Locatable

  has_many :memberships, :dependent => :destroy
  has_many :users, :through => :memberships
  has_many :messages, :dependent => :destroy
  has_many :invites, :dependent => :destroy
  has_many :custom_channels, :dependent => :destroy
  has_many :custom_qst_server_channels
  has_many :custom_xmpp_channels

  validates :alias, :presence => true, :length => {:minimum => 3}, :format => {:with => /\A[a-zA-Z0-9]+\Z/, :message => 'can only contain alphanumeric characters'}
  validates :alias_downcase, :presence => true, :uniqueness => true
  validates_presence_of :name
  validate :alias_not_a_command

  before_validation :update_alias_downcase

  data_accessor :users_count, :default => 0
  data_accessor :external_service_url
  data_accessor :external_service_prefix

  attr_reader_as_symbol :kind

  scope :public, where(:hidden => false)

  def self.find_by_alias(talias)
    self.find_by_alias_downcase talias.downcase
  end
  class << self; alias_method :[], :find_by_alias; end

  def to_param
    self.alias
  end

  def name_with_alias
    name == self.alias ? name : "#{name} (alias: #{self.alias})"
  end

  def owners
    User.joins(:memberships).where('memberships.group_id = ? AND (role = ? OR role = ?)', self.id, :admin, :owner)
  end

  def public?
    !hidden?
  end

  # Returns the targets of having membership send a message to this group.
  # Returns:
  #  - :none : if no one should receive the message
  #  - :owners : if owners should receive the message
  #  - :all : if owners should receive the message
  def message_targets(membership)
    case kind
    when :chatroom
      :all
    when :reports_and_alerts
      membership.owner? ? :all : :owners
    when :reports
      membership.owner? ? :none : :owners
    when :messaging
      :none
    when :alerts
      membership.owner? ? :all : :none
    end
  end

  def send_message(msg, membership = nil)
    membership ||= msg.sender.membership_in self
    targets = message_targets membership
    return if targets == :all ? users : owners

    targets.includes(:channels).each do |user|
      user.active_channels.each do |channel|
        send_message_to_channel user, channel, msg
      end
    end
    msg
  end

  def as_json(options = {})
    hash = {:alias => self.alias}
    hash[:name] = self.name if self.name.present?
    hash[:isPublic] = !self.hidden?
    hash[:requireApprovalToJoin] = self.requires_approval_to_join?
    hash[:membersCount] = self.users_count
    hash[:kind] = self.kind.to_s
    hash.merge! location_json
    hash[:created] = self.created_at
    hash[:updated] = self.updated_at
    hash
  end

  def to_s
    self.alias
  end

  private

  def send_message_to_user(user, msg)
    user.active_channels.each do |channel|
      send_message_to_channel user, channel, msg
    end
  end

  def send_message_to_channel(user, channel, msg)
    prefix = ""
    if id != user.default_group_id && user.groups_count > 1
      prefix << "[#{self.alias}] "
    end
    prefix << "#{msg.sender_login}: "
    options = {}
    options[:from] = "user://#{msg.sender_login}"
    options[:to] = channel.full_address
    options[:body] = "#{prefix}#{msg.text}"
    options[:group] = self.alias

    Nuntium.new_from_config.send_ao options
  end

  def update_alias_downcase
    self.alias_downcase = self.alias.downcase
  end

  def alias_not_a_command
    errors.add(:alias, 'is a reserved name') if self.alias.try(:command?)
  end
end
