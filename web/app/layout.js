export const metadata = {
  title: 'Boo — a ghost for your menu bar',
  description:
    'A small ghost that lives in your Mac menu bar and quietly minds how your machine is doing. Free and open source.',
  openGraph: {
    title: 'Boo — a ghost for your menu bar',
    description: 'A small ghost that minds how your Mac is doing.',
    type: 'website',
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=JetBrains+Mono:wght@400;500&family=Inter:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
