/** @type {import('next').NextConfig} */
const nextConfig = {
  // Allow the HMR websocket when the dev server is accessed through the
  // nginx proxy at http://app.test (inside the container it runs on
  // localhost:3000, so the browser origin doesn't match without this).
  allowedDevOrigins: ['app.test'],
};

export default nextConfig;
