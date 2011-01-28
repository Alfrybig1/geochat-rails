# coding: utf-8

require 'unit/pipeline_test'

class LocationTest < PipelineTest
  test "place" do
    create_users 1..4

    send_message 1, "create Group1"
    send_message 2..4, "join Group1"

    Geocoder.expects(:locate).with('Paris').returns([48.856667, 2.350987])
    send_message 1, "at Paris"
    assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
    assert_messages_sent_to 2..4, "User1: at Paris (lat: 48.856667, lon: 2.350987)"
    assert_user_location "User1", "Paris", 48.856667, 2.350987
    assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2.350987
  end

  test "place with message" do
    create_users 1..4

    send_message 1, "create Group1"
    send_message 2..4, "join Group1"

    Geocoder.expects(:locate).with('Paris').returns([48.856667, 2.350987])
    send_message 1, "/Paris/ Hello!"
    assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
    assert_messages_sent_to 2..4, "User1: Hello! (at Paris, lat: 48.856667, lon: 2.350987)"
    assert_user_location "User1", "Paris", 48.856667, 2.350987
    assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2.350987
  end

  ['at 48.856667 2.350987', 'at 48.856667, 2.350987'].each do |msg|
    test "lat/lon #{msg}" do
      create_users 1..4

      send_message 1, "create Group1"
      send_message 2..4, "join Group1"

      Geocoder.expects(:reverse).with([48.856667, 2.350987]).returns("Paris")
      send_message 1, msg
      assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
      assert_messages_sent_to 2..4, "User1: at Paris (lat: 48.856667, lon: 2.350987)"
      assert_user_location "User1", "Paris", 48.856667, 2.350987
      assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2350987
    end

    test "lat/lon with message #{msg}" do
      create_users 1..4

      send_message 1, "create Group1"
      send_message 2..4, "join Group1"

      Geocoder.expects(:reverse).with([48.856667, 2.350987]).returns("Paris")
      send_message 1, "#{msg} Hello!"
      assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
      assert_messages_sent_to 2..4, "User1: Hello! (at Paris, lat: 48.856667, lon: 2.350987)"
      assert_user_location "User1", "Paris", 48.856667, 2.350987
      assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2350987
    end

    test "lat/lon to group #{msg}" do
      create_users 1..4

      send_message 1, "create Group1"
      send_message 2..4, "join Group1"

      Geocoder.expects(:reverse).with([48.856667, 2.350987]).returns("Paris")
      send_message 1, "Group1 #{msg}"
      assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
      assert_messages_sent_to 2..4, "User1: at Paris (lat: 48.856667, lon: 2.350987)"
      assert_user_location "User1", "Paris", 48.856667, 2.350987
      assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2350987
    end

    test "lat/lon to group with message #{msg}" do
      create_users 1..4

      send_message 1, "create Group1"
      send_message 2..4, "join Group1"

      Geocoder.expects(:reverse).with([48.856667, 2.350987]).returns("Paris")
      send_message 1, "Group1 #{msg} Hello!"
      assert_messages_sent_to 1, "Your location was successfully updated to Paris (lat: 48.856667, lon: 2.350987)"
      assert_messages_sent_to 2..4, "User1: Hello! (at Paris, lat: 48.856667, lon: 2.350987)"
      assert_user_location "User1", "Paris", 48.856667, 2.350987
      assert_message_saved_as_blast_with_location 1, "Group1", "Hello!", "Paris", 48.4856667, 2350987
    end
  end

  # TODO USNG

  # TODO custom locations

end
