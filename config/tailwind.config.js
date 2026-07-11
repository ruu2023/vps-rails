const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        // kaikei（会計アプリ）デザイントークン: docs/spec/kaikei/frontend-detail.md #デザイントークン
        'kaikei-primary': '#3a7bd5',
        'kaikei-income': '#28a745',
        'kaikei-expense': '#dc3545',
        'kaikei-warning': '#ffc107',
        'kaikei-bg': '#f5f7fa',
        'kaikei-text': '#333333',
        'kaikei-text-muted': '#666666',
        'kaikei-text-subtle': '#888888',
        // モーダル背景オーバーレイ（box-shadowではなくbackground-colorとして使う）
        'kaikei-overlay': 'rgba(0, 0, 0, 0.5)',
        // 収支カードのグラデーション終端色（#3a7bd5 → #3a6073）
        'kaikei-primary-dark': '#3a6073',
        // 収支カード（青背景）上でのプラス/マイナス文字色。本文用income/expenseより明るい専用色
        'kaikei-balance-positive': '#a5f3c9',
        'kaikei-balance-negative': '#ffb3b3',
      },
      borderRadius: {
        'kaikei-card': '12px',
        'kaikei-control': '8px',
      },
      boxShadow: {
        'kaikei-section': '0 2px 4px rgba(0, 0, 0, 0.05)',
        'kaikei-card': '0 2px 4px rgba(0, 0, 0, 0.1)',
      },
    },
  },
  plugins: [
    // require('@tailwindcss/forms'),
    // require('@tailwindcss/typography'),
    // require('@tailwindcss/container-queries'),
  ]
}
