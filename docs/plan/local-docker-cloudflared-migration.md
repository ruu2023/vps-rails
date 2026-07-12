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
- Cloudflare Tunnel は本アプリ専用に新規構築するのではなく、既に別サービス
  (immich 等)で稼働中の共有 tunnel
  (`/Volumes/docker-storage/docker-apps/cloudflare/`)にこのアプリを相乗りさせる。
  `cloudflare/README.md` の「新しいアプリを追加する手順」に従う(詳細は §3)。

---

## 1. Kamal / リモートデプロイ関連の削除

- [x] `config/deploy.yml` を削除
- [x] `.kamal/` ディレクトリ(`secrets`, `hooks/`)を削除
- [x] `bin/kamal` を削除
- [x] `Gemfile` から `gem "kamal", require: false` の行を削除し、
      `bundle install` で `Gemfile.lock` を更新(kamal エントリが消えることを確認)
- [x] `.github/workflows/deploy.yml` を削除(`ci.yml` はそのまま残す)
- [x] `.dockerignore` の「Ignore Kamal files」ブロック
      (`/config/deploy*.yml`, `/.kamal`)を削除(対象ファイルがなくなるため不要)
- [x] `README.md` の Kamal デプロイ手順(`docker login` → `kamal deploy` の記載)を
      削除し、本ドキュメント §2〜4 のローカル Docker 起動手順に置き換える

## 2. ローカル Docker 本番運用の構成

- [x] 既存の `Dockerfile` は Kamal 非依存で `docker build` / `docker run` 単体でも
      動く設計のため、Dockerfile 自体の変更は不要(確認のみ)。
- [x] ローカルでの起動・自動再起動・ボリューム管理のため `docker-compose.yml`
      を新規作成する(`cloudflare/README.md` の「アプリの docker-compose.yml に
      tunnel-net を追加」の手順に対応させる):
  - `build: .`
  - `container_name: vps_rails`(§3 の ingress ルールで参照するホスト名として使う。
    旧 `config/deploy.yml` の `service: vps_rails` と同名で揃える)
  - `restart: unless-stopped`(PC再起動後も自動起動)
  - 外部公開は cloudflared コンテナが `tunnel-net` 経由で直接
    `http://vps_rails:80` に到達する形になるため、ホストへの `ports:` 公開は
    必須ではない(ローカルデバッグ用に `127.0.0.1:<PORT>:80` を任意で追加してもよい)
  - `networks: [default, tunnel-net]` を追加し、`tunnel-net` は
    `external: true`(`cloudflare/docker-compose.yml` が定義する既存ネットワークに
    参加する)
  - `environment` に `RAILS_MASTER_KEY`, `GOOGLE_OAUTH_CLIENT_ID`,
    `GOOGLE_OAUTH_CLIENT_SECRET`, `SOLID_QUEUE_IN_PUMA=true` を
    `.env`(gitignore 対象、コミットしない)から注入
  - `volumes` で名前付きボリュームを `/rails/storage` にマウント
    (sqlite3 の各DBファイルを永続化。旧 `config/deploy.yml` の
    `vps_rails_storage:/rails/storage` と同じ考え方)
- [x] `config/environments/production.rb` に `config.assume_ssl = true` を追加する。
      cloudflared は Cloudflare エッジでTLS終端し、オリジン(このPCのコンテナ)へは
      平文HTTPで転送する。`assume_ssl` がないと Rails が生成するURL(OmniAuthの
      コールバックURLなど)が `http://` になり、Google に登録した `https://` の
      リダイレクトURIと一致せず認証が失敗するため。`force_ssl` は有効化しない
      (TLS終端は Cloudflare 側の責務であり、コンテナ自身がリダイレクトやHSTSを
      行う必要はない)。
- [x] `config.hosts` は現状コメントアウトのまま(未設定)で問題ないため変更不要
      (確認のみ)。

## 3. cloudflared 設定(このリポジトリ外、`cloudflare/` 側の共有インフラ操作)

cloudflared は本アプリ専用に新規構築しない。既に immich 等で稼働中の共有
tunnel(`/Volumes/docker-storage/docker-apps/cloudflare/`)に相乗りさせる。
手順は `cloudflare/README.md` の「新しいアプリを追加する手順」に準拠する:

- [x] **(手動・要ユーザー作業)** `ruu2023.com` を Cloudflare アカウントに
      ゾーンとして追加する(既存 tunnel は `ruu-dev.com` ゾーン向けに構築済み
      のため、新ドメインを使う場合はこのゾーン追加が別途必要)
- [x] `cloudflare/config.yml` の `ingress` に追記済み(`config.yml.bak-*` として
      変更前のバックアップも保存済み):
  ```yaml
  ingress:
    - hostname: immich.ruu-dev.com
      service: http://immich_server:2283
    - hostname: ruu2023.com
      service: http://vps_rails:80
    - service: http_status:404   # 末尾のこの行は必ず残す
  ```
- [x] このアプリの `docker-compose.yml` を `tunnel-net` に接続した状態で起動済み
- [x] `cloudflare/config.yml` の変更を反映するため cloudflared を再起動済み
      (既存の immich ルートには影響なし。ただし `ruu2023.com` のゾーンが
      Cloudflare 側に存在しないため、この時点では外部からは到達不可)
- [x] **(手動・要ユーザー作業)** ゾーン追加後、Cloudflare ダッシュボード →
      DNS でレコードを追加: Type `CNAME` / Name `ruu2023.com`
      (または該当サブドメイン)/ Target
      `a5682f06-2438-4a86-a7ce-3a5656e40b4c.cfargotunnel.com` /
      Proxy オン(オレンジ雲)
- [x] **(手動・要ユーザー作業)** Google Cloud Console の OAuth 2.0
      クライアント設定で「承認済みのリダイレクト URI」に
      `https://ruu2023.com/auth/google_oauth2/callback` を追加
      (旧 `vps-rails.ruu-dev.com` のURIは、切り戻しの予定がなければ削除)

## 4. development.sqlite3 → 本番データの移行

- [x] 移行前に開発DBのWALをチェックポイントして一貫性を確保
- [x] `storage/development.sqlite3` を本番用ボリューム内に `production.sqlite3`
      としてコピー
- [x] `docker compose up` 初回起動で `production_cache` / `production_queue` /
      `production_cable` が新規作成されることを確認
- [x] コピー後の再起動でマイグレーションエラーが出ないことを確認
- [x] `docker compose exec vps_rails bin/rails runner` でデータ件数を確認
      (User: 1件、Kaikei::Transaction: 31件、Reservation::Event: 42件が
      正しく反映されていることを確認済み)
- [ ] ユーザーデータの最終調整(不要なテストユーザーの削除など)は
      **未実施**。必要になったタイミングで
      `docker compose exec vps_rails bin/rails console` から行う

## 5. 動作確認

- [x] コンテナ起動後、`curl http://127.0.0.1:3000/up` が 200 を返すことを確認
- [x] `/login` にもアクセスできることを確認
- [x] cloudflared 経由で `https://ruu2023.com` にアクセスし、Google OAuth
      ログインが成功することを確認(ユーザー確認済み。コールバックURLの
      https/httpミスマッチなし)
- [x] kaikei・reservation それぞれの主要導線(取引一覧・予定表示など)を
      ブラウザで確認し、データが正しく表示され動作に問題ないことを確認済み
      (ユーザー確認済み)
- [ ] Turbo Streams / Solid Cable によるリアルタイム更新が cloudflared トンネル
      越しでも機能することを確認(WebSocketアップグレードが通るか)— 未確認
- [ ] PCの再起動をシミュレートしても、`docker-compose.yml` の `restart:
      unless-stopped`(このアプリ)と `cloudflare/docker-compose.yml` の
      `restart: always`(cloudflared、既存インフラで設定済み)により
      両コンテナが自動的に復帰することを確認
