---
description: テスト実行速度を改善するためのリファクタリングパターンとベストプラクティス集
---

# テスト最適化パターン集

テスト実行速度を改善するためのリファクタリングパターンとベストプラクティスをまとめたドキュメントです。

## パターン一覧

| パターン | 効果 | 難易度 | リスク |
|---------|------|--------|--------|
| 1. データベーストランザクション | ★★★★★ | 低 | 低 |
| 2. ファイルI/Oのモック化 | ★★★★★ | 低 | 低 |
| 3. 外部APIのモック化 | ★★★★★ | 中 | 低 |
| 4. beforeEach → beforeAll | ★★★☆☆ | 低 | 中 |
| 5. 非同期待機の最適化 | ★★★☆☆ | 中 | 低 |
| 6. テストデータファクトリー | ★★☆☆☆ | 中 | 低 |
| 7. テストの粒度見直し | ★★★☆☆ | 高 | 中 |
| 8. 並列実行可能な設計 | ★★★☆☆ | 中 | 中 |

---

## パターン1: データベーストランザクション

### 概要

各テストでデータベースのクリア・再投入を行うと、I/O待機時間が累積して遅くなります。トランザクションを使ってロールバックすることで、物理的なDELETE/INSERTを避けて高速化できます。

### 適用条件

- ✅ beforeEach でデータのクリア・再投入を行っている
- ✅ テストごとにクリーンな状態が必要
- ✅ データベースがトランザクションをサポート

### Before（遅い実装）

```javascript
describe('User API', () => {
  beforeEach(async () => {
    // 毎回DELETE・INSERT（遅い）
    await db.query('DELETE FROM users');
    await db.query('DELETE FROM posts');
    await db.query('INSERT INTO users (id, name) VALUES (1, "Test")');
    await db.query('INSERT INTO posts (id, user_id, title) VALUES (1, 1, "Post")');
  });

  afterEach(async () => {
    await db.disconnect();
  });

  it('should get user', async () => {
    const user = await getUserById(1);
    expect(user.name).toBe('Test');
  });

  it('should get posts', async () => {
    const posts = await getPostsByUserId(1);
    expect(posts).toHaveLength(1);
  });
});
```

### After（高速実装）

```javascript
describe('User API', () => {
  let transaction;

  beforeEach(async () => {
    // トランザクション開始
    transaction = await db.transaction();

    // データ準備（トランザクション内）
    await transaction.query('INSERT INTO users (id, name) VALUES (1, "Test")');
    await transaction.query('INSERT INTO posts (id, user_id, title) VALUES (1, 1, "Post")');
  });

  afterEach(async () => {
    // ロールバック（高速）
    await transaction.rollback();
  });

  it('should get user', async () => {
    const user = await getUserById(1);
    expect(user.name).toBe('Test');
  });

  it('should get posts', async () => {
    const posts = await getPostsByUserId(1);
    expect(posts).toHaveLength(1);
  });
});
```

### 期待される効果

- **実行時間**: 80-95%削減
- **具体例**: 15秒 → 2秒

### 注意点

- トランザクション内のデータは他のトランザクションから見えない（分離レベルによる）
- 外部キー制約などは正しく動作する
- ロールバックは物理削除より圧倒的に高速

---

## パターン2: ファイルI/Oのモック化

### 概要

実ファイルへの読み書きはディスクI/Oが発生して遅くなります。メモリ上の仮想ファイルシステムやモックを使うことで高速化できます。

### 適用条件

- ✅ fs.readFile, fs.writeFile などの実ファイル操作を行っている
- ✅ ファイル内容の検証が目的（実際のファイルシステムの動作確認が不要）

### Before（遅い実装）

```javascript
it('should save config', async () => {
  const config = { port: 3000, host: 'localhost' };

  // 実ファイルに書き込み（遅い）
  await fs.writeFile('./config.json', JSON.stringify(config));

  // 実ファイルから読み込み（遅い）
  const saved = await loadConfig('./config.json');

  expect(saved.port).toBe(3000);

  // クリーンアップ
  await fs.unlink('./config.json');
});
```

### After（高速実装）

**方法A: mock-fs を使用**

```javascript
const mockFs = require('mock-fs');

beforeEach(() => {
  // メモリ上に仮想ファイルシステムを作成
  mockFs({
    '/tmp': {},
  });
});

afterEach(() => {
  mockFs.restore();
});

it('should save config', async () => {
  const config = { port: 3000, host: 'localhost' };

  // メモリ上のファイルシステムに書き込み（高速）
  await saveConfig('/tmp/config.json', config);
  const saved = await loadConfig('/tmp/config.json');

  expect(saved.port).toBe(3000);
  // クリーンアップ不要（afterEachで自動）
});
```

**方法B: jest.mock を使用**

```javascript
jest.mock('fs/promises', () => ({
  readFile: jest.fn(),
  writeFile: jest.fn(),
}));

const fs = require('fs/promises');

it('should save config', async () => {
  const config = { port: 3000, host: 'localhost' };

  fs.writeFile.mockResolvedValue(undefined);
  fs.readFile.mockResolvedValue(JSON.stringify(config));

  await saveConfig('./config.json', config);

  expect(fs.writeFile).toHaveBeenCalledWith(
    './config.json',
    JSON.stringify(config)
  );
});
```

### 期待される効果

- **実行時間**: 90-99%削減
- **具体例**: 8秒 → 0.3秒

### 注意点

- ファイルシステムの実際の動作（権限、シンボリックリンク等）は検証できない
- そのような検証が必要な場合はE2Eテストとして分離

---

## パターン3: 外部APIのモック化

### 概要

外部APIへの実際のHTTPリクエストはネットワーク遅延とサーバー処理時間がかかります。モックを使うことで高速化できます。

### 適用条件

- ✅ fetch, axios などで外部APIを呼び出している
- ✅ APIのレスポンス処理ロジックのテストが目的
- ✅ 実際のAPI動作確認は不要

### Before（遅い実装）

```javascript
it('should fetch user data', async () => {
  // 実際のAPI呼び出し（遅い）
  const user = await fetchUser(1);
  expect(user.name).toBe('John');
});
```

### After（高速実装）

**方法A: jest.mock でfetchをモック**

```javascript
global.fetch = jest.fn();

beforeEach(() => {
  fetch.mockClear();
});

it('should fetch user data', async () => {
  // モックのレスポンスを設定（高速）
  fetch.mockResolvedValue({
    ok: true,
    json: async () => ({ id: 1, name: 'John' }),
  });

  const user = await fetchUser(1);

  expect(user.name).toBe('John');
  expect(fetch).toHaveBeenCalledWith('https://api.example.com/users/1');
});
```

**方法B: MSW (Mock Service Worker) を使用**

```javascript
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  rest.get('https://api.example.com/users/:id', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json({ id: Number(req.params.id), name: 'John' })
    );
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

it('should fetch user data', async () => {
  const user = await fetchUser(1);
  expect(user.name).toBe('John');
});

it('should handle API errors', async () => {
  server.use(
    rest.get('https://api.example.com/users/:id', (req, res, ctx) => {
      return res(ctx.status(404));
    })
  );

  await expect(fetchUser(999)).rejects.toThrow('User not found');
});
```

### 期待される効果

- **実行時間**: 90-99%削減
- **具体例**: 5秒 → 0.1秒

### 注意点

- 実際のAPIの動作（認証、レート制限等）は検証できない
- API統合テストはE2Eテストとして分離

---

## パターン4: beforeEach → beforeAll

### 概要

テストデータを変更しない読み取り専用のテストでは、beforeAllでデータを一度だけ準備すれば高速化できます。

### 適用条件

- ✅ 複数のテストで同じデータを使用
- ✅ データを変更しない（読み取り専用）
- ✅ テストの独立性が保たれる

### Before（遅い実装）

```javascript
describe('User queries', () => {
  let testUser;

  beforeEach(async () => {
    // 各テストの前に生成（遅い）
    testUser = await createComplexTestUser();
  });

  afterEach(async () => {
    await deleteUser(testUser.id);
  });

  // 全て読み取り専用のテスト
  it('should get user by id', async () => {
    const user = await getUserById(testUser.id);
    expect(user.name).toBe(testUser.name);
  });

  it('should get user by email', async () => {
    const user = await getUserByEmail(testUser.email);
    expect(user.id).toBe(testUser.id);
  });
});
```

### After（高速実装）

```javascript
describe('User queries', () => {
  let testUser;

  beforeAll(async () => {
    // 一度だけ生成（高速）
    testUser = await createComplexTestUser();
  });

  afterAll(async () => {
    await deleteUser(testUser.id);
  });

  it('should get user by id', async () => {
    const user = await getUserById(testUser.id);
    expect(user.name).toBe(testUser.name);
  });

  it('should get user by email', async () => {
    const user = await getUserByEmail(testUser.email);
    expect(user.id).toBe(testUser.id);
  });
});
```

### 期待される効果

- **実行時間**: テスト数に比例して削減
- **具体例**: 10秒（5テスト × 2秒） → 2.5秒（セットアップ2秒 + テスト0.5秒）

### 注意点

- **重要**: データを変更するテストには適用できない
- テストが独立していることを確認
- 並列実行時は他のテストファイルとの競合に注意

---

## パターン5: 非同期待機の最適化

### 概要

固定時間のsleep/waitは最悪ケースを想定した長い時間になりがちです。条件ベースの待機に変更することで、実際に必要な最小時間だけ待機できます。

### 適用条件

- ✅ setTimeout, sleep などの固定待機時間を使用している
- ✅ 特定の条件が満たされるのを待つ処理

### Before（遅い実装）

```javascript
it('should process async task', async () => {
  startAsyncTask();

  // 5秒待機（実際には1秒で完了していても待つ）
  await new Promise(resolve => setTimeout(resolve, 5000));

  const result = await getTaskResult();
  expect(result.status).toBe('completed');
});
```

### After（高速実装）

```javascript
// ヘルパー関数
async function waitFor(condition, options = {}) {
  const { timeout = 5000, interval = 100 } = options;
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (await condition()) {
      return;
    }
    await new Promise(resolve => setTimeout(resolve, interval));
  }

  throw new Error('Timeout waiting for condition');
}

it('should process async task', async () => {
  startAsyncTask();

  // 条件が満たされるまで待機（最小時間）
  await waitFor(async () => {
    const result = await getTaskResult();
    return result.status === 'completed';
  });

  const result = await getTaskResult();
  expect(result.status).toBe('completed');
});
```

### 期待される効果

- **実行時間**: 50-80%削減
- **具体例**: 5秒 → 1秒（実際の完了時間）

### 注意点

- タイムアウト時間は適切に設定（CI環境では長めに）
- ポーリング間隔を短くしすぎるとCPU負荷が高くなる

---

## パターン6: テストデータファクトリー

### 概要

テストデータの準備で不要な詳細まで定義すると時間がかかります。ファクトリー関数で必要最小限のデータを生成することで高速化できます。

### 適用条件

- ✅ 複雑なデータ構造を毎回定義している
- ✅ テストごとに異なる一部の値だけが必要

### Before（遅い実装）

```javascript
it('should calculate total', () => {
  const order = {
    id: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
    user: {
      id: 1,
      name: 'John',
      email: 'john@example.com',
      address: {
        street: '123 Main St',
        city: 'Tokyo',
        country: 'Japan',
        postalCode: '100-0001',
      },
      preferences: {
        language: 'ja',
        currency: 'JPY',
        timezone: 'Asia/Tokyo',
      },
    },
    items: [
      {
        id: 1,
        name: 'Product A',
        description: 'Description A',
        price: 100,
        quantity: 2,
        taxRate: 0.1,
        category: 'Electronics',
      },
      {
        id: 2,
        name: 'Product B',
        description: 'Description B',
        price: 200,
        quantity: 1,
        taxRate: 0.1,
        category: 'Books',
      },
    ],
    shippingAddress: { /* ... */ },
    billingAddress: { /* ... */ },
    paymentMethod: { /* ... */ },
  };

  expect(calculateTotal(order)).toBe(400);
});
```

### After（高速実装）

```javascript
// ファクトリー関数
function createOrder(overrides = {}) {
  return {
    items: [],
    ...overrides,
  };
}

function createItem(overrides = {}) {
  return {
    price: 0,
    quantity: 1,
    ...overrides,
  };
}

it('should calculate total', () => {
  // 必要最小限のデータのみ
  const order = createOrder({
    items: [
      createItem({ price: 100, quantity: 2 }),
      createItem({ price: 200, quantity: 1 }),
    ],
  });

  expect(calculateTotal(order)).toBe(400);
});
```

### 期待される効果

- **実行時間**: 30-50%削減（可読性向上も）
- **具体例**: 0.5秒 → 0.3秒

### 注意点

- ファクトリー関数は共通ファイルに定義して再利用
- デフォルト値は最も一般的なケースを設定

---

## パターン7: テストの粒度見直し

### 概要

統合テストとして複数の処理を1つのテストで行うと時間がかかります。ユニットテストに分割することで個別の実行時間は短縮できます。

### 適用条件

- ✅ 1つのテストで複数の機能を検証している
- ✅ 各機能は独立してテスト可能

### Before（遅い実装）

```javascript
// 統合テスト（10秒）
it('should complete user registration flow', async () => {
  const user = await registerUser({ email: 'test@example.com' });
  await sendVerificationEmail(user);
  await verifyEmail(user.verificationToken);
  await setupUserProfile(user);
  await sendWelcomeEmail(user);

  const savedUser = await getUser(user.id);
  expect(savedUser.verified).toBe(true);
  expect(savedUser.profile).toBeDefined();
});
```

### After（高速実装）

```javascript
// ユニットテストに分割（各0.5秒）
describe('User Registration', () => {
  it('should register user', async () => {
    const user = await registerUser({ email: 'test@example.com' });
    expect(user.email).toBe('test@example.com');
  });

  it('should send verification email', async () => {
    const mockEmail = jest.fn();
    await sendVerificationEmail({ email: 'test@example.com' }, mockEmail);
    expect(mockEmail).toHaveBeenCalled();
  });

  it('should verify email', async () => {
    const user = { verified: false };
    await verifyEmail(user, 'valid-token');
    expect(user.verified).toBe(true);
  });
});

// E2Eテスト（別ファイル: test/e2e/）
describe('User Registration E2E', () => {
  it('should complete entire flow', async () => {
    // verify-complete フェーズでのみ実行
  });
});
```

### 期待される効果

- **開発時の実行時間**: 大幅削減（ユニットテストのみ実行）
- **CI全体の実行時間**: 変化なし（統合テストも実行）

### 注意点

- 統合テスト・E2Eテストは依然として重要
- テストの階層化（unit, integration, e2e）を明確に

---

## パターン8: 並列実行可能な設計

### 概要

グローバル状態に依存するテストは順次実行する必要がありますが、独立したテストは並列実行できます。

### 適用条件

- ✅ テストがグローバル状態を共有している
- ✅ テストの順序に依存している

### Before（遅い実装）

```javascript
// グローバル状態に依存（並列実行不可）
let currentUser = null;

it('test 1', async () => {
  currentUser = { id: 1 };
  const result = await processUser(currentUser);
  expect(result.id).toBe(1);
});

it('test 2', async () => {
  currentUser = { id: 2 };
  const result = await processUser(currentUser);
  expect(result.id).toBe(2);
});
```

### After（高速実装）

```javascript
// 各テストが独立（並列実行可能）
it('test 1', async () => {
  const user = { id: 1 };
  const result = await processUser(user);
  expect(result.id).toBe(1);
});

it('test 2', async () => {
  const user = { id: 2 };
  const result = await processUser(user);
  expect(result.id).toBe(2);
});
```

### 期待される効果

- **実行時間**: 並列実行数に応じて削減（CPUコア数が上限）
- **具体例**: 10秒（10テスト × 1秒） → 2.5秒（4並列）

### 注意点

- データベーステストでは分離レベルに注意
- CI環境のリソースに応じて並列数を調整

---

## テスト階層化のベストプラクティス

```
test/
├── unit/           # ユニットテスト（高速・常時実行）
│   ├── utils/
│   └── services/
├── integration/    # 統合テスト（中速・リファクタ時実行）
│   ├── api/
│   └── database/
└── e2e/           # E2Eテスト（低速・最終検証時実行）
    └── scenarios/
```

### package.json設定例

```json
{
  "scripts": {
    "test": "jest",
    "test:unit": "jest test/unit",
    "test:integration": "jest test/integration",
    "test:e2e": "jest test/e2e --runInBand",
    "test:watch": "jest --watch test/unit",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e"
  }
}
```

### 開発フローでの使い分け

- **開発中（green/refactor）**: `npm run test:unit -- --findRelatedTests`
- **リファクタ完了後**: `npm run test:integration`
- **最終検証**: `npm run test:all`

---

## まとめ

### 優先度の高いパターン（まず試すべき）

1. **データベーストランザクション** - 効果大・リスク低
2. **ファイルI/Oのモック化** - 効果大・リスク低
3. **外部APIのモック化** - 効果大・リスク低

### 次に検討すべきパターン

4. **beforeEach → beforeAll** - 条件付きで有効
5. **非同期待機の最適化** - 場合により効果大
6. **テストデータファクトリー** - 可読性向上も

### 慎重に検討すべきパターン

7. **テストの粒度見直し** - 設計レベルの変更
8. **並列実行可能な設計** - 既存コードの修正が必要

これらのパターンを組み合わせることで、テストスイート全体の実行時間を50-80%削減できます。
