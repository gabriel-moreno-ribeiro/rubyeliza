# frozen_string_literal: true

# ElizaBot - a rule-based conversational bot written from scratch in Ruby.
#
# The engine works the way Joseph Weizenbaum's original ELIZA did:
#   1. normalise the input and expand contractions
#   2. find the highest-ranked keyword present in the sentence
#   3. try that keyword's decomposition patterns (with wildcards) in order
#   4. reassemble a reply from the matched fragments, "reflecting" pronouns
#      (I -> you, my -> your ...) so the reply talks back to the user
#   5. fall back to memory (something the user said earlier) or a generic prompt
#
# Rules are plain Ruby data (see DEFAULT_SCRIPT), so the personality can be
# swapped or extended without touching the engine.
class ElizaBot
  Rule = Struct.new(:keyword, :rank, :decompositions, keyword_init: true)
  Decomposition = Struct.new(:pattern, :responses, :memory, keyword_init: true)

  REFLECTIONS = {
    'am' => 'are', 'was' => 'were', 'i' => 'you', 'i\'d' => 'you would',
    'i\'ve' => 'you have', 'i\'ll' => 'you will', 'my' => 'your', 'are' => 'am',
    'you\'ve' => 'I have', 'you\'ll' => 'I will', 'your' => 'my', 'yours' => 'mine',
    'you' => 'me', 'me' => 'you', 'myself' => 'yourself', 'yourself' => 'myself'
  }.freeze

  CONTRACTIONS = {
    "don't" => 'do not', "can't" => 'cannot', "won't" => 'will not', "i'm" => 'i am',
    "it's" => 'it is', "that's" => 'that is', "isn't" => 'is not', "aren't" => 'are not',
    "didn't" => 'did not', "doesn't" => 'does not', "wasn't" => 'was not', "i've" => 'i have',
    "i'd" => 'i would', "i'll" => 'i will', "you're" => 'you are', "they're" => 'they are',
    "we're" => 'we are', "haven't" => 'have not', "hasn't" => 'has not', "couldn't" => 'could not',
    "shouldn't" => 'should not', "wouldn't" => 'would not'
  }.freeze

  FALLBACKS = [
    'Please go on.',
    'Tell me more about that.',
    'I see. What does that suggest to you?',
    'Can you elaborate on that?',
    'How does that make you feel?',
    'Why do you say that?'
  ].freeze

  GREETING = 'Hello. I am Eliza. How are you feeling today?'
  GOODBYE = 'Goodbye. It was nice talking to you.'

  attr_reader :script, :memory, :name

  def initialize(script: DEFAULT_SCRIPT, random: Random.new)
    @script = script.map { |r| build_rule(r) }.sort_by { |r| -r.rank }
    @random = random
    @memory = []
    @name = nil
    @last_reply = nil
    @counters = Hash.new(0)
  end

  # Main entry point: returns the bot's reply to one user message.
  def respond(input)
    text = normalise(input)
    return GOODBYE if quit?(text)
    return 'You have not said anything yet.' if text.empty?

    remember_name(text)
    reply = try_rules(text) || recall_memory || pick(FALLBACKS)
    reply = personalise(reply)
    @last_reply = reply
  end

  # Converts "I love my dog" into "you love your dog".
  def reflect(fragment)
    fragment.split.map { |w| REFLECTIONS.fetch(w.downcase, w) }.join(' ')
  end

  def normalise(input)
    text = input.to_s.downcase.strip
    text = text.gsub(/[^\w\s']/, ' ').gsub(/\s+/, ' ').strip
    CONTRACTIONS.each { |from, to| text = text.gsub(/\b#{Regexp.escape(from)}\b/, to) }
    text
  end

  private

  def build_rule(hash)
    decomps = hash[:decompositions].map do |d|
      Decomposition.new(pattern: compile_pattern(d[:pattern]), responses: d[:responses], memory: d[:memory] || false)
    end
    Rule.new(keyword: hash[:keyword], rank: hash[:rank] || 0, decompositions: decomps)
  end

  # "* my *" => /\A(.*)\bmy\b(.*)\z/ ; "*" alone matches everything.
  def compile_pattern(pattern)
    parts = pattern.split('*', -1).map { |p| Regexp.escape(p.strip) }
    body = parts.map { |part| part.empty? ? '' : "\\b#{part}\\b" }.join('(.*?)')
    body = '(.*)' if pattern.strip == '*'
    Regexp.new("\\A\\s*#{body}\\s*\\z", Regexp::IGNORECASE)
  end

  def quit?(text)
    %w[bye goodbye quit exit].include?(text)
  end

  def remember_name(text)
    if (m = text.match(/\b(?:my name is|i am called|call me) (\w+)/))
      @name = m[1].capitalize
    end
  end

  def try_rules(text)
    @script.each do |rule|
      next unless text.match?(/\b#{Regexp.escape(rule.keyword)}\b/)
      rule.decompositions.each do |decomp|
        m = text.match(decomp.pattern)
        next unless m
        groups = m.captures.map { |c| reflect(c.to_s.strip) }
        reply = fill(next_response(rule, decomp), groups)
        @memory << reply if decomp.memory
        return reply
      end
    end
    nil
  end

  # Cycle through responses so the bot does not repeat itself immediately.
  def next_response(rule, decomp)
    key = [rule.keyword, decomp.pattern.source]
    responses = decomp.responses
    idx = @counters[key] % responses.size
    @counters[key] += 1
    responses[idx]
  end

  def fill(template, groups)
    out = template.gsub('(name)', @name.to_s)
    out = out.gsub(/\(\d+\)/) { |ref| groups[ref[1..-2].to_i - 1].to_s }
    out = out.gsub(/\s+/, ' ').strip
    out.sub(/\A(\w)/) { ::Regexp.last_match(1).upcase }
  end

  def recall_memory
    return nil if @memory.empty? || @random.rand > 0.4
    @memory.shift
  end

  def personalise(reply)
    return reply unless @name && @random.rand < 0.3
    "#{@name}, #{reply[0].downcase}#{reply[1..]}"
  end

  def pick(list)
    list[@random.rand(list.size)]
  end

  DEFAULT_SCRIPT = [
    { keyword: 'sorry', rank: 1, decompositions: [
      { pattern: '*', responses: ['Please do not apologise.', 'Apologies are not necessary.', 'What feelings do you have when you apologise?'] }
    ] },
    { keyword: 'remember', rank: 5, decompositions: [
      { pattern: '* i remember *', responses: ['Do you often think of (2)?', 'What else do you recollect?', 'Why do you remember (2) just now?'] },
      { pattern: '* do you remember *', responses: ['Did you think I would forget (2)?', 'What about (2)?', 'You mentioned (2).'] },
      { pattern: '*', responses: ['What do you remember?'] }
    ] },
    { keyword: 'if', rank: 3, decompositions: [
      { pattern: '* if *', responses: ['Do you think it is likely that (2)?', 'Do you wish that (2)?', 'What do you know about (2)?', 'Really, if (2)?'] }
    ] },
    { keyword: 'dreamed', rank: 4, decompositions: [
      { pattern: '* i dreamed *', responses: ['Really, (2)?', 'Have you ever fantasized (2) while you were awake?', 'Have you ever dreamed (2) before?'] }
    ] },
    { keyword: 'dream', rank: 3, decompositions: [
      { pattern: '*', responses: ['What does that dream suggest to you?', 'Do you dream often?', 'What persons appear in your dreams?', 'Do you believe that dreams have something to do with your problem?'] }
    ] },
    { keyword: 'perhaps', rank: 0, decompositions: [
      { pattern: '*', responses: ['You do not seem quite certain.', 'Why the uncertain tone?', 'Can you not be more positive?', 'You are not sure?'] }
    ] },
    { keyword: 'name', rank: 15, decompositions: [
      { pattern: '* my name is *', responses: ['Nice to meet you, (name).', 'Hello (name). What brings you here today?'] },
      { pattern: '* your name *', responses: ['My name is Eliza.', 'I am Eliza. Names are not important, though. Tell me about yourself.'] },
      { pattern: '*', responses: ['I am not interested in names.', 'Names do not interest me.'] }
    ] },
    { keyword: 'hello', rank: 0, decompositions: [{ pattern: '*', responses: ['How do you do. Please state your problem.', 'Hi. What seems to be your problem?'] }] },
    { keyword: 'hi', rank: 0, decompositions: [{ pattern: '*', responses: ['How do you do. Please state your problem.', 'Hi. What seems to be your problem?'] }] },
    { keyword: 'computer', rank: 50, decompositions: [
      { pattern: '*', responses: ['Do computers worry you?', 'Why do you mention computers?', 'What do you think machines have to do with your problem?', 'Do not you think computers can help people?'] }
    ] },
    { keyword: 'am', rank: 0, decompositions: [
      { pattern: '* am i *', responses: ['Do you believe you are (2)?', 'Would you want to be (2)?', 'What would it mean if you were (2)?'] },
      { pattern: '* i am *', responses: ['How long have you been (2)?', 'Do you enjoy being (2)?', 'Why do you tell me you are (2)?', 'Do you believe it is normal to be (2)?'] },
      { pattern: '*', responses: ['Why do you say "am"?', 'I do not understand that.'] }
    ] },
    { keyword: 'are', rank: 0, decompositions: [
      { pattern: '* are you *', responses: ['Why are you interested in whether I am (2) or not?', 'Would you prefer if I were not (2)?', 'Perhaps I am (2) in your fantasies.', 'Do you sometimes think I am (2)?'] },
      { pattern: '* are *', responses: ['Did you think they might not be (2)?', 'Would you like it if they were not (2)?', 'What if they were not (2)?', 'Possibly they are (2).'] }
    ] },
    { keyword: 'your', rank: 0, decompositions: [
      { pattern: '* your *', responses: ['Why are you concerned over my (2)?', 'What about your own (2)?', 'Are you worried about someone else\'s (2)?', 'Really, my (2)?'] }
    ] },
    { keyword: 'was', rank: 2, decompositions: [
      { pattern: '* was i *', responses: ['What if you were (2)?', 'Do you think you were (2)?', 'Were you (2)?', 'What would it mean if you were (2)?'] },
      { pattern: '* i was *', responses: ['Were you really?', 'Why do you tell me you were (2) now?', 'Perhaps I already know you were (2).'] },
      { pattern: '* was you *', responses: ['Would you like to believe I was (2)?', 'What suggests that I was (2)?', 'What do you think?', 'Perhaps I was (2).'] }
    ] },
    { keyword: 'i', rank: 0, decompositions: [
      { pattern: '* i want *', responses: ['What would it mean to you if you got (2)?', 'Why do you want (2)?', 'Suppose you got (2) soon.', 'What if you never got (2)?'], memory: true },
      { pattern: '* i need *', responses: ['Why do you need (2)?', 'Would it really help you to get (2)?', 'Are you sure you need (2)?'] },
      { pattern: '* i am sad *', responses: ['I am sorry to hear that you are sad.', 'Do you think coming here will help you not to be sad?', 'I am sure it is not pleasant to be sad.'] },
      { pattern: '* i am happy *', responses: ['How have I helped you to be happy?', 'Has your treatment made you happy?', 'What makes you happy just now?'] },
      { pattern: '* i feel *', responses: ['Tell me more about such feelings.', 'Do you often feel (2)?', 'Do you enjoy feeling (2)?', 'Of what does feeling (2) remind you?'] },
      { pattern: '* i think *', responses: ['Do you doubt that (2)?', 'Do you really think so?', 'But you are not sure that (2)?'] },
      { pattern: '* i cannot *', responses: ['How do you know that you cannot (2)?', 'Have you tried?', 'Perhaps you could (2) now.', 'Do you really want to be able to (2)?'] },
      { pattern: '* i do not *', responses: ['Do not you really (2)?', 'Why do not you (2)?', 'Do you wish to be able to (2)?', 'Does that trouble you?'] },
      { pattern: '* i *', responses: ['You say (2)?', 'Can you elaborate on that?', 'Do you say (2) for some special reason?', 'That is quite interesting.'] }
    ] },
    { keyword: 'you', rank: 0, decompositions: [
      { pattern: '* you remind me of *', responses: ['What resemblance do you see?', 'What does that resemblance suggest to you?'] },
      { pattern: '* you are *', responses: ['What makes you think I am (2)?', 'Does it please you to believe I am (2)?', 'Do you sometimes wish you were (2)?', 'Perhaps you would like to be (2).'] },
      { pattern: '* you *', responses: ['We were discussing you, not me.', 'Oh, I (2)?', 'You are not really talking about me, are you?', 'What are your feelings now?'] }
    ] },
    { keyword: 'yes', rank: 0, decompositions: [{ pattern: '*', responses: ['You seem to be quite positive.', 'You are sure.', 'I see.', 'I understand.'] }] },
    { keyword: 'no', rank: 0, decompositions: [{ pattern: '*', responses: ['Are you saying no just to be negative?', 'You are being a bit negative.', 'Why not?', 'Why no?'] }] },
    { keyword: 'my', rank: 2, decompositions: [
      { pattern: '* my *', responses: ['Your (2)?', 'Why do you say your (2)?', 'Does that have anything to do with the fact that your (2)?', 'Is it important to you that your (2)?'], memory: true }
    ] },
    { keyword: 'can', rank: 0, decompositions: [
      { pattern: '* can you *', responses: ['You believe I can (2), do not you?', 'You want me to be able to (2).', 'Perhaps you would like to be able to (2) yourself.'] },
      { pattern: '* can i *', responses: ['Whether or not you can (2) depends on you more than on me.', 'Do you want to be able to (2)?', 'Perhaps you do not want to (2).'] }
    ] },
    { keyword: 'what', rank: 0, decompositions: [
      { pattern: '*', responses: ['Why do you ask?', 'Does that question interest you?', 'What is it you really want to know?', 'What answer would please you most?', 'What do you think?'] }
    ] },
    { keyword: 'why', rank: 0, decompositions: [
      { pattern: '* why do not you *', responses: ['Do you believe I do not (2)?', 'Perhaps I will (2) in good time.', 'Should you (2) yourself?', 'You want me to (2)?'] },
      { pattern: '* why cannot i *', responses: ['Do you think you should be able to (2)?', 'Do you want to be able to (2)?', 'Do you believe this will help you to (2)?'] },
      { pattern: '*', responses: ['Why do you ask?', 'What is it you really want to know?', 'Why indeed?'] }
    ] },
    { keyword: 'everyone', rank: 2, decompositions: [
      { pattern: '*', responses: ['Really, everyone?', 'Surely not everyone.', 'Can you think of anyone in particular?', 'Who, for example?'] }
    ] },
    { keyword: 'always', rank: 1, decompositions: [
      { pattern: '*', responses: ['Can you think of a specific example?', 'When?', 'What incident are you thinking of?', 'Really, always?'] }
    ] },
    { keyword: 'because', rank: 0, decompositions: [
      { pattern: '*', responses: ['Is that the real reason?', 'Do not any other reasons come to mind?', 'Does that reason seem to explain anything else?', 'What other reasons might there be?'] }
    ] },
    { keyword: 'mother', rank: 10, decompositions: [
      { pattern: '*', responses: ['Tell me more about your family.', 'Who else in your family?', 'Your mother?', 'What else comes to mind when you think of your mother?'], memory: true }
    ] },
    { keyword: 'father', rank: 10, decompositions: [
      { pattern: '*', responses: ['Tell me more about your family.', 'Who else in your family?', 'Your father?', 'What else comes to mind when you think of your father?'], memory: true }
    ] }
  ].freeze
end
