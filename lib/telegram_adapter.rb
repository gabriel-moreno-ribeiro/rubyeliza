# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# Connects an ElizaBot to Telegram using long polling on the Bot API.
# One ElizaBot instance is kept per chat so each conversation has its own memory.
class TelegramAdapter
  API = 'https://api.telegram.org'

  def initialize(token, bot_factory: -> { ElizaBot.new }, http: nil, logger: $stderr)
    raise ArgumentError, 'token is required' if token.nil? || token.empty?

    @token = token
    @bot_factory = bot_factory
    @http = http || method(:default_http)
    @logger = logger
    @bots = {}
    @offset = nil
  end

  # Runs forever (or until the block returns false, used by tests).
  def run
    loop do
      updates = call('getUpdates', timeout: 30, offset: @offset)
      updates.each { |u| handle_update(u) }
      break if block_given? && !yield
    end
  end

  def handle_update(update)
    @offset = update['update_id'] + 1
    msg = update['message'] || return
    chat_id = msg.dig('chat', 'id')
    text = msg['text'] || return
    reply = reply_for(chat_id, text)
    call('sendMessage', chat_id: chat_id, text: reply)
    reply
  end

  def reply_for(chat_id, text)
    return ElizaBot::GREETING if text == '/start'

    bot = (@bots[chat_id] ||= @bot_factory.call)
    bot.respond(text)
  end

  private

  def call(method_name, **params)
    body = @http.call("#{API}/bot#{@token}/#{method_name}", params)
    body['result'] || []
  end

  def default_http(url, params)
    uri = URI(url)
    res = Net::HTTP.post(uri, JSON.generate(params), 'Content-Type' => 'application/json')
    JSON.parse(res.body)
  rescue StandardError => e
    @logger.puts("telegram error: #{e.message}")
    {}
  end
end
