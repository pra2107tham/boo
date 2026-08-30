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

Tick **On desktop** in that panel and Boo hops out of the menu bar into a floating window you
can drag anywhere. It stays on top, follows you between Spaces, and remembers where you put it.
Right-click it to send it back.

## What it does when it's out

- **Watches your cursor.** Eyes follow your pointer around the screen.
- **Click it** and it showers hearts.
- **Dances** when music is playing — any music, through any device.
- **Hover for a couple of seconds** and it takes it as petting.
- **Drag it** and it squashes, then wobbles when you let go.
- **Falls asleep** if you leave for five minutes, wakes when you come back.
- **Cheers** when a long build finishes.
- **Startles you** now and then, if you tick **Spooky**. Off by default.
- **Swoops in every five minutes** to whisper "ssshhh… focus". Tick **Nudges** to turn it off.
- **Eight idle antics** — spins, yawns, sneezes, wobbles, bounces, stargazes — picked at
  random every 25–70 seconds so it never reads as a loop.
- **Laps your cursor** — double-click it and it shrinks to cursor size, flies over, does
  three laps with a comet trail, and drifts home
- **Three scratchpad bubbles** appear on hover — park a room number, a name, a command.
  Click to type, right-click to copy or clear. They survive restarts.
- **Shows what is playing** as the real app icon in a thought cloud, so you can see at a
  glance whether the sound is Spotify, Music, a browser tab or a call.

## Website

`web/` is the landing page — Next.js, statically exported.

```bash
cd web && npm install && npm run dev
```

## Install

Download the latest DMG from [Releases](https://github.com/pra2107tham/boo/releases),
open it, and drag Boo to Applications.

macOS will say it cannot verify Boo. That is Gatekeeper: it says the same about every
app not notarised by Apple, which needs a paid developer account. Boo is open source,
so you can read every line it runs.

After dragging it to Applications, run this once:

```bash
xattr -dr com.apple.quarantine /Applications/Boo.app
```

That removes the "downloaded from the internet" flag, and Boo opens normally from then on.

If you would rather not use Terminal: right-click Boo in Applications and choose **Open**,
then confirm. If macOS only offers "Move to Trash", open System Settings → Privacy &
Security and click **Open Anyway**.

Or build it yourself:

```bash
git clone https://github.com/pra2107tham/boo.git
cd boo
swift run -c release
```

Needs macOS 14 or later. No permissions, no entitlements, no login item — every signal comes
from a public API that asks you for nothing.

To build the app bundle and DMG locally:

```bash
./scripts/build-app.sh 1.0.0
```

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
