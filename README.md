# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

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
