# local-docker-cloudflared-migration.md — VPS+Kamal → ローカルPC Docker + cloudflared 運用への移行

このドキュメントは運用基盤の移行実行計画であり、作業ログ兼チェックリストとして
扱う。実装が進むごとにチェックボックスを更新すること。

## 背景・目的

現在このアプリは VPS (162.43.77.16 / vps-rails.ruu-dev.com) に GitHub Actions +
Kamal で自動デプロイする構成になっている。今後は VPS を使わず、このPC上で
Docker コンテナとして本番相当のアプリを常時起動し、Cloudflare Tunnel
(cloudflared) 経由で外部公開する運用に切り替える。

これに伴い:
- Kamal / GitHub Actions によるリモートデプロイの仕組みは不要になるため撤去する
  (CI の test/lint/security scan である `ci.yml` は継続、`deploy.yml` のみ廃止)。
- 本番DBは新規作成せず、`storage/development.sqlite3` をそのまま本番用ボリュームに
  コピーして初期データとする。ユーザー情報の最終的な調整は本番環境(このPC上の
  コンテナ)で直接行う。
- 公開ホスト名は `ruu2023.com`(または配下のサブドメイン)を新規に使う。
  Google OAuth の承認済みリダイレクトURIをこれに合わせて変更する必要がある
  (コールバックパスは `config/routes.rb:6` の
  `get "auth/google_oauth2/callback" => "sessions#create"` より
  `https://ruu2023.com/auth/google_oauth2/callback`)。
- Active Storage の添付ファイルは開発環境に存在しないため移行対象外(確認済み)。

---

## 1. Kamal / リモートデプロイ関連の削除

- [ ] `config/deploy.yml` を削除
- [ ] `.kamal/` ディレクトリ(`secrets`, `hooks/`)を削除
- [ ] `bin/kamal` を削除
- [ ] `Gemfile` から `gem "kamal", require: false` の行を削除し、
      `bundle install` で `Gemfile.lock` を更新(kamal エントリが消えることを確認)
- [ ] `.github/workflows/deploy.yml` を削除(`ci.yml` はそのまま残す)
- [ ] `.dockerignore` の「Ignore Kamal files」ブロック
      (`/config/deploy*.yml`, `/.kamal`)を削除(対象ファイルがなくなるため不要)
- [ ] `README.md` の Kamal デプロイ手順(`docker login` → `kamal deploy` の記載)を
      削除し、本ドキュメント §2〜4 のローカル Docker 起動手順に置き換える

## 2. ローカル Docker 本番運用の構成

- [ ] 既存の `Dockerfile` は Kamal 非依存で `docker build` / `docker run` 単体でも
      動く設計のため、Dockerfile 自体の変更は不要(確認のみ)。
- [ ] ローカルでの起動・自動再起動・ボリューム管理のため `docker-compose.yml`
      を新規作成する:
  - `build: .`
  - `restart: unless-stopped`(PC再起動後も自動起動)
  - `ports: "127.0.0.1:<PORT>:80"`
    → cloudflared だけが外部からの唯一の入口になるようにし、LAN/インターネット
    に直接ポートを晒さない
  - `environment` に `RAILS_MASTER_KEY`, `GOOGLE_OAUTH_CLIENT_ID`,
    `GOOGLE_OAUTH_CLIENT_SECRET`, `SOLID_QUEUE_IN_PUMA=true` を
    `.env`(gitignore 対象、コミットしない)から注入
  - `volumes` で名前付きボリュームを `/rails/storage` にマウント
    (sqlite3 の各DBファイルを永続化。旧 `config/deploy.yml` の
    `vps_rails_storage:/rails/storage` と同じ考え方)
- [ ] `config/environments/production.rb` に `config.assume_ssl = true` を追加する。
      cloudflared は Cloudflare エッジでTLS終端し、オリジン(このPCのコンテナ)へは
      平文HTTPで転送する。`assume_ssl` がないと Rails が生成するURL(OmniAuthの
      コールバックURLなど)が `http://` になり、Google に登録した `https://` の
      リダイレクトURIと一致せず認証が失敗するため。`force_ssl` は有効化しない
      (TLS終端は Cloudflare 側の責務であり、コンテナ自身がリダイレクトやHSTSを
      行う必要はない)。
- [ ] `config.hosts` は現状コメントアウトのまま(未設定)で問題ないため変更不要
      (確認のみ)。

## 3. cloudflared 設定(リポジトリ外、このPC上のOS操作)

リポジトリのコード変更ではなく手順として実施:

- [ ] `brew install cloudflared`
- [ ] `cloudflared tunnel login`(Cloudflareアカウント認証、対象ゾーンとして
      `ruu2023.com` を選択)
- [ ] `cloudflared tunnel create vps-rails`
- [ ] `cloudflared tunnel route dns vps-rails ruu2023.com`
      (サブドメイン運用にする場合は `app.ruu2023.com` 等に読み替え)
- [ ] `~/.cloudflared/config.yml` に ingress ルールを設定:
  ```yaml
  tunnel: vps-rails
  credentials-file: /Users/<user>/.cloudflared/<tunnel-id>.json
  ingress:
    - hostname: ruu2023.com
      service: http://localhost:<PORT>
    - service: http_status:404
  ```
- [ ] `cloudflared service install` で launchd 常駐サービス化
      (PC起動時に自動起動)
- [ ] Google Cloud Console の OAuth 2.0 クライアント設定で「承認済みの
      リダイレクト URI」に `https://ruu2023.com/auth/google_oauth2/callback` を追加
      (旧 `vps-rails.ruu-dev.com` のURIは、切り戻しの予定がなければ削除)

## 4. development.sqlite3 → 本番データの移行

- [ ] 移行前に開発DBのWALをチェックポイントして一貫性を確保:
  ```
  sqlite3 storage/development.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"
  ```
- [ ] `storage/development.sqlite3` を本番用ボリューム内に
      `production.sqlite3`(`config/database.yml` の
      `production.primary.database` と同名)としてコピーする
- [ ] `docker compose up` を初回起動すると `bin/docker-entrypoint` が
      `db:prepare` を実行し、`production_cache.sqlite3` /
      `production_queue.sqlite3` / `production_cable.sqlite3` が新規作成される
      (development では単一DB構成で solid_cache/queue/cable のテーブルを
      使っていないため、これらは移行不要で新規作成のままでよいと確認済み)
- [ ] `db:prepare` によりマイグレーションも適用されるため、開発側で未適用の
      マイグレーションがあれば本番側でも揃うことを確認
- [ ] 起動後、`docker compose exec web bin/rails console` で本番コンテナに入り、
      ユーザーデータの最終調整(不要なテストユーザーの削除など)を直接行う

## 5. 動作確認

- [ ] `docker compose up` → `http://localhost:<PORT>` に直接アクセスしてアプリが
      起動することを確認
- [ ] cloudflared 経由で `https://ruu2023.com` にアクセスし、Google OAuthログインが
      成功すること(コールバックURLの https/httpミスマッチが起きないこと)を確認
- [ ] kaikei・reservation それぞれの主要導線(取引一覧・予定作成など)を一通り確認
- [ ] Turbo Streams / Solid Cable によるリアルタイム更新が cloudflared トンネル
      越しでも機能することを確認(WebSocketアップグレードが通るか)
- [ ] PCの再起動をシミュレートしても `docker-compose.yml` の `restart:
      unless-stopped` と `cloudflared service install` により自動的に
      サービスが復帰することを確認
