// Lint: npm run lint (plain ESLint rules, no plugins; the app has no build step).
const g = (names) => Object.fromEntries(names.map((n) => [n, 'readonly']));
export default [{
  files: ['**/*.js', '**/*.mjs'],
  languageOptions: {
    ecmaVersion: 2023, sourceType: 'module',
    globals: g(['window', 'document', 'navigator', 'localStorage', 'location', 'Notification', 'URL', 'Blob', 'Node', 'TextEncoder',
      'Intl', 'setTimeout', 'setInterval', 'clearTimeout', 'clearInterval', 'structuredClone', 'console', 'self', 'caches', 'fetch',
      'globalThis', 'process', 'Response', 'Headers', 'getComputedStyle']),
  },
  rules: { 'no-unused-vars': ['error', { args: 'none', caughtErrors: 'none' }], 'no-undef': 'error', 'no-unreachable': 'error', 'no-dupe-keys': 'error' },
}];
