# rubyeliza

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

**EN:** Weizenbaum's ELIZA in plain Ruby (standard library only) with a Telegram adapter. Keyword ranking, wildcard decomposition patterns compiled to regexes, pronoun reflection in the reassembly step, response rotation and the "memory" trick, plus per-chat bots over the Telegram Bot API with long polling. Scripts are plain data, so the personality is swappable. MIT.
