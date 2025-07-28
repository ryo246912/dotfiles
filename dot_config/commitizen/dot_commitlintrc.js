/* prettier-ignore */
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
      { value: 'chore',    name: 'chore:    その他の変更（ソースやテストの変更を含まない）', emoji: ':hammer:' },
      { value: 'fix',      name: 'fix:      バグ修正', emoji: ':bug:' },
      { value: 'refactor', name: 'refactor: リファクタリング（削除の場合はremoveをscopeに入れる）', emoji: ':recycle:' },
      { value: 'wip',      name: 'wip:      作業途中', emoji: '' },
      { value: 'test',     name: 'test:     テスト', emoji: ':white_check_mark:' },
    ],
    aiQuestionCB: ({ maxSubjectLength, diff, type }) => {
      const isEnglish = process.env.CZ_LANG === 'en'

      if (isEnglish) {
        return `Write an insightful and concise Git commit message in the present tense for the following Git diff code, without any prefixes, and no longer than ${maxSubjectLength} characters.: \`\`\`diff\n${diff}\n\`\`\``
      } else {
        return `以下のGit diff コードに対して、簡潔で洞察に富んだ日本語のGitコミットメッセージを現在形・体言止めで書いてください。プレフィックスは不要で、${maxSubjectLength}文字以内にしてください: \`\`\`diff\n${diff}\n\`\`\``
      }
    },
    aiNumber: 3,
    useEmoji: false,
    skipQuestions: ['breaking','footerPrefix'],
    maxHeaderLength: 72,
    minSubjectLength: 0,
    scopeOverrides: undefined,
  }
}
