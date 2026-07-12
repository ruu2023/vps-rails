# backup-rollback-verification.md — バックアップ/ロールバック方式の実機検証記録(恒久)

`docs/db/user-id-reassignment.md` §3/§7 と `ignore/reservation-data-full-replace.md`
§3/§8 が使っているバックアップ取得・ロールバック方式について、このリポジトリの
実際の運用環境(`docker compose` + 名前付きボリューム + SQLite、macOS +
Rancher Desktop)で実機検証した記録。検証は 2026-07-12 に実施。

検証は本番コンテナ・本番データには一切書き込みを行わず、**同じイメージで
起動した使い捨てのサンドボックスコンテナ/ボリューム**(ダミーデータ)を
使って行った。本番コンテナ(`vps_rails`)に対しては読み取り専用の
確認コマンドのみ実行し、ダウンタイムなし・データ変更なしで完了している。

方式やDockerランタイムが変わった場合はこのドキュメントも再検証・更新すること。

---

## 前提: このマシンでのDocker実行環境

```
$ docker context ls
NAME                DESCRIPTION                       DOCKER ENDPOINT
rancher-desktop *   Rancher Desktop moby context       unix:///Users/server/.rd/docker.sock
$ docker info --format '{{.OperatingSystem}}'
Alpine Linux v3.23
```

Docker デーモンは Rancher Desktop が動かす軽量VM(Alpine Linux)の中で
動いている。`docker volume inspect` が返す `Mountpoint` はそのVM内のパスで
あり、**macOS ホストから直接 `ls`/`cp` できない**ことを確認した:

```
$ docker volume inspect vps-rails_vps_rails_storage
...
"Mountpoint": "/var/lib/docker/volumes/vps-rails_vps_rails_storage/_data",
...
$ ls -la /var/lib/docker/volumes/vps-rails_vps_rails_storage/_data
ls: /var/lib/docker/volumes/vps-rails_vps_rails_storage/_data: No such file or directory
```

→ 「`docker volume inspect` で mountpoint を特定してホストから直接 `cp`」
という案はこの環境では**使えない**。ボリューム内容の出し入れは
`docker cp` を使う必要がある。

---

## 検証1: バックアップの保存先(同一ボリューム内 vs ホスト側)

上記のとおりホストから直接ボリュームに触れないため、ボリューム外に
出す唯一の実用的な方法は `docker cp` によるホストへの吸い出し。

- 同一ボリューム内(`storage/*.bak-*`)に置く方式: ボリューム自体が壊れる・
  消える障害(誤って `docker volume rm`、ディスク破損など)に対して無力。
  バックアップとして意味をなさない。
- ホスト側(`~/vps-rails-backups/` 等、リポジトリ外)に `docker cp` で
  吸い出す方式: ボリューム障害から独立して残る。

**結論: ホスト側に `docker cp` で吸い出す方式を採用する。**

---

## 検証2: `cp`(+ 手動WALチェックポイント)vs `.backup`

サンドボックスコンテナ(同一イメージ、ダミーの `production.sqlite3`、
`journal_mode=WAL`)で検証。

### 2-1. `.backup` は手動チェックポイントなしでもWAL内の未反映データを含む

読み取りトランザクションを別接続で保持させて WAL からのチェックポイントを
意図的にブロックした状態(実運用で Puma がコネクションを保持している状況を
模擬)で、`.backup` を実行:

```
$ sqlite3 production.sqlite3 ".backup 'wal_aware_backup.sqlite3'"
$ sqlite3 wal_aware_backup.sqlite3 "SELECT * FROM widgets;"
1|clean-1
2|clean-2
3|trapped-in-wal-only     ← WALにしか無かった行も正しく含まれている
```

手動 `wal_checkpoint` を挟んでいないにもかかわらず、WAL 経由でしか読めない
最新のコミット済みデータまで一貫性を保ったまま取り込めている。

### 2-2. 結論

`.backup` はチェックポイントのタイミングを気にする必要がなく、単純な
`cp`(+事前の `wal_checkpoint`)より安全かつ手順もシンプル。

**結論: `.backup` コマンドを採用する。事前の手動 `wal_checkpoint` ステップは不要。**

手順(採用した方式):
```bash
docker compose exec vps_rails sqlite3 storage/production.sqlite3 \
  ".backup '/tmp/production_backup.sqlite3'"
docker cp vps_rails:/tmp/production_backup.sqlite3 \
  ~/vps-rails-backups/production.sqlite3.bak-$(date +%Y%m%d%H%M%S)
docker compose exec vps_rails rm /tmp/production_backup.sqlite3
```

---

## 検証3: ロールバック時の `docker compose exec` 順序矛盾

### 3-1. 停止中コンテナに `docker compose exec`(`docker exec`)は使えない

```
$ docker stop sandbox_vps_rails
$ docker exec sandbox_vps_rails echo "should fail"
Error response from daemon: container ...  is not running
(exit=1)
```

旧手順書の「`docker compose stop` → `docker compose exec ... cp ...`」は
この時点で必ず失敗する。

### 3-2. `docker cp` は停止中コンテナにも効く(読み書き双方)

```
$ docker cp sandbox_vps_rails:/rails/storage/production.sqlite3 /tmp/stopped_readout.sqlite3
$ sqlite3 /tmp/stopped_readout.sqlite3 "SELECT * FROM widgets;"
1|before-backup-1
2|before-backup-2
$ docker cp /tmp/backup_copy.sqlite3 sandbox_vps_rails:/rails/storage/production.sqlite3.cp_write_test
(exit=0)
$ docker start sandbox_vps_rails
$ docker exec sandbox_vps_rails sqlite3 storage/production.sqlite3.cp_write_test "SELECT * FROM widgets;"
1|before-backup-1
2|before-backup-2
```

停止中のコンテナに対しても `docker cp` は読み書きとも成功し、内容も正しい。

### 3-3. `docker compose run --rm` は entrypoint の副作用なく安全に使える

`bin/docker-entrypoint` は「最後の2引数が `./bin/rails server` のときだけ
`db:prepare` を実行する」ガードになっている(`docker-entrypoint` 実装確認済み)。
そのため任意のコマンドで `run --rm` しても `db:prepare` は走らない。
実プロジェクトの `vps_rails` サービスに対し、稼働中のまま(ダウンタイムなし)
読み取り専用コマンドで確認した:

```
$ docker compose run --rm vps_rails sh -c "echo ephemeral-container-ok; ls storage; whoami"
ephemeral-container-ok
production.sqlite3
production_cable.sqlite3
production_cache.sqlite3
production_queue.sqlite3
production_queue.sqlite3-shm
production_queue.sqlite3-wal
rails
(exit=0)
$ docker compose ps        # 本番コンテナは引き続き Up のまま
NAME        ...  STATUS
vps_rails   ...  Up
```

`-v` でホスト側ディレクトリを追加マウントできることも確認済み
(`docker compose run --rm -v <host>:/backup vps_rails ...`)。

### 3-4. 結論

停止中のコンテナに対する操作は `docker compose exec` ではなく
`docker compose run --rm`(同じボリュームに繋がる使い捨てコンテナ)を使う。

---

## 検証4: ロールバック時のWAL残骸(最重要・実害を確認済み)

### 4-1. 再現手順

サンドボックスで以下を再現:

1. `production.sqlite3` に2行(`before-backup-1`, `before-backup-2`)を作成
2. `.backup` でバックアップを取得(この時点で2行)
3. 読み取りトランザクションを別接続で保持しチェックポイントをブロックした
   状態で追加の書き込みを行い、`-wal`/`-shm` に未チェックポイントの変更を
   残したまま(異常終了を模して)プロセスを `kill -9`
   ```
   -rw-r--r-- 1 rails rails  8192 ... production.sqlite3
   -rw-r--r-- 1 rails rails 32768 ... production.sqlite3-shm
   -rw-r--r-- 1 rails rails  4152 ... production.sqlite3-wal
   ```

### 4-2. 「WALを残したまま本体だけ上書き」した場合(危険な方式)

```
$ cp sandbox_backup_good.sqlite3 production.sqlite3   # -wal/-shmはそのまま残す
$ sqlite3 production.sqlite3 "SELECT * FROM widgets;"
1|before-backup-1
2|before-backup-2
3|after-backup-3-in-wal-only
4|after-backup-3-wal-only        ← バックアップには存在しない行が復活
```

**エラーは一切出ず、サイレントにロールバックしたはずの内容が復活する。**
これはSQLiteのWALが「ページ単位の差分」を保持しており、本体ファイルを
差し替えてもWAL側は自分の情報だけを見て差分を再適用してしまうため。

### 4-3. 「停止 → `-wal`/`-shm` を先に削除 → 本体を上書き」した場合(安全な方式)

```
$ rm -f production.sqlite3-wal production.sqlite3-shm
$ cp sandbox_backup_good.sqlite3 production.sqlite3
$ sqlite3 production.sqlite3 "SELECT * FROM widgets;"
1|before-backup-1
2|before-backup-2
```

意図したとおりバックアップ時点の内容だけになる。

### 4-4. 結論

**書き戻し前に必ず `-wal`/`-shm` を削除してから本体ファイルを上書きする。**
順序を誤ると、エラーなくロールバックが無効化される(旧手順書にはこの
削除ステップが無かった=既知の不具合だった)。

---

## 採用した最終方式(両手順書に反映済み)

**バックアップ(§3)**
```bash
docker compose exec vps_rails sqlite3 storage/production.sqlite3 \
  ".backup '/tmp/production_backup.sqlite3'"
docker cp vps_rails:/tmp/production_backup.sqlite3 \
  ~/vps-rails-backups/production.sqlite3.bak-$(date +%Y%m%d%H%M%S)
docker compose exec vps_rails rm /tmp/production_backup.sqlite3
```

**ロールバック(§7/§8)**
```bash
docker compose stop vps_rails
docker compose run --rm \
  -v ~/vps-rails-backups:/backup \
  vps_rails sh -c "
    rm -f storage/production.sqlite3-wal storage/production.sqlite3-shm &&
    cp /backup/production.sqlite3.bak-<timestamp> storage/production.sqlite3
  "
docker compose start vps_rails
```

反映先: `docs/db/user-id-reassignment.md` §3/§7、
`ignore/reservation-data-full-replace.md` §3/§8。
