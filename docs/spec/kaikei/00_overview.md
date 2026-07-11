# 仕様書 概要

このディレクトリは、リポジトリ内のコード（ルーティング定義、コントローラ、モデル、マイグレーション、Blade ビュー、JavaScript）を直接読んで作成した仕様書です。

**方針**
- 記載内容はすべてコードから直接確認できる事実です。
- コードから断定できない箇所（意図・仕様意図・未実装機能の予定など）は「要確認」と明記しています。
- 実際にアプリケーションを実行して動作確認したものではなく、静的なコード解析による記述です。挙動の断定には「（静的解析による推定。実行確認は未実施）」を付記しています。

**ドキュメント構成**
- [01_routes_and_controllers.md](01_routes_and_controllers.md) — 全ルーティングと対応コントローラ一覧
- [02_db_schema.md](02_db_schema.md) — DBスキーマとリレーション
- [03_business_rules.md](03_business_rules.md) — モデルごとのビジネスルール（バリデーション、金額計算、端数処理）
- [04_frontend.md](04_frontend.md) — フロントエンド（Blade / JavaScript）解析結果

**プロジェクト基本情報**（コードから確認）
- フレームワーク: Laravel（Breeze 認証スキャフォールド使用、`routes/auth.php` の構成より）
- DB接続既定値: `sqlite`（`config/database.php:19`, `.env.example:24`）
- ロケール既定値: `en`（`config/app.php:81`、`APP_LOCALE` 未設定時）。画面文言は日本語がBladeに直書きされている。
- タイムゾーン既定値: `UTC`（`config/app.php:68`、`APP_TIMEZONE` 未設定時）
- 通貨・税金計算: リポジトリ全体を検索した結果、消費税計算・端数処理（round/floor/ceil）を行うロジックは業務ロジック上どこにも存在しません（`ceil` の唯一の使用箇所はログイン試行回数制限のロックアウト時間計算 `app/Http/Requests/Auth/LoginRequest.php:73` のみで、金額とは無関係）。金額は常に整数円（`amount` カラムは `integer`）として扱われています。
