require 'test_helper'

class NuntiumControllerTest < ActionController::TestCase
  test "receive at" do
    sender = User.make
    group = Group.make
    receiver = User.make
    message = {'from' => 'sms://1', 'body' => "Hello!"}
    saved_message = {
      :sender => sender,
      :receiver => receiver,
      :group => group,
      :text => "Hey",
      :lat => 10.2,
      :lon => 30.4,
      :location => 'Somewhere'
    }
    saved_message_copy = saved_message.dup

    pipeline = mock('pipeline')
    Pipeline.expects(:new).returns(pipeline)
    pipeline.expects(:process).with(message)
    pipeline.expects(:messages).returns('sms://2' => ['Bye'])
    pipeline.expects(:saved_message).returns(saved_message)

    @request.env['HTTP_AUTHORIZATION'] = http_auth(NuntiumConfig['incoming_username'], NuntiumConfig['incoming_password'])
    get :receive_at, message

    assert_response :ok

    assert_equal [{:from => 'geochat://system', :to => 'sms://2', :body => 'Bye'}].to_json, @response.body

    messages = Message.all
    assert_equal 1, messages.count

    msg = messages.first
    saved_message_copy.each do |key, value|
      assert_equal value, msg.send(key)
    end
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
