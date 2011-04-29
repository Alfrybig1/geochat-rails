class ApiController < ApplicationController
  skip_before_filter :check_login
  before_filter :authenticate, :except => [:create_user, :user, :verify_user_credentials]
  before_filter :check_user, :only => [:user, :set_groups_order, :get_groups_order]
  before_filter :check_group, :only => [:group, :group_members, :send_message_to_group]

  def create_user
    user = User.create! :login => params[:login], :password => params[:password], :display_name => params[:displayname]
    render :json => user
  rescue
    head :bad_request
  end

  def user
    render :json => @user
  end

  def verify_user_credentials
    render :text => (!!User.authenticate(params[:login], params[:password])).to_s
  end

  def user_groups
    render :json => @user.sorted_groups
  end

  def group
    render :json => @group
  end

  def group_members
    render :json => @group.users
  end

  def group_messages
    groups = params[:alias].split('+').map &:downcase
    groups_length = groups.length
    groups = Group.where(:alias_downcase => groups).select(:id).map(&:id)
    return head :not_found if groups_length != groups.length
    return head :unauthorized if Membership.where(:user_id => @user.id, :group_id => groups).count != groups.length

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 50).to_i
    offset = (page - 1) * per_page

    messages = Message.where(:group_id => groups).order('created_at DESC').offset(offset).limit(per_page)
    messages = messages.where('created_at > ?', Time.parse(params[:since])) if params[:since].present?
    render :json => {:items => messages}
  end

  def send_message_to_group
    msg = @user.send_message_to_group @group, params[:message]
    render :text => %Q("#{msg.id}")
  end

  def set_groups_order
    order = JSON.parse request.raw_post

    @user.groups_order = order['by']
    @user.groups_order_manually = order['order'] if @user.groups_order == "manually"
    @user.save!

    head :ok
  end

  def get_groups_order
    render :text => @user.groups_order
  end

  private

  def authenticate
    check_user_in_session or check_user_used_remember_me or authenticate_or_request_with_http_basic do |username, password|
      @user = User.authenticate username, password
    end
  end

  def check_user
    @user = User.find_by_login params[:login]
    return head :not_found unless @user
  end

  def check_group
    @group = Group.find_by_alias params[:alias]
    return head :not_found unless @group
    return head :unauthorized unless @user.belongs_to? @group
  end
end
