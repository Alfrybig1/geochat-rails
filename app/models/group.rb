class Group < ActiveRecord::Base
  include Locatable

  has_many :memberships, :dependent => :destroy
  has_many :users, :through => :memberships
  has_many :messages, :dependent => :destroy
  has_many :custom_channels, :dependent => :destroy
  has_many :custom_qst_server_channels

  validates :alias, :presence => true, :length => {:minimum => 3}, :format => {:with => /\A[a-zA-Z0-9]+\Z/, :message => 'can only contain alphanumeric characters'}
  validates :alias_downcase, :presence => true, :uniqueness => true
  validates_presence_of :name
  validate :alias_not_a_command

  before_validation :update_alias_downcase

  data_accessor :users_count, :default => 0
  data_accessor :blocked_users, :default => []

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

  def block(user)
    return false if self.blocked_users.include?(user.id)

    # Block it
    self.blocked_users << user.id

    save!

    # Remove user from group
    membership = user.membership_in(self)
    membership.destroy if membership

    true
  end

  def unblock(user)
    return false unless self.blocked_users && self.blocked_users.include?(user.id)

    self.blocked_users.delete user.id
    save!

    true
  end

  def as_json(options = {})
    hash = {:alias => self.alias}
    hash[:name] = self.name if self.name.present?
    hash[:requireApprovalToJoin] = self.requires_approval_to_join?
    hash[:isChatRoom] = self.chatroom?
    hash[:created] = self.created_at
    hash[:updated] = self.updated_at
    hash
  end

  def to_s
    self.alias
  end

  private

  def update_alias_downcase
    self.alias_downcase = self.alias.downcase
  end

  def alias_not_a_command
    errors.add(:alias, 'is a reserved name') if self.alias.try(:command?)
  end
end
