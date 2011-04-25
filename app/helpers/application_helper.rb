module ApplicationHelper
  def geochat_version
    begin
      @@geochat_version = File.read('VERSION').strip unless defined? @@geochat_version
    rescue Errno::ENOENT
      @@geochat_version = 'Development'
    end
    @@geochat_version
  end

  def new_custom_location_path(locatable)
    if locatable.is_a? User
      new_user_custom_location_path
    else
      new_group_custom_location_path locatable
    end
  end

  def create_custom_location_path(locatable)
    if locatable.is_a? User
      create_user_custom_location_path
    else
      create_group_custom_location_path locatable
    end
  end

  def edit_custom_location_path(locatable, location)
    if locatable.is_a? User
      edit_user_custom_location_path location
    else
      edit_group_custom_location_path locatable, location
    end
  end

  def destroy_custom_location_path(locatable, location)
    if locatable.is_a? User
      destroy_user_custom_location_path location
    else
      destroy_group_custom_location_path locatable, location
    end
  end
end
