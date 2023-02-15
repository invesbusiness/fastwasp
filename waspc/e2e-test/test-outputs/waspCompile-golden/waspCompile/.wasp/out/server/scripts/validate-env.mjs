import { throwIfNotValidAbsoluteURL } from './universal/validators.mjs';

console.info("🔍 Validating environment variables...");
throwIfNotValidAbsoluteURL(process.env.WASP_WEB_CLIENT_URL, 'Environment variable WASP_WEB_CLIENT_URL is not a valid absolute URL');
