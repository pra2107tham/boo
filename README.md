# Boo

A small ghost that lives in your Mac's menu bar and quietly minds how your machine is doing.

**The eyes carry the mood. The heart carries the load.** Splitting the job in two is what keeps
it readable at 18 pixels.

- Heart shifts green → amber → red with CPU, and beats faster the harder your Mac works
- Eyes strain when the CPU is buried, close when the battery is low, go happy when you plug in
- Puts on headphones when you connect headphones
- Blinks and glances around on its own

Click it for a small panel: CPU, memory, battery, audio output. Nothing else. It reports, it
doesn't nag — no badges, no "issues found", no upgrade prompt.

## Install

```bash
git clone https://github.com/pra2107tham/boo.git
cd boo
swift run -c release
```

Needs macOS 14 or later. No permissions, no entitlements, no login item — every signal comes
from a public API that asks you for nothing.

## Why it's light

Native SwiftUI, zero dependencies. The whole face is drawn as vector shapes in code, so every
expression is a few lines and animations cost nothing. A menu bar pet that eats 200 MB of RAM
would defeat the purpose.

## Design

The full design — character sheet, panel, and build spec — is at
[claude.ai/code/artifact/a010c2c2-812b-438c-a380-49f803af2b04](https://claude.ai/code/artifact/a010c2c2-812b-438c-a380-49f803af2b04).

`brief/` holds the prompts used to explore the character, if you want to see how Boo was found.

## Checks

```bash
swift run Boo --self-check
```

Covers the parts that fail quietly: threshold flapping, headphone name matching,
and the top-process baseline.

## Adding a mood

Moods are cases on one enum with a matching set of eye shapes. Adding one is roughly ten lines
in `Face.swift` plus a rule in `MoodEngine.swift`. PRs welcome.

## License

MIT — see [LICENSE](LICENSE).
