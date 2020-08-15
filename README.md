# rubyeliza

> 🇺🇸 [English version below](#english)

ELIZA, o chatbot de 1966, reescrito em Ruby, com um adaptador pra rodar como bot de Telegram de verdade. É o projeto que eu uso pra explicar pros amigos que "IA que conversa" existe desde antes do homem pisar na lua: são regras, palavras-chave e um pouco de malandragem com pronomes.

```
$ ruby bin/chat
Eliza: Hello. I am Eliza. How are you feeling today?
You:   my name is Ana
Eliza: Nice to meet you, Ana.
You:   I want a new job
Eliza: Why do you want a new job?
You:   because my boss is always angry
Eliza: Can you think of a specific example?
```

No Telegram (cria o bot no @BotFather primeiro):

```sh
TELEGRAM_BOT_TOKEN=123456:ABC... ruby bin/chat telegram
```

## Como a mágica (não) acontece

1. Normaliza a frase: minúsculas, tira pontuação, expande contrações (`can't` vira `cannot`).
2. Cada regra tem uma palavra-chave e um peso; a de maior peso presente na frase ganha (`computer` bate `my`).
3. Decomposição: padrões com `*`, tipo `* i want *`, viram regex e são testados em ordem.
4. Reassembly: a resposta referencia os pedaços capturados com `(2)`, depois de *refletir* eles: `i love my dog` vira `you love your dog`. É esse truque que dá a sensação de que ela entendeu.
5. As respostas rodam pra não repetir, e regras com `memory: true` guardam algo pra puxar depois quando você disser uma frase sem palavra-chave nenhuma. Ela também aprende seu nome e usa de vez em quando.

As regras são dados Ruby (`ElizaBot::DEFAULT_SCRIPT`), então dá pra trocar a personalidade inteira:

```ruby
script = [{ keyword: 'pizza', decompositions: [{ pattern: '* pizza *', responses: ['Pizza with (2)?'] }] }]
ElizaBot.new(script: script).respond('I want pizza with extra cheese')  # => "Pizza with extra cheese?"
```

O `TelegramAdapter` usa long polling na Bot API (`getUpdates`/`sendMessage`) só com `Net::HTTP`, guarda um `ElizaBot` por chat (cada conversa tem sua memória) e aceita uma função HTTP injetável, que é como os testes rodam sem internet.

Testes: `for f in test/*.rb; do ruby -Ilib -Itest "$f"; done`.

---

## English

ELIZA, the 1966 chatbot, rewritten in Ruby, with an adapter to run it as a real Telegram bot. It's the project I use to explain to friends that "AI that talks" has existed since before man set foot on the moon: it's rules, keywords and a bit of trickery with pronouns.

```
$ ruby bin/chat
Eliza: Hello. I am Eliza. How are you feeling today?
You:   my name is Ana
Eliza: Nice to meet you, Ana.
You:   I want a new job
Eliza: Why do you want a new job?
You:   because my boss is always angry
Eliza: Can you think of a specific example?
```

On Telegram (create the bot with @BotFather first):

```sh
TELEGRAM_BOT_TOKEN=123456:ABC... ruby bin/chat telegram
```

## How the magic (doesn't) happen

1. Normalize the sentence: lowercase, strip punctuation, expand contractions (`can't` becomes `cannot`).
2. Every rule has a keyword and a weight; the heaviest one present in the sentence wins (`computer` beats `my`).
3. Decomposition: patterns with `*`, like `* i want *`, become regexes and are tried in order.
4. Reassembly: the answer references the captured pieces with `(2)`, after *reflecting* them: `i love my dog` becomes `you love your dog`. That's the trick that gives the feeling she understood you.
5. Answers rotate so they don't repeat, and rules with `memory: true` store something to pull out later when you say a sentence with no keyword at all. She also learns your name and uses it once in a while.

The rules are Ruby data (`ElizaBot::DEFAULT_SCRIPT`), so you can swap the whole personality:

```ruby
script = [{ keyword: 'pizza', decompositions: [{ pattern: '* pizza *', responses: ['Pizza with (2)?'] }] }]
ElizaBot.new(script: script).respond('I want pizza with extra cheese')  # => "Pizza with extra cheese?"
```

The `TelegramAdapter` uses long polling on the Bot API (`getUpdates`/`sendMessage`) with nothing but `Net::HTTP`, keeps one `ElizaBot` per chat (each conversation has its own memory) and accepts an injectable HTTP function, which is how the tests run without internet.

Tests: `for f in test/*.rb; do ruby -Ilib -Itest "$f"; done`.

MIT.
