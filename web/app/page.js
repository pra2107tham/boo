import './globals.css';
import { Ghost, Bloom } from './Ghost';

const REPO = 'https://github.com/pra2107tham/boo';
const DMG = `${REPO}/releases/latest/download/Boo-1.0.0.dmg`;

const MOODS = [
  { name: 'Calm', when: 'CPU under 30%', tint: 'calm', note: 'green heart, slow float' },
  { name: 'Working', when: 'a few things running', tint: 'busy', note: 'amber heart, faster beat' },
  { name: 'Struggling', when: 'CPU over 85%', tint: 'hot', note: 'strain brows, sweat drop' },
  { name: 'Tuned in', when: 'music is playing', tint: 'audio', note: 'headphones, bobbing' },
];

const ANTICS = [
  ['Peeks at your cursor', 'Its eyes follow your pointer around the screen.'],
  ['Swoops in to nag', 'Every so often it flies over and whispers “ssshhh… focus”.'],
  ['Showers hearts', 'Click it. That is the whole feature.'],
  ['Dances to your music', 'Detects real playback, then sways and drops little notes.'],
  ['Yawns, sneezes, spins', 'Eight idle antics, picked at random so it never loops.'],
  ['Falls asleep', 'Leave for five minutes and it dozes off. Wakes when you return.'],
  ['Squashes when dragged', 'Grab it and it squishes, then wobbles when you let go.'],
  ['Cheers your builds', 'When a long heavy job finishes, it celebrates with you.'],
];

export default function Home() {
  return (
    <>
      <Bloom />
      <div className="shell">
        {/* Nav — glass pill, the shape all three references share */}
        <header style={{ padding: '26px 0 0' }}>
          <div className="wrap" style={{ display: 'flex', justifyContent: 'center' }}>
            <nav
              className="glass"
              style={{
                display: 'flex', alignItems: 'center', gap: 26,
                padding: '10px 12px 10px 16px', borderRadius: 999,
              }}
            >
              <span style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                <Ghost size={22} animate={false} />
                <span className="display" style={{ fontSize: 19 }}>Boo</span>
              </span>
              <a href="#what" style={{ fontSize: 14, color: 'var(--ink-dim)' }}>What it does</a>
              <a href="#moods" style={{ fontSize: 14, color: 'var(--ink-dim)' }}>Moods</a>
              <a href={REPO} style={{ fontSize: 14, color: 'var(--ink-dim)' }}>Source</a>
              <a href={DMG} className="btn" style={{ padding: '9px 18px', fontSize: 13.5 }}>
                Download
              </a>
            </nav>
          </div>
        </header>

        {/* Hero */}
        <section className="wrap" style={{ padding: '86px 28px 74px', textAlign: 'center' }}>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 34 }}>
            <Ghost size={132} mood="calm" />
          </div>
          <h1 className="display" style={{ fontSize: 'clamp(46px, 8vw, 88px)' }}>
            A ghost that minds
            <br />
            how your Mac feels.
          </h1>
          <p
            style={{
              fontSize: 'clamp(16px, 2vw, 19px)', color: 'var(--ink-dim)',
              maxWidth: 560, margin: '26px auto 0', lineHeight: 1.6,
            }}
          >
            Boo lives in your menu bar. Its eyes carry the mood, its heart carries the
            load. It reports, it never nags.
          </p>
          <div
            style={{
              display: 'flex', gap: 12, justifyContent: 'center',
              marginTop: 38, flexWrap: 'wrap',
            }}
          >
            <a href={DMG} className="btn">
              <AppleMark />
              Download for macOS
            </a>
            <a href={REPO} className="btn btn-ghost">View source</a>
          </div>
          <p className="mono" style={{ fontSize: 12, color: 'var(--ink-faint)', marginTop: 20 }}>
            Free &amp; open source · MIT · macOS 14+ · about 500 KB
          </p>
        </section>

        {/* The panel, shown rather than described */}
        <section className="wrap" style={{ paddingBottom: 90, display: 'flex', justifyContent: 'center' }}>
          <PanelShot />
        </section>

        {/* What it does */}
        <section id="what" className="wrap" style={{ padding: '20px 28px 90px' }}>
          <p className="eyebrow" style={{ marginBottom: 14 }}>What it does when it is out</p>
          <h2 className="display" style={{ fontSize: 'clamp(32px, 4.5vw, 48px)', marginBottom: 40 }}>
            Small things, often.
          </h2>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(248px, 1fr))',
              gap: 14,
            }}
          >
            {ANTICS.map(([title, body]) => (
              <div key={title} className="glass" style={{ borderRadius: 18, padding: '22px 22px 24px' }}>
                <h3 style={{ fontSize: 15.5, fontWeight: 600, margin: '0 0 8px' }}>{title}</h3>
                <p style={{ fontSize: 13.5, color: 'var(--ink-dim)', margin: 0, lineHeight: 1.6 }}>
                  {body}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* Moods */}
        <section id="moods" className="wrap" style={{ padding: '0 28px 96px' }}>
          <p className="eyebrow" style={{ marginBottom: 14 }}>Moods</p>
          <h2 className="display" style={{ fontSize: 'clamp(32px, 4.5vw, 48px)', marginBottom: 40 }}>
            The eyes carry the mood.
            <br />
            The heart carries the load.
          </h2>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(184px, 1fr))',
              gap: 14,
            }}
          >
            {MOODS.map((m) => (
              <div
                key={m.name}
                className="glass"
                style={{
                  borderRadius: 20, padding: '28px 18px 22px',
                  display: 'flex', flexDirection: 'column',
                  alignItems: 'center', gap: 12, textAlign: 'center',
                }}
              >
                <Ghost size={62} mood={m.tint} animate={false} />
                <div className="display" style={{ fontSize: 22 }}>{m.name}</div>
                <div className="mono" style={{ fontSize: 11, color: 'var(--ink-faint)' }}>{m.when}</div>
                <div style={{ fontSize: 12.5, color: 'var(--ink-dim)' }}>{m.note}</div>
              </div>
            ))}
          </div>
        </section>

        {/* Honest install note */}
        <section className="wrap" style={{ padding: '0 28px 96px' }}>
          <div
            className="glass"
            style={{ borderRadius: 22, padding: '34px 34px 36px', maxWidth: 720, margin: '0 auto' }}
          >
            <p className="eyebrow" style={{ marginBottom: 12 }}>Installing</p>
            <h3 className="display" style={{ fontSize: 27, margin: '0 0 16px' }}>
              It is not signed by Apple yet.
            </h3>
            <p style={{ fontSize: 14.5, color: 'var(--ink-dim)', lineHeight: 1.7, margin: '0 0 18px' }}>
              Notarising needs a paid developer account, so the first time you open Boo macOS
              will warn you. Right-click the app and choose <strong style={{ color: 'var(--ink)' }}>Open</strong>,
              then confirm once. After that it launches normally.
            </p>
            <p style={{ fontSize: 14.5, color: 'var(--ink-dim)', lineHeight: 1.7, margin: 0 }}>
              Prefer to build it yourself? That is three lines:
            </p>
            <pre
              className="mono"
              style={{
                background: 'rgba(0,0,0,0.42)', border: '1px solid var(--line)',
                borderRadius: 12, padding: '16px 18px', fontSize: 12.5,
                color: 'var(--ink-dim)', overflowX: 'auto', marginTop: 14,
              }}
            >{`git clone ${REPO}.git
cd boo
swift run -c release`}</pre>
          </div>
        </section>

        {/* Privacy */}
        <section className="wrap" style={{ padding: '0 28px 96px', textAlign: 'center' }}>
          <h2 className="display" style={{ fontSize: 'clamp(30px, 4vw, 42px)', marginBottom: 18 }}>
            It asks you for nothing.
          </h2>
          <p
            style={{
              fontSize: 15.5, color: 'var(--ink-dim)', maxWidth: 580,
              margin: '0 auto', lineHeight: 1.7,
            }}
          >
            No permissions, no entitlements, no account, no network calls. Every reading
            comes from a public macOS API that needs no prompt. Nothing leaves your Mac,
            because nothing is ever sent anywhere.
          </p>
        </section>

        <footer style={{ borderTop: '1px solid var(--line)', padding: '30px 0 44px' }}>
          <div
            className="wrap"
            style={{
              display: 'flex', justifyContent: 'space-between',
              alignItems: 'center', gap: 16, flexWrap: 'wrap',
            }}
          >
            <span style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
              <Ghost size={20} animate={false} />
              <span className="mono" style={{ fontSize: 12, color: 'var(--ink-faint)' }}>
                MIT licensed
              </span>
            </span>
            <a href={REPO} className="mono" style={{ fontSize: 12, color: 'var(--ink-faint)' }}>
              github.com/pra2107tham/boo
            </a>
          </div>
        </footer>
      </div>
    </>
  );
}

function AppleMark() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M11.1 8.5c0-1.5 1.2-2.2 1.3-2.3-.7-1-1.8-1.2-2.2-1.2-.9-.1-1.8.6-2.3.6s-1.2-.5-2-.5c-1 0-2 .6-2.5 1.5-1.1 1.9-.3 4.6.8 6.1.5.7 1.1 1.6 1.9 1.5.8 0 1-.5 2-.5s1.2.5 2 .5c.8 0 1.4-.7 1.9-1.5.6-.9.8-1.7.8-1.8 0 0-1.6-.6-1.7-2.4zM9.7 3.9c.4-.5.7-1.2.6-1.9-.6 0-1.4.4-1.8.9-.4.5-.7 1.2-.6 1.9.7.1 1.4-.4 1.8-.9z" />
    </svg>
  );
}

/** The actual panel, rebuilt in HTML so the site shows the real thing. */
function PanelShot() {
  const stats = [
    ['CPU', 18, 'var(--green)'],
    ['MEMORY', 54, 'var(--amber)'],
    ['BATTERY', 82, 'var(--green)'],
  ];
  return (
    <div
      style={{
        width: 306, borderRadius: 24, overflow: 'hidden', position: 'relative',
        border: '1px solid rgba(255,255,255,0.12)',
        boxShadow: '0 40px 90px rgba(0,0,0,0.6)',
      }}
    >
      <div style={{ position: 'absolute', inset: 0, filter: 'blur(40px)', opacity: 0.9 }}>
        <div style={{ position: 'absolute', width: 220, height: 220, left: -55, top: -60, borderRadius: '50%', background: '#2f8f6a' }} />
        <div style={{ position: 'absolute', width: 180, height: 180, right: -55, top: 10, borderRadius: '50%', background: '#1f6f7a' }} />
        <div style={{ position: 'absolute', width: 200, height: 200, left: 50, bottom: -100, borderRadius: '50%', background: '#14493f' }} />
      </div>
      <div style={{ position: 'relative', background: 'rgba(10,11,13,0.6)', backdropFilter: 'blur(30px)' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '30px 24px 22px' }}>
          <Ghost size={84} mood="calm" />
          <div className="display" style={{ fontSize: 29, marginTop: 12 }}>All good</div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-dim)', marginTop: 3 }}>
            barely doing anything
          </div>
        </div>
        <div style={{ display: 'flex', padding: '0 24px 18px' }}>
          {stats.map(([label, value, colour], i) => (
            <div key={label} style={{ flex: 1, borderLeft: i ? '1px solid rgba(255,255,255,0.08)' : 'none', paddingLeft: i ? 15 : 0, marginLeft: i ? 15 : 0 }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 1 }}>
                <span className="mono" style={{ fontSize: 21 }}>{value}</span>
                <span style={{ fontSize: 11, color: 'var(--ink-faint)' }}>%</span>
              </div>
              <div style={{ fontSize: 9, fontWeight: 600, letterSpacing: '0.11em', color: 'var(--ink-faint)', marginTop: 2 }}>
                {label}
              </div>
              <div style={{ height: 2, borderRadius: 1, background: 'rgba(255,255,255,0.13)', marginTop: 6 }}>
                <div style={{ width: `${value}%`, height: '100%', borderRadius: 1, background: colour }} />
              </div>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '13px 24px', borderTop: '1px solid rgba(255,255,255,0.07)' }}>
          <span className="mono" style={{ fontSize: 11, color: 'var(--ink-dim)' }}>
            MacBook Air Speakers
          </span>
          <span className="mono" style={{ fontSize: 10.5, color: 'var(--ink-faint)' }}>quiet</span>
        </div>
      </div>
    </div>
  );
}
