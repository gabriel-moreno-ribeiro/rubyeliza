# frozen_string_literal: true

require 'minitest/autorun'
require 'eliza_bot'

class TestElizaBot < Minitest::Test
  def setup
    @bot = ElizaBot.new(random: Random.new(1))
  end

  def test_reflects_pronouns
    assert_equal 'you love your dog', @bot.reflect('i love my dog')
    assert_equal 'am me fine', @bot.reflect('are you fine')
  end

  def test_normalises_input
    assert_equal 'i am not happy', @bot.normalise("  I'm NOT happy!!  ")
    assert_equal 'i cannot sleep', @bot.normalise("I can't sleep.")
  end

  def test_keyword_with_capture
    assert_equal 'What would it mean to you if you got a new job?', @bot.respond('I want a new job')
    assert_equal 'Why do you want a new job?', @bot.respond('I want a new job')
  end

  def test_memory_keyword_captures_after_wildcard
    assert_equal 'Your cat is sick?', @bot.respond('I think my cat is sick')
  end

  def test_responses_rotate
    first = @bot.respond('yes')
    second = @bot.respond('yes')
    refute_equal first, second
  end

  def test_ranked_keyword_wins
    # "computer" outranks "i" and "my"
    assert_equal 'Do computers worry you?', @bot.respond('I think my computer hates me')
  end

  def test_name_is_remembered
    reply = @bot.respond('My name is Ana')
    assert_equal 'Nice to meet you, Ana.', reply
    assert_equal 'Ana', @bot.name
  end

  def test_quit_words
    assert_equal ElizaBot::GOODBYE, @bot.respond('bye')
    assert_equal ElizaBot::GOODBYE, @bot.respond('Quit')
  end

  def test_empty_input
    assert_equal 'You have not said anything yet.', @bot.respond('   ')
  end

  def test_fallback_when_no_keyword
    reply = @bot.respond('blue trees')
    assert_includes ElizaBot::FALLBACKS, reply
  end

  def test_memory_is_recalled_later
    bot = ElizaBot.new(random: Random.new(1))
    bot.respond('my car is broken')
    assert_equal 1, bot.memory.size
    recalled = 20.times.map { bot.respond('zzz qqq') }
    assert_includes recalled, 'Your car is broken?'
  end

  def test_custom_script
    script = [{ keyword: 'pizza', decompositions: [{ pattern: '* pizza *', responses: ['Pizza (2)?'] }] }]
    bot = ElizaBot.new(script: script)
    assert_equal 'Pizza with extra cheese?', bot.respond('I want pizza with extra cheese')
  end

  def test_reply_starts_with_capital_letter
    assert_match(/\A[A-Z]/, @bot.respond('i feel tired'))
  end
end
