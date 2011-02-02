require 'test_helper'

class NuntiumControllerTest < ActionController::TestCase
  test "receive at" do
    pipeline = Pipeline.new
    pipeline.process :from => 'sms://1', :body => '.name User1'
    pipeline.process :from => 'sms://1', :body => 'create Group1'
    pipeline.process :from => 'sms://2', :body => '.name User2'
    pipeline.process :from => 'sms://2', :body => 'join Group1'

    message = {'from' => 'sms://1', 'body' => "@User2 Hello!"}

    @request.env['HTTP_AUTHORIZATION'] = http_auth(NuntiumConfig['incoming_username'], NuntiumConfig['incoming_password'])
    get :receive_at, message

    assert_response :ok

    assert_equal [{:to => 'sms://2', :body => 'User1 only to you: Hello!', :from => 'geochat://system'}].to_json, @response.body

    messages = Message.all
    assert_equal 1, messages.count

    msg = messages.first
    assert_equal User.find_by_login('User1'), msg.sender
    assert_equal User.find_by_login('User2'), msg.receiver
    assert_equal Group.find_by_alias('Group1'), msg.group
    assert_equal 'Hello!', msg.text
  end

  test "receive at unauthorized" do
    get :receive_at

    assert_response :unauthorized
  end

  test "receive at spots bug" do
    sender = User.make
    group = Group.make
    receiver = User.make
    message = {'from' => 'sms://1', 'body' => "Hello!"}

    pipeline = mock('pipeline')
    Pipeline.expects(:new).returns(pipeline)
    pipeline.expects(:process).with(message).raises(Exception.new 'the bug description')

    @request.env['HTTP_AUTHORIZATION'] = http_auth(NuntiumConfig['incoming_username'], NuntiumConfig['incoming_password'])
    get :receive_at, message

    assert_response :ok
    assert_equal "You've just spotted a bug: the bug description", @response.body
  end
end
