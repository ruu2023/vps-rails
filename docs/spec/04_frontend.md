# フロントエンド解析結果

出典: `resources/views/**`, `resources/js/**`, `vite.config.js`, `resources/sass/**`

## ビルド構成

- Vite + `laravel-vite-plugin`（`vite.config.js`）。
- `input`に登録されているエントリは以下の4本のみ:
  ```
  resources/sass/app.scss
  resources/sass/analytics.scss
  resources/js/app.js
  resources/js/transaction.js
  resources/js/settings.js
  resources/js/analytics.js
  ```
- **検出事項（事実）**: `resources/js/dashboard.js` は `vite.config.js` の `input` に含まれておらず、かつ `dashboard.blade.php` からも `@vite(...)` で読み込まれていない。したがって **`dashboard.js` はビルド対象外・実行対象外の未使用ファイル**（`formatCurrency`, 通知/プロフィールボタンのクリックハンドラ, グラフ期間セレクタのイベント等はすべて到達不能）。
- `resources/js/app.js` は中身が**全行コメントアウト**されており、実質何も実行しない空ファイル。それでも`vite.config.js`の`input`とレイアウト（`layouts/app.blade.php`, `layouts/guest.blade.php`）の`@vite(['resources/sass/app.scss', 'resources/js/app.js'])`双方から読み込まれている。

## ページ別（Blade + JS）構成

| ページ | Blade | 対応JS（`@vite`で読込） | 主なJSライブラリ |
|---|---|---|---|
| ダッシュボード | `resources/views/pages/dashboard.blade.php` | なし（`dashboard.js`は未読込。ページ内に`<script>`直書きでChart.js初期化とプロフィールモーダル制御を実装） | Chart.js（CDN: `https://cdn.jsdelivr.net/npm/chart.js`） |
| 取引登録フォーム | `resources/views/pages/transaction.blade.php` | `resources/js/transaction.js` | なし |
| 分析（取引一覧・集計） | `resources/views/pages/analytics.blade.php` | `resources/js/analytics.js` | Chart.js（CDN: `https://cdn.jsdelivr.net/npm/chart.js`、`analytics.blade.php:417`） |
| 設定 | `resources/views/pages/settings.blade.php` | `resources/js/settings.js` | axios（`bootstrap.js`経由）、XLSX/SheetJS（CDN: `https://cdn.jsdelivr.net/npm/xlsx/dist/xlsx.full.min.js`、`settings.blade.php:436`） |

すべてのページ共通レイアウトは `resources/views/layouts/app.blade.php`（認証済みユーザー向け）で、`resources/js/app.js`（実質空）と`app.scss`を読み込む。

## ダッシュボード（`pages/dashboard.blade.php`）

- サーバー側（`AppController@dashboard`）で計算済みの以下の値をBladeで表示するのみで、金額計算・集計はフロント側では行わない:
  - 今月の収入・支出・収支（`number_format`で3桁区切り整数表示、符号は`{{ $currentMonthBalance >= 0 ? '+' : '' }}`で手動付与）
  - 前月比変化率（`number_format($balanceChange, 1)` — 小数第1位までの四捨五入表示。これが本アプリで唯一の「端数処理」箇所）
  - 直近5件の取引一覧
  - 過去6ヶ月分の収入・支出棒グラフ（Chart.js、CDN読込）
  - 今月の予算一覧（進捗バー・警告表示）
- 予算の警告表示は`Budget`モデルの`warning_level`アクセサ（`danger`/`warning`/`normal`）に連動したCSSクラスをBlade側で分岐（具体的な分岐箇所の行番号は本調査では未特定、**要確認**）。
- プロフィールボタンのクリックでモーダル表示切替（インラインJS）。通知ボタンは`dashboard.js`内に実装があるが前述の通り未読込のため、ダッシュボード画面上の通知ボタンにクリックハンドラが付与されているかは**要確認**（別途インラインで実装されている可能性あり、本調査では該当箇所を特定していない）。

## 取引登録フォーム（`pages/transaction.blade.php` + `transaction.js`）

- フォーム項目: 日付・取引元（`client_name`自由入力、必須）・科目（`category_id`、`<optgroup>`で収入/支出をグルーピング）・収支区分（ラジオボタン `income`/`expense`）・相手方（`payment_method_id`、収入用/支出用リストをJSで出し分け）・金額（`type="number" min="0"`）・メモ。
- `client_id`を選択するUI要素は存在しない（[03_business_rules.md](03_business_rules.md)のClient節を参照）。
- `transaction.js`のロジック:
  - ページ読込時に日付欄へ本日日付をデフォルト設定。
  - 科目`<select>`の選択変更時、選択された`<optgroup>`のラベル（"収入"/"支出"）を見て、対応するラジオボタン（`#income`/`#expense`）を自動選択し`change`イベントを発火。
  - 収支区分のラジオボタン変更に応じて、相手方`<select>`内の`.paymentMethodIncome`/`.paymentMethodExpense`クラス付き`<option>`の表示/非表示をCSSで切り替え（サーバー側でも初期表示用に`style="display:none"`がBladeでセットされる二重管理）。
  - `saveTransaction()`関数（金額をJPY通貨形式に整形してalert表示、フォームリセット）は**定義されているが呼び出し箇所が無いデッドコード**（フォームの`submit`は通常のHTMLフォーム送信のみで、JSによるインターセプトはされていない。実際の保存はサーバーサイド`POST /transaction`への同期的なフォーム送信で行われる）。

## 分析画面（`pages/analytics.blade.php` + `analytics.js`）

- サーバー側（`AppController@analytics`）でフィルタ（`type`, `category_id`, `start_date`〜`end_date`）・ページネーション（20件/ページ）・期間収支サマリー・科目別集計（`groupBy('category_id','type')`を`category.name`でさらにグループ化）・月別推移データを計算し、Bladeに渡す。
- 金額表示は`number_format($transaction->amount)`（3桁区切り、整数）。丸め処理なし。
- 取引一覧の各行クリックで編集モーダルを開き、`data-*`属性（`data-date`, `data-category-id`, `data-client-name`, `data-amount`, `data-payment-method`, `data-memo`, `data-type`, `data-id`）からフォームへ値を転記して、フォームの`action`を`/transaction/{id}`に書き換えてPATCH送信する仕組み（`analytics.js` L228-255）。
- 円グラフ（`pie`）は`categoryStats`の先頭5科目のみを対象（`Object.keys(categoryStats).slice(0,5)`）。6科目目以降は円グラフに反映されない（**事実**: 件数制限あり、警告や「その他」への集約処理は無い）。
- 予算関連のフォーム送信・削除処理は無く、分析画面では予算機能は扱っていない（予算は設定画面・ダッシュボードのみ）。
- `updateChart()`関数（チャート種別切替）は`console.log`のみで**中身が未実装**。
- `openEditModal()`もモーダル表示のみで、フォームへのデータ転記は行っていない（実際のデータ転記は前述の`.transaction-item`クリックリスナー内で別途実装されている）。

## 設定画面（`pages/settings.blade.php` + `settings.js`）

3タブ構成（`category`, `budgets`, `export`。クエリパラメータ`page`とBlade条件分岐、およびJS側`.settings-menu-item`クリックで切替）。

### 科目タブ
- 科目データはBladeが`data-category`属性にJSON埋め込みし、`settings.js`が`JSON.parse`して`default_type`ごとにグルーピングして描画（`categoryData`はサーバー起源、クライアントでの再取得なし）。
- 追加・編集フォームは`FormData`を使い、既存IDがあれば隠しフィールド`methodInput`を`PATCH`に、無ければ`POST`にセットしてから`action`を`/categories/{id}`（新規時は`id`が空文字のため`/categories/`宛先になる点は**要確認**: 空IDでの`POST /categories/`が正しくルーティングされるか、通常のフォーム送信であれば末尾スラッシュはLaravel側で許容されるかは実機未検証）に変更してネイティブ送信。
- `generateCategoryId()`関数（`inc1`/`exp1`のような擬似ID生成）は定義されているが、どこからも呼び出されていない**デッドコード**。

### 予算タブ
- 予算一覧は`fetch('/budgets/data')`で取得しJSONを描画（[03_business_rules.md](03_business_rules.md)のBudget節を参照。バックエンドはこの経路は正しくJSONを返す）。
- 予算新規作成（`fetch('/budgets', {method:'POST'})`）・削除（`fetch('/budgets/{id}', {method:'DELETE'})`）は**JSONレスポンスを期待しているが、バックエンドはリダイレクトレスポンスを返すため、動作しない可能性が高い**（[03_business_rules.md](03_business_rules.md)のBudget節に詳細記載、要確認扱い）。
- `editBudget()`は未実装（`console.log`のみ）。

### エクスポートタブ
- 期間指定＋出力形式（CSV/Excel/PDF）＋出力項目（取引データ/仕訳帳/科目設定）のラジオボタン。
  - CSV・PDF・「科目設定」出力は`disabled`属性が付与されており、UI上選択不可（「現在開発中」ラベル明記）。
  - 実際に選択・実行可能なのは**Excel形式 × 取引データ or 仕訳帳のみ**。
- `exportData()`（`settings.js` L443-566）の処理フロー:
  1. `axios.post('/data-export', {startDate, endDate})`で`DataExportController@fetchData`から取引データ（JSON配列）を取得。
  2. Excel形式の場合、SheetJS（`XLSX`グローバル、CDN読込: `settings.blade.php:436`）で以下いずれかの表を生成:
     - 「取引データ」: 取引日・科目・相手方(支払方法名)・取引元(`client_name`)・収支区分・金額・メモをそのまま列挙。
     - 「仕訳帳」: 収支区分に応じて借方・貸方を機械的に振り分け（支出なら借方＝科目名／貸方＝支払方法名、収入なら逆）。**借方金額・貸方金額はいずれも同一の`item.amount`を重複して設定しており（`借方金額: item.amount`, `貸方金額: item.amount`、`settings.js` L526-528）、複式簿記としての貸借差額チェックや消費税抜き出し等の会計処理は行われていない**（単純な転記表示のためのラベル振り分けのみ）。
  3. `XLSX.writeFile(...)`でブラウザにダウンロード。
- CSVエクスポート（このJS内の`format === 'csv'`分岐）はUI上`disabled`のため通常到達しないが、コード自体は実装済み（BOM付きUTF-8、`,`区切り、値のエスケープ処理なし＝メモや取引先名にカンマ・改行が含まれる場合CSVが壊れる可能性がある。**要確認**: 実データでの検証は未実施）。
- この`exportData()`のCSV/Excelエクスポートと、`TransactionController@exportCsv`（`GET /transaction/export`、仕訳帳CSV）は**別実装・別経路**であり、コード上重複した2種類のエクスポート機能が存在する。

## 共通コンポーネント

- `resources/views/components/*`: Breeze標準のフォーム部品（`text-input`, `input-label`, `input-error`, `primary-button`等）。業務ロジックは持たない表示用コンポーネント。
- `resources/views/layouts/navigation.blade.php` / `navigation-bottom.blade.php`: ヘッダー・フッター（モバイル用ボトムナビ）。
- 全ページで日本語文言がBladeテンプレートに直書きされており、多言語化はされていない。`__('取引登録')`のような`__()`呼び出しは一部で使われているが（`transaction.blade.php:5`）、リポジトリ内に`lang/`および`resources/lang/`ディレクトリ自体が存在しないため、翻訳キーは未定義（Laravelは翻訳キーが見つからない場合キー文字列自体をそのまま表示するため、実害としては素の日本語文字列がそのまま表示される＝実質的に翻訳機構は使われていないのと同じ）。
