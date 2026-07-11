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
- Macの場合 ファイル内にある以下の1行を探して、行ごと削除します。
vim ~/.docker/config.json
```
"credsStore": "osxkeychain"
```

- 環境変数を設定します。
```env
KAMAL_REGISTRY_PASSWORD=
RAILS_MASTER_KEY=
```
- Dockerログインします。
```
docker login
```
- kamal deployを実行します。
```
export $(no-proxy=* xargs < .env) && kamal deploy
```

- DB マイグレーション
```
bin/rails kaikei:migrate_legacy_dump
```
