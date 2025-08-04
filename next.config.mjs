/** @type {import('next').NextConfig} */
const nextConfig = {
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  // Handle static assets
  assetPrefix: process.env.NODE_ENV === 'production' ? '' : '',
  webpack: (config, { isServer }) => {
    // Handle missing modules
    config.resolve.fallback = {
      ...config.resolve.fallback,
      "pino-pretty": false,
      "lokijs": false,
      "encoding": false,
    };

    // Handle indexedDB for server-side
    if (isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        "indexeddb": false,
      };
    }

    return config;
  },
}

export default nextConfig
