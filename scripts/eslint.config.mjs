// Lint: npm run lint (plain ESLint rules, no plugins) over the Node scripts.
export default [{
  files: ['**/*.mjs'],
  languageOptions: {
    ecmaVersion: 2023, sourceType: 'module',
    globals: { console: 'readonly', process: 'readonly', URL: 'readonly' },
  },
  rules: { 'no-unused-vars': ['error', { args: 'none', caughtErrors: 'none' }], 'no-undef': 'error', 'no-unreachable': 'error', 'no-dupe-keys': 'error' },
}];
