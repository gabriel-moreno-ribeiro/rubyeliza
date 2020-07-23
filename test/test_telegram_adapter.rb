# frozen_string_literal: true

require 'minitest/autorun'
require 'eliza_bot'
require 'telegram_adapter'

class TestTelegramAdapter < Minitest::Test
  def setup
    @calls = []
    fake_http = lambda do |url, params|
      @calls << [url.split('/').last, params]
      if url.end_with?('getUpdates')
        { 'ok' => true, 'result' => [
          { 'update_id' => 7, 'message' => { 'chat' => { 'id' => 42 }, 'text' => 'I want coffee' } }
        ] }
      else
        { 'ok' => true, 'result' => {} }
      end
    end
    @adapter = TelegramAdapter.new('123:abc', http: fake_http,
                                              bot_factory: -> { ElizaBot.new(random: Random.new(1)) })
  end

  def test_requires_token
    assert_raises(ArgumentError) { TelegramAdapter.new('') }
  end

  def test_start_command_greets
    assert_equal ElizaBot::GREETING, @adapter.reply_for(1, '/start')
  end

  def test_handles_update_and_sends_reply
    reply = @adapter.handle_update('update_id' => 7, 'message' => { 'chat' => { 'id' => 42 }, 'text' => 'I want coffee' })
    assert_equal 'What would it mean to you if you got coffee?', reply
    method, params = @calls.last
    assert_equal 'sendMessage', method
    assert_equal({ chat_id: 42, text: 'What would it mean to you if you got coffee?' }, params)
  end

  def test_run_polls_with_offset
    @adapter.run { false }
    assert_equal 'getUpdates', @calls.first[0]
    assert_equal 'sendMessage', @calls.last[0]
    @adapter.run { false }
    assert_equal 8, @calls[2][1][:offset]
  end

  def test_separate_memory_per_chat
    @adapter.reply_for(1, 'my name is Bo')
    @adapter.reply_for(2, 'hello')
    @adapter.reply_for(1, 'yes')
    bots = @adapter.instance_variable_get(:@bots)
    assert_equal 'Bo', bots[1].name
    assert_nil bots[2].name
  end
end
