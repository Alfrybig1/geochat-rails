class User < ActiveRecord::Base
  has_many :channels
  has_many :memberships
  has_many :groups, :through => :memberships

  validates :login, :presence => true, :uniqueness => true

  belongs_to :default_group, :class_name => 'Group'

  def self.find_by_mobile_number(number)
    User.joins(:channels).where('channels.protocol = ? and channels.address = ?', 'sms', number).first
  end

  def self.find_suitable_login(suggested_login)
    login = suggested_login
    index = 2
    while self.find_by_login(login)
      login = "#{suggested_login}#{index}"
      index += 1
    end
    login
  end

  def self.find_by_login_or_mobile_number(search)
    user = self.find_by_login search
    user = self.find_by_mobile_number search unless user
    user
  end

  def create_group(options = {})
    group = Group.create! options
    join group, :as => :owner
    group
  end

  def join(group, options = {})
    Membership.create! :user => self, :group => group, :role => (options[:as] || :member)
  end

  # user can be a User or a string, in which case a new User will be created with that login
  # options = :to => group
  def invite(user, options = {})
    group = options[:to]
    if user.kind_of?(String)
      user = User.create! :login => user, :created_from_invite => true
    end
    Invite.create! :group => group, :user => user, :admin_accepted => self.is_owner_of(group)
  end

  def request_join(group)
    Invite.create! :user => self, :group => group, :user_accepted => true
  end

  def make_owner_of(group)
    membership = Membership.find_by_group_id_and_user_id(group.id, self.id)
    membership.role = :owner
    membership.save!
  end

  def role_in(group)
    Membership.find_by_group_id_and_user_id(group.id, self.id).try(:role).try(:to_sym)
  end

  def is_owner_of(group)
    role_in(group) == :owner
  end
end
