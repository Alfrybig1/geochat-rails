class GroupsController < ApplicationController
  before_filter :get_group, :except => [:index, :public, :new, :create]
  before_filter :check_is_owner, :except => [:index, :public, :new, :create, :show, :join, :change_role, :accept_join_request]
  before_filter :check_is_admin_or_owner, :only => [:accept_join_request]

  def index
    @memberships = @user.memberships.includes(:group).all
    @groups = @memberships.map &:group
    @owned_groups = @memberships.select{|m| m.role == :owner}.map &:group
  end

  def public
    @pagination = {
      :page => params[:page] || 1,
      :per_page => 10
    }
    @groups = Group.public.includes(:memberships).paginate @pagination
    @groups.reject! { |g| g.memberships.map(&:user_id).include? @user.id }
  end

  def new
    @group = @user.groups.new
  end

  def create
    @group = @user.groups.new params[:group]
    if @group.valid? && @group.location_known?
      result = Geokit::Geocoders::GoogleGeocoder.reverse_geocode([@group.lat, @group.lon])
      @group.location = result.full_address if result.success?
    end

    if @group.save
      @user.join @group, :as => :owner

      flash[:notice] = "Group #{@group.alias} created"
      redirect_to groups_path
    else
      render :new
    end
  end

  def show
    @user_membership = @user.membership_in @group
    if !@user_membership
      @invite = @user.invite_in @group
      render :show_for_non_members and return
    end

    @memberships_pagination = {
      :page => params[:users_page] || 1,
      :per_page => 10
    }
    @memberships = @group.memberships.includes(:user).order('users.login_downcase').paginate @memberships_pagination

    @custom_locations_pagination = {
      :page => params[:custom_locations_page] || 1,
      :per_page => 10
    }
    @custom_locations = @group.custom_locations.order('name').paginate @custom_locations_pagination

    @custom_channels = @group.custom_channels.order('name')
  end

  def join
    if @user.belongs_to? @group
      flash[:notice] = "You already are a member of #{@group}"
    elsif @group.requires_approval_to_join?
      invites = @user.invites_in @group
      if invites.present?
        if invites.any? &:admin_accepted?
          @user.join @group
          invites.each &:destroy

          flash[:notice] = "You are now a member of #{@group}"
        elsif invites.any? &:user_accepted?
          flash[:notice] = "You already requested to join #{@group}"
        else
          invites.each { |x| x.user_accepted = true; x.save! }

          flash[:notice] = "Request to join group #{@group} sent"
        end
      else
        @user.request_join @group
        flash[:notice] = "Request to join group #{@group} sent"
      end
    else
      @user.join @group
      flash[:notice] = "You are now a member of #{@group}"
    end

    redirect_to @group
  end

  def accept_join_request
    login = params[:user]
    invite = @user.others_requests.all.select{|x| x.user_login == login}.first
    other_user = invite.user
    other_user.join @group
    invite.destroy

    other_user.invites_in(@group).each &:destroy

    flash[:notice] = "You have accepted #{other_user.login} in #{@group}"
    redirect_to invites_path
  end

  def change_role
    user_membership = @user.membership_in(@group)
    membership = @group.memberships.joins(:user).where('users.login_downcase = ?', params[:user].downcase).first

    # Can't touch someone bigger or same than you
    return redirect_to @group if membership >= user_membership

    membership.role = params[:role].to_sym

    # Can't change to someone bigger than you
    return redirect_to @group if membership > user_membership

    membership.save!

    flash[:notice] = "User #{params[:user]} is now #{params[:role]} in #{@group}"
    redirect_to @group
  end

  [['sms', 'qst_server'], ['xmpp', 'xmpp']].each do |kind, nuntium_kind|
    class_eval %Q(
      def new_custom_#{kind}_channel
        @custom_channel = @group.custom_#{nuntium_kind}_channels.new
      end

      def create_custom_#{kind}_channel
        @custom_channel = @group.custom_#{nuntium_kind}_channels.new params[:custom_#{nuntium_kind}_channel]
        if @custom_channel.save
          flash[:notice] = "Custom #{kind} channel " + @custom_channel.name + " created"
          redirect_to group_path(@group)
        else
          render :new_custom_#{nuntium_kind}_channel
        end
      end
    )
  end

  def destroy_custom_channel
    @custom_channel = @group.custom_channels.find params[:custom_channel_id]
    @custom_channel.destroy

    flash[:notice] = "Custom #{@custom_channel.kind} channel #{@custom_channel.name} deleted"
    redirect_to group_path(@group)
  end

  def change_external_service
  end

  def update_external_service
    @group.external_service_prefix = params[:group][:external_service_prefix]
    @group.external_service_url = params[:group][:external_service_url]
    @group.save!

    if @group.external_service_url.present?
      flash[:notice] = "Now messages are forwarded to an external service"
    else
      flash[:notice] = "Now messages are not forwarded to an external service"
    end
    redirect_to group_path(@group)
  end

  include LocatableActions
  def locatable; @group; end
  def locatable_path; group_path(@group); end

  private

  def get_group
    @group = Group.find_by_alias params[:id]
  end

  def check_is_owner
    redirect_to group_path(@group) unless @user.is_owner_of? @group
  end

  def check_is_admin_or_owner
    @membership = @user.membership_in @group
    redirect_to group_path(@group) unless @membership >= :admin
  end
end
