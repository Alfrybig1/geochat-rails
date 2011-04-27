# coding: utf-8

require 'unit/node_test'

class ExternalServiceTest < NodeTest
  setup do
    create_users 1..2
    send_message 1, "create Group1"
    send_message 2, "join Group1"

    group = Group.find_by_alias 'Group1'
    group.external_service_url = 'http://example.com'
    group.save!

    @options = {:from => 'sms://1', :to => 'geochat://system', :sender => 'User1'}
  end

  test "external service stop" do
    HTTParty.expects(:post).with("http://example.com?#{@options.to_query}", :body => 'something').returns(stub(:headers => {'x-geochat-action' => 'stop'}, :body => nil))

    send_message 1, "something"
    assert_no_messages_sent_to 1..2
    assert_no_messages_saved
  end

  test "external service continue" do
    HTTParty.expects(:post).with("http://example.com?#{@options.to_query}", :body => 'something').returns(stub(:headers => {'x-geochat-action' => 'continue'}, :body => nil))

    send_message 1, "something"
    assert_no_messages_sent_to 1
    assert_messages_sent_to 2, "User1: something", :group => 'Group1'
    assert_message_saved 'User1', 'Group1', 'something'
  end

  test "external service continue and replace with" do
    HTTParty.expects(:post).with("http://example.com?#{@options.to_query}", :body => 'something').returns(stub(:headers => {'x-geochat-action' => 'continue', 'x-geochat-replacewith' => 'abracadabra'}, :body => nil))

    send_message 1, "something"
    assert_no_messages_sent_to 1
    assert_messages_sent_to 2, "User1: abracadabra", :group => 'Group1'
    assert_message_saved 'User1', 'Group1', 'abracadabra'
  end

  test "external service continue and replace backwards compatible" do
    HTTParty.expects(:post).with("http://example.com?#{@options.to_query}", :body => 'something').returns(stub(:headers => {'x-geochat-action' => 'continue', 'x-geochat-replace' => 'true'}, :body => 'abracadabra'))

    send_message 1, "something"
    assert_no_messages_sent_to 1
    assert_messages_sent_to 2, "User1: abracadabra", :group => 'Group1'
    assert_message_saved 'User1', 'Group1', 'abracadabra'
  end

  test "external service reply and stop" do
    HTTParty.expects(:post).with("http://example.com?#{@options.to_query}", :body => 'something').returns(stub(:headers => {'x-geochat-action' => 'reply'}, :body => 'abracadabra'))

    send_message 1, "something"
    assert_messages_sent_to 1, "abracadabra", :group => 'Group1'
    assert_no_messages_sent_to 2
    assert_no_messages_saved
  end
end
