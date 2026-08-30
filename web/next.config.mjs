/** @type {import('next').NextConfig} */
// Pages serves this from /boo, so assets need the prefix or they 404.
const repo = '/boo';
export default {
  output: 'export',
  basePath: repo,
  assetPrefix: repo,
  images: { unoptimized: true },
};
