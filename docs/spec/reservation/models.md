# models.md — モデル仕様 (as-is)

## User

### テーブル: `users`

| カラム | 型 | NOT NULL | デフォルト | DB制約 |
|---|---|---|---|---|
| `id` | integer | ○ | autoincrement | PK |
| `name` | string | — | NULL | — |
| `email` | string | — | NULL | — |
| `image` | string | — | NULL | — |
| `provider` | string | — | NULL | — |
| `uid` | string | — | NULL | — |
| `created_at` | datetime | ○ | — | — |
| `updated_at` | datetime | ○ | — | — |

- **インデックス**: なし（`provider` + `uid` の複合インデックスなし）
- **Devise**: 使用していない。パスワードカラム・Deviseコールバック一切なし

### 関連

```ruby
has_many :events, dependent: :destroy
```

### バリデーション

コード上に明示的なバリデーションなし。

### クラスメソッド

```ruby
def self.from_omniauth(auth)
  where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
    user.name  = auth.info.name
    user.email = auth.info.email
    user.image = auth.info.image
  end
end
```

`first_or_create` で upsert。UID が存在しなければ新規作成、存在すれば既存レコードを返す（既存レコードの name/email/image は更新しない）。

### scope / enum / コールバック

なし

### 認証方式について（vps-rails 移植の注意点）

- Devise なし、OmniAuth のみ
- セッションは `cookies.permanent.signed[:user_id]` で管理
- `provider` カラムに `"google_oauth2"` が入る（開発環境では `"developer"`）
- `uid` は Google の sub ID
- reservation 固有のユーザー属性（`image`, `name`, `email`, `provider`, `uid`）を持つが、これらは vps-rails の共通 User に統合すれば不要になる可能性がある

---

## Event

### テーブル: `events`

| カラム | 型 | NOT NULL | デフォルト | DB制約 |
|---|---|---|---|---|
| `id` | integer | ○ | autoincrement | PK |
| `title` | string | — | NULL | — |
| `start_time` | datetime | — | NULL | — |
| `end_time` | datetime | — | NULL | — |
| `has_end_time` | boolean | ○ | `false` | — |
| `content` | text | — | NULL | — |
| `user_id` | integer | ○ | — | FK → users.id |
| `created_at` | datetime | ○ | — | — |
| `updated_at` | datetime | ○ | — | — |

- **インデックス**: `index_events_on_user_id`
- **外部キー制約**: `add_foreign_key "events", "users"`

### 関連

```ruby
belongs_to :user
```

`dependent:` 指定なし（親 User 側の `dependent: :destroy` で連鎖削除される）。

### バリデーション

```ruby
validates :title, presence: true, length: { maximum: 50 }
validates :start_time, presence: true
validate :start_time_cannot_be_in_the_past, on: :create
validate :end_time_cannot_be_before_start_time
```

#### カスタムバリデーション詳細

**`start_time_cannot_be_in_the_past`** （`on: :create` のみ）

```ruby
if start_time.present? && start_time < Time.zone.now
  errors.add(:start_time, "未来の時間にしてください")
end
```

- 新規作成時のみ過去日時を弾く。更新時はチェックしない。

**`end_time_cannot_be_before_start_time`**

```ruby
if end_time.present? && start_time.blank?
  errors.add(:start_time, "先に選んでね")
end
if end_time.present? && start_time.present? && end_time <= start_time
  errors.add(:end_time, "開始よりあとの時間に！")
end
```

- `end_time` が `start_time` と同じ場合も弾く（`<=`）。

### scope / enum / コールバック

なし

### 日時の扱い

- カラム型: `datetime`（SQLite では ISO8601 文字列として保存）
- タイムゾーン: `Time.zone`（Asia/Tokyo）で扱う
- カレンダー JSON では `.iso8601` で出力
- `end_time` は NULL 許容（`has_end_time: false` のイベントは `end_time` なし）
- `has_end_time` フラグ: UI で終了時刻を表示するかどうかのフラグ。DB には `end_time` が NULL でも保存可能

### 金額・数値

金額カラムなし
