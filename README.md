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
