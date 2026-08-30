'use client';

/** Boo, drawn from the same 64x64 grid the app uses so the site and the
 *  product are literally the same character rather than a lookalike. */
export function Ghost({ size = 96, mood = 'calm', animate = true }) {
  const tint = { calm: '#5bc98a', busy: '#f5a623', hot: '#ef5f4c', audio: '#57c4c0' }[mood] || '#f5a623';

  const hem =
    'M32 5 C45.8 5 55 15 55 28.5 L55 48.2 C55 51.4 52 52.6 50 50.6 ' +
    'C48.1 48.7 45.4 48.7 43.5 50.6 C41.5 52.6 38.6 52.6 36.6 50.6 ' +
    'C34.7 48.7 32 48.7 30.1 50.6 C28.1 52.6 25.2 52.6 23.2 50.6 ' +
    'C21.3 48.7 18.6 48.7 16.7 50.6 C14.7 52.6 12 51.4 12 48.2 ' +
    'L12 28.5 C12 15 18.2 5 32 5 Z';

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      className={animate ? 'ghost-float' : undefined}
      style={{ filter: 'drop-shadow(0 10px 26px rgba(0,0,0,0.45))' }}
      aria-hidden="true"
    >
      <path d={hem} fill="#f7f4ec" />
      <g className={animate ? 'eyes-blink' : undefined} style={{ transformOrigin: '32px 31px' }}>
        <ellipse cx="23" cy="31" rx="4.3" ry="4.6" fill="#0a0b0d" />
        <ellipse cx="41" cy="31" rx="4.3" ry="4.6" fill="#0a0b0d" />
      </g>
      <g fill={tint} className={animate ? 'heart-beat' : undefined}>
        <rect x="28" y="38" width="3" height="3" />
        <rect x="33" y="38" width="3" height="3" />
        <rect x="26" y="41" width="12" height="3" />
        <rect x="28" y="44" width="8" height="3" />
        <rect x="30" y="47" width="4" height="3" />
      </g>
    </svg>
  );
}

/** The blurred colour field. Same three-blob recipe as the app's panel. */
export function Bloom() {
  const blobs = [
    { c: '#2f8f6a', size: 640, x: '-8%', y: '-14%', d: '0s' },
    { c: '#6d4bd6', size: 560, x: '72%', y: '2%', d: '-6s' },
    { c: '#2fa8a0', size: 600, x: '28%', y: '58%', d: '-3s' },
    { c: '#d94a2b', size: 420, x: '84%', y: '66%', d: '-9s' },
  ];
  return (
    <div className="bloom" aria-hidden="true">
      {blobs.map((b, i) => (
        <div
          key={i}
          className="blob"
          style={{
            background: b.c,
            width: b.size,
            height: b.size,
            left: b.x,
            top: b.y,
            animation: `drift 22s ease-in-out ${b.d} infinite`,
          }}
        />
      ))}
    </div>
  );
}
