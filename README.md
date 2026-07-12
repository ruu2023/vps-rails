# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

- Ruby version

- System dependencies

- Configuration

- Database creation

- Database initialization

- How to run the test suite

- Services (job queues, cache servers, search engines, etc.)

- Deployment instructions

## 本番運用(ローカルPC Docker + Cloudflare Tunnel)

このアプリはVPSではなく、このPC上のDockerコンテナとして本番相当を常時起動し、
共有インフラの Cloudflare Tunnel(`/Volumes/docker-storage/docker-apps/cloudflare/`)
経由で外部公開する。詳細な移行手順・チェックリストは
`docs/plan/local-docker-cloudflared-migration.md` を参照。

- `.env` に `RAILS_MASTER_KEY`, `GOOGLE_OAUTH_CLIENT_ID`,
  `GOOGLE_OAUTH_CLIENT_SECRET` を設定する(コミットしない)。
- 起動:

```
docker compose up -d --build
```

- ログ確認:

```
docker compose logs -f
```

- 本番コンテナでのコンソール操作(DBマイグレーション・データ調整など):

```
docker compose exec vps_rails bin/rails console
```

- DB マイグレーション(レガシーデータ取り込み)

```
bin/rails kaikei:migrate_legacy_dump
bin/rails reservation:import_legacy_events
```

## 開発プレビュー環境

ソースをコンテナにコピーせず bind mount する専用サービス。編集がリビルド
不要で即座に反映される(Gemfile を変更した場合のみ `--build` が要る)。
DB は本番/ローカル開発用とは別ボリューム(`vps_rails_dev_storage`)に分離
されており、まっさらな状態から始まる。通常の `docker compose up -d`
(本番)には含まれない(`profiles: [dev]`)。

- 起動:

```
docker compose --profile dev up -d --build
```

- 停止:

```
docker compose --profile dev down
```

- ログ確認:

```
docker compose logs -f vps_rails_dev
```

- アクセス先:
    - `http://127.0.0.1:3001`(ローカルから直接)
- Gemfile を変更したときだけ再ビルドが必要:

```
docker compose --profile dev up -d --build vps_rails_dev
```

## 本番ビルド手順

コード変更は自動反映されない(`Dockerfile` はマルチステージのソース
COPY ビルドで、`docker-compose.yml` はストレージ以外を bind mount して
いないため)。変更を本番に反映するには、確認が取れた変更を本番ブランチに
取り込んだうえで再ビルド・再作成する:

`vps_rails` コンテナのみを対象にしたい場合:

```
docker compose up -d --build vps_rails
```

## DB ドキュメント(ER・user_id 洗い替え)

- 全テーブル・カラム・リレーション・外部キーの一覧(ER図つき、恒久ドキュメント):
  `docs/db/er.md`
    - 重要ポイント: `kaikei_categories` / `kaikei_payment_methods` /
      `kaikei_budgets` / `kaikei_transactions` / `reservation_events` の
      **5テーブル全てが `user_id` を直接持つ**(親経由でしか user に
      紐づかないテーブルは存在しない)。「取引の `user_id` だけ変えれば
      科目は自動で追随する」という発想は誤り
- ある user のデータをまるごと別 user に付け替える手順(上記ERをチェック
  リストとして使う恒久ドキュメント): `docs/db/user-id-reassignment.md`
    - 新旧ユーザーを両方実在させたまま5テーブルを UPDATE する(FK制約上
      「先に旧ユーザーを消す」は不可能)、`uid`/`provider` は書き換えない、
      という2点の設計判断とその根拠を含む
- 上記手順書が使うバックアップ取得・ロールバック方式(`.backup` +
  `docker cp`、`docker compose run --rm`、`-wal`/`-shm` の扱い)の実機
  検証記録: `docs/db/backup-rollback-verification.md`
