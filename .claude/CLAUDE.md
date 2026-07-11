# vps-rails

複数の独立した機能を一つの Rails アプリにパス名前空間で同居させる、
個人開発用のモノリス。不特定多数への公開は想定しない。

## 全体アーキテクチャ

- 機能ごとに URL パスと名前空間を分ける。今回の会計アプリは `/kaikei` 配下。
- ルーティングは名前空間で分離する:

    namespace :kaikei do
      resources :transactions
      # ...
    end

  → URL は `/kaikei/transactions`、コントローラは
    `app/controllers/kaikei/transactions_controller.rb`、
    モデルは `app/models/kaikei/` 配下(`Kaikei::Transaction` など)。
- 各機能は自分の名前空間の中で完結させる。機能をまたぐ共有は極力しない。
  共通で使うものだけ名前空間なしのトップレベルに置く(認証、レイアウト、
  共通 concern など)。
- DB テーブルは名前空間ごとにプレフィックスを付ける
  (例: `kaikei_transactions`)。異なる機能が同じテーブル名を
  取り合う事故を防ぐため。モデルは以下で対応:

    class Kaikei::Transaction < ApplicationRecord
      self.table_name = "kaikei_transactions"
    end

## ディレクトリ規約

- コントローラ: `app/controllers/<機能>/`
- モデル: `app/models/<機能>/`
- ビュー: `app/views/<機能>/`
- Stimulus コントローラ: `app/javascript/controllers/<機能>/`
- 機能固有の concern やサービスも `<機能>/` サブディレクトリに置く。

## レイアウト構成

- `app/views/layouts/application.html.erb` は全機能共通のシェル(html/head/body/yield
  と CSS・JS・Font Awesome の読み込み)だけを持つ。機能固有のヘッダー・ナビ・
  レイアウト枠をここに足さない。
- 各機能のヘッダー・ナビ・レイアウト枠は `app/views/layouts/<機能>.html.erb`
  (名前空間レイアウト)に置き、`app/views/<機能>/shared/` のパーシャルを
  描画する形にする。名前空間レイアウトは application レイアウトを内側から
  包む(`render template: "layouts/application" do ... end`)。
- 機能の base controller で `layout "<機能>"` を指定する。

## 認証

- 認証はアプリ全体で共通、Google OAuth のみに一本化する
  (Rails 8 標準のメール/パスワード認証は使わない)。
- 登録は制限しない(誰でも Google アカウントでログインでき、
  初回ログイン時に自動でユーザーレコードを作成する)。
- 名前空間ごとにアクセス制御が必要になったら、機能側の
  base controller で before_action を掛ける。

## 技術スタック

- Rails 8 + SQLite
- Hotwire (Turbo Streams + Stimulus)。リアルタイム更新は Solid Cable 経由。
  フロントエンドは全面的に Hotwire 化し、素の fetch/axios + JSON API は使わない。
- グラフ描画は Chart.js を importmap で取り込んで使う(CDN の `<script>` は使わない)。
- ジョブは Solid Queue、キャッシュは Solid Cache。Redis は使わない。
- テストは minitest(Rails 標準)。機能追加時は必ずテストを書く。
- タイムゾーンは Asia/Tokyo(JST)固定。
- i18n(config/locales)は使わず、ビューに日本語を直書きする。

## kaikei（会計アプリ）固有ルール

- 個人事業主向けの会計管理アプリ。
- 金額はすべて integer(円単位)で保持する。float・decimal は使わない。
- 消費税計算は対象外。取引金額は税込の整数円としてそのまま記録する。
- 科目(Category)・支払方法(PaymentMethod)はユーザーごとに分離する
  (グローバル共有マスタにはしない)。新規ユーザーは空の状態から開始する
  (デフォルト科目の自動生成はしない)。
- 取引先(Client)は自由テキスト(`client_name`)のみとし、専用マスタは持たない。
- 科目・支払方法は論理削除(`deleted_at`)。取引・予算は物理削除。
  過去の取引に紐づく科目名・相手方名を履歴として保全するため、
  削除後も参照している取引からは名前が引ける必要がある
  (`belongs_to` 側は `-> { unscope(where: :deleted_at) }` で
  default_scope を外して参照する)。
- 取引の `type`(収支区分)は選択した科目の `default_type` と一致することを
  バリデーションで強制する。
- 予算(Budget)は支出科目(`default_type = expense`)のみ設定可能。
  年の範囲はハードコード上限を設けない。使用率(`progress_percentage`)は
  表示時に小数第1位で四捨五入する。
- エクスポート機能(CSV/Excel)はサーバーサイドで生成し、1つの機能に統合する
  (取引一覧からの個別エクスポートと設定画面のエクスポートを分けない)。
- 詳細仕様は docs/spec/ を参照し、実装前に必ず確認する
  (ただしこれは移行元 Laravel 版の仕様書であり、既知のバグ・認可漏れ・
  未完成箇所は踏襲せず修正した上で再実装する)。

## 作業ルール

- 新機能を足すときは、まず名前空間・テーブルプレフィックス・
  ディレクトリを上記規約どおりに切ってから実装する。
- 既存機能のコードには、その機能の名前空間の外から触らない。
