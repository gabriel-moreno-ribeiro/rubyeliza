# rubyeliza

A conversational bot written from scratch in Ruby, in the spirit of Joseph
Weizenbaum's ELIZA, with a Telegram adapter so it can run as a real chat bot.
No gems required beyond the Ruby standard library.

## Try it

```sh
ruby bin/chat
```

```
Eliza: Hello. I am Eliza. How are you feeling today?
You:   my name is Ana
Eliza: Nice to meet you, Ana.
You:   I want a new job
Eliza: Why do you want a new job?
You:   because my boss is always angry
Eliza: Can you think of a specific example?
```

Run it on Telegram (create a bot with @BotFather first):

```sh
TELEGRAM_BOT_TOKEN=123456:ABC... ruby bin/chat telegram
```

## How the engine works

1. **Normalise**: lowercase, strip punctuation, expand contractions
   (`can't` -> `cannot`) so patterns stay simple.
2. **Keyword ranking**: every rule has a keyword and a rank. The highest
   ranked keyword found in the sentence is used (`computer` beats `my`).
3. **Decomposition**: each keyword has patterns with `*` wildcards, such as
   `* i want *`. They are compiled to regexes and tried in order.
4. **Reassembly**: the reply template refers to captured fragments with `(2)`,
   and the fragment is *reflected* first: `i love my dog` -> `you love your dog`.
5. **Rotation and memory**: responses rotate so the bot does not repeat itself,
   and rules marked `memory: true` store a reply to bring up later when the
   user says something with no keyword.
6. **Personalisation**: the bot picks up the user's name and uses it sometimes.

Rules are plain Ruby data (`ElizaBot::DEFAULT_SCRIPT`), so you can give the
bot a completely different personality:

```ruby
script = [{ keyword: 'pizza', decompositions: [{ pattern: '* pizza *', responses: ['Pizza with (2)?'] }] }]
ElizaBot.new(script: script).respond('I want pizza with extra cheese')
# => "Pizza with extra cheese?"
```

## Telegram adapter

`TelegramAdapter` uses long polling on the Bot API (`getUpdates` /
`sendMessage`) with `Net::HTTP`, keeps one `ElizaBot` per chat so every
conversation has its own memory, and accepts an injectable HTTP function so
it can be tested offline.

## Tests

```sh
for f in test/*.rb; do ruby -Ilib -Itest "$f"; done
```

## License

MIT
