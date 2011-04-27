class OwnerNode < Node
  command_after_group do
    name 'owner group', :spaces_in_args => false
    name 'owner', 'ow', 'group owner', :spaces_in_args => false
    name '\$', :prefix => :none, :space_after_command => false, :spaces_in_args => false
    args :user, :spaces_in_args => false
    args :user, :group, :spaces_in_args => false
  end

  requires_user_to_be_logged_in

  include UserAndGroupNode

  def after_scan
    self.group, self.user = self.user, self.group if self.group && self.group.integer?
  end

  def process
    user, group = solve_user_and_group :no_default_group_message => T.you_must_specify_a_group_to_set_owner(@user)
    return unless user && group

    current_user_membership = current_user.membership_in group
    return reply T.you_cant_set_owner_you_dont_belong_to_group(user, group) unless current_user_membership

    user_membership = user.membership_in group
    return reply T.user_does_not_belong_to_group(user, group), :group => group unless user_membership

    if current_user_membership.role != :owner
      if user == current_user
        return reply T.nice_try, :group => group
      else
        return reply T.you_cant_set_owner_you_are_not_owner(user, group), :group => group
      end
    end

    if user == current_user
      return reply T.you_are_already_an_owner_of_group(group), :group => group
    end

    if user_membership.change_role_to :owner
      reply T.user_set_as_owner(user, group), :group => group
      send_message_to_user user, :user_has_made_you_owner, :group => group, :args => [current_user, group], :prefix => false
    else
      reply T.user_already_an_owner(user, group), :group => group
    end
  end
end
