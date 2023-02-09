// commitlint.config.js | .commitlintrc.js
/** @type {import('cz-git').UserConfig} */
module.exports = {
  rules: {
    // @see: https://commitlint.js.org/#/reference-rules
  },
  prompt: {
    messages: {
      type: 'コミットする変更タイプを選択:',
      scope: '変更内容のスコープを記載しますか? (enterでスキップ):',
      customScope: '変更の範囲を示す(例:コンポーネントやファイル名):',
      subject: '変更内容を要約:\n',
      body: '変更内容の詳細 (optional). Use "|" to break new line:\n',
      breaking: '破壊的変更についての記述 (optional). Use "|" to break new line:\n',
      footerPrefixSelect: 'Issueの変更タイプを記載しますか？ (enterでスキップ):',
      customFooterPrefix: 'issue prefixを記述(例.fix, close, resolve):',
      footer: '関連するURLやissue(例.fix #31):\n',
      confirmCommit: '上記のコミットで本当に良いですか？'
    },
    types: [
      { value: 'feat',     name: 'feat:     新機能', emoji: ':sparkles:' },
      { value: 'add',      name: 'add:      追加(機能追加ほどではない)', emoji: '' },
      { value: 'fix',      name: 'fix:      バグ修正', emoji: ':bug:' },
      { value: 'docs',     name: 'docs:     ドキュメントのみの変更', emoji: ':memo:' },
      { value: 'move',     name: 'move:     ファイル名変更・ファイル移動', emoji: '' },
      { value: 'refactor', name: 'refactor: リファクタリングのための変更（機能追加やバグ修正を含まない）', emoji: ':recycle:' },
      { value: 'chore',    name: 'chore:    その他の変更（ソースやテストの変更を含まない）', emoji: ':hammer:' },
      { value: 'revert',   name: 'revert:   リバート', emoji: ':rewind:' },
      { value: 'wip',      name: 'wip:      作業途中', emoji: '' }
      // { value: 'style',    name: 'style:    フォーマットの変更（コードの動作に影響しないスペース、フォーマット、セミコロンなど）', emoji: ':lipstick:' },
      // { value: 'perf',     name: 'perf:     パフォーマンスの改善のための変更', emoji: ':zap:' },
      // { value: 'test',     name: 'test:     不足テストの追加や既存テストの修正', emoji: ':white_check_mark:' },
      // { value: 'build',    name: 'build:    Changes that affect the build system or external dependencies', emoji: ':package:' },
      // { value: 'ci',       name: 'ci:       CI用の設定やスクリプトに関する変更', emoji: ':ferris_wheel:' },
    ],
    useEmoji: false,
    skipQuestions: ['breaking','footerPrefix'],
    maxHeaderLength: 72,
    minSubjectLength: 0,
    scopeOverrides: undefined,
  }
}
