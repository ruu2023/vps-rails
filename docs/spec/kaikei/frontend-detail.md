# フロントエンド詳細仕様（画面別）

出典: `resources/views/**`, `resources/js/**`, `resources/sass/**`、および `docs/spec/screenshot/*.png`（2026-07-11撮影のスクリーンショット）との突合。

既存の [`04_frontend.md`](04_frontend.md) がビルド構成・データフロー・デッドコードの調査結果であるのに対し、本書は **画面ごとの見た目（レイアウト/色/フォント/余白/コンポーネント）と、vanilla JS が担う動的挙動** を中心にまとめる。

## 共通事項（全画面）

### デザイントークン
- フォント: `"Helvetica Neue", Arial, sans-serif`（body全体）。見出し(`h1`)は`1.5rem/600`、`h2`は`1.2rem/600`。
- 基調色:
  - プライマリブルー `#3a7bd5`（ボタン、アクティブ状態、リンク、進捗バー）。グラデーション時は`#3a7bd5 → #3a6073`。
  - 収入グリーン `#28a745` / 支出レッド `#dc3545`（アイコン背景は同色の10〜20%不透明度）。
  - 警告イエロー `#ffc107`（予算警告）。
  - 背景 `#f5f7fa`（body）、カード背景は白`#fff`。
  - 本文色 `#333`、補助テキスト `#666`〜`#888`。
- 角丸: カード/セクション `12px`、フォーム部品・ボタン `8px`、丸アイコン/丸ボタンは`50%`（円形）。
- 影: セクションは`box-shadow: 0 2px 4px rgba(0,0,0,0.05)`、カードは`0 2px 4px rgba(0,0,0,0.1)`、モーダルは背景に`rgba(0,0,0,0.5)`のオーバーレイ。
- 余白: セクション間`margin: 0 1rem 1rem`、セクション内`padding: 1.25rem`、フォーム項目間`margin-bottom: 1.5rem`。
- レスポンシブ: `min-width: 768px`で`.app-container`が`max-width: 480px`に固定される（＝**PCでもモバイル幅のカラム表示**をキープする設計）。実装上はスマホ専用UIを想定しており、デスクトップ最適化はされていない。
- アイコンフォント: Font Awesome 6（CDN読込。`app.blade.php`で6.5.1、`transaction.blade.php`で個別に6.4.0を`@push('styles')`で追加読込しておりバージョン不一致がある）。

### 共通レイアウト構造
- `layouts/app.blade.php`: 全ページのシェル。`<head>`でFigtreeフォント・FontAwesome・`app.scss`/`app.js`を読み込み、`$header`スロット（Breeze標準の白いページヘッダー、Tailwindクラス）と`$slot`（各ページ本体）を描画。
- 実際の見た目上のヘッダーはページごとに二重構造になっている:
  1. Breezeの`$header`スロット（`dashboard.blade.php`は未使用、`transaction`/`settings`は使用: 白背景、`max-w-7xl`中央寄せ、Tailwindの`text-xl font-semibold`）
  2. 各ページ内で独自に組んだ`.header`（`会計管理`固定ヘッダー等、sticky top、box-shadow付き）
  - `dashboard.blade.php`と`analytics.blade.php`は独自`.header`のみ、`transaction.blade.php`と`settings.blade.php`はBreeze `$header`のみを使う、という**画面によってヘッダーの実装方式が異なる**（統一されていない）。
- 下部ナビゲーション `layouts/navigation-bottom.blade.php` が全ページ共通（`.bottom-nav`、`position: fixed; bottom:0`、4項目: ホーム/取引/分析/設定、FontAwesomeアイコン+ラベル、現在ルートに`.active`クラスでブルー着色）。スクリーンショット4枚すべてで下部に固定表示されていることを確認。
- Breeze標準の`layouts/navigation.blade.php`（PC向け上部ナビ、Tailwind製、ハンバーガーメニュー、Alpine.js `x-data`使用）は`app.blade.php`でコメントアウトされておりどのページでも表示されない（**検出事実**: `{{-- @include('layouts.navigation') --}}`）。

---

## 1. ダッシュボード（`pages/dashboard.blade.php`）

対応スクリーンショット: `docs/spec/screenshot/dashboard.png`

### レイアウト構造（上から順）
1. `.header`: `会計管理` (h1) ＋ 右側に通知ベルアイコン・プロフィールアイコンの2つの丸ボタン。sticky。
2. `.balance-card`: 青グラデーションの角丸カード。「今月の収支」見出し＋年月、下段に「今月」/`前月比`を`.balance-divider`（縦線）で区切った2カラム表示。金額はプラス時`.positive`（`#a5f3c9`）、マイナス時`.negative`（`#ffb3b3`）。前月比には`fa-arrow-up`/`fa-arrow-down`アイコン付き。
3. `.quick-actions`: 白背景、4列グリッドのアイコンボタン（収入登録/支出登録/CSV出力/レポート）。アイコンは`#3a7bd5`、ラベルは`#555`。
4. `.chart-section`: 「収支概要」見出し＋Chart.js棒グラフ（`<canvas id="incomeExpenseChart">`、高さ200px、768px以上で250px）。
5. `.transactions-section`: 「最近の取引」＋「すべて表示」リンク（`/analytics`へ）。直近5件を`.transaction-item`のリストで表示（丸アイコン+タイトル+日付+金額）。
6. 予算進捗セクションは**Blade側でまるごとコメントアウト**されており実際には描画されない（`<!-- 予算進捗 -->`以下、`dashboard.blade.php:529-565`）。スクリーンショットにも予算セクションは存在せず、これと一致。
7. 下部ナビゲーション。

### コンポーネントの見た目
- 取引アイテムの丸アイコン: 収入＝薄緑背景+緑アイコン、支出＝薄赤背景+赤アイコン、直径40px。
- 金額文字色は取引種別で緑/赤に自動着色（`.income`/`.expense`）。
- グラフ凡例は上部中央（Chart.jsの`legend.position: 'top'`）、収入=緑、支出=赤の半透明塗り。

### 動的挙動（インラインJS、`dashboard.blade.php`末尾の`<script>`）
- **Chart.js初期化**: サーバーが埋め込んだ`chartData`（過去6ヶ月分の月別収入・支出）を棒グラフとして描画。Y軸ラベルは`¥`+3桁区切り。
- **期間セレクタのイベントリスナーがデッドコード化**: `document.getElementById('chartPeriod').addEventListener('change', ...)`が呼ばれているが、対応する`<select id="chartPeriod">`はHTML側でBladeコメントアウトされている（`{{-- <select id="chartPeriod">...--}}`、486-490行目）ため、**実行時に`getElementById`が`null`を返しJSエラーで後続のプロフィールモーダル初期化コードまで止まる可能性がある**（`null.addEventListener`は例外を投げる）。スクリーンショットで通知/プロフィールボタンが機能するか外見からは判断できないため要実機確認。
- **プロフィールボタン**: `#profileBtn`クリックで`#profileModal`（ヘッダー右下に絶対配置されるドロップダウン、ログアウトのみ）の表示をトグル。外側クリックで閉じる。通知ベルボタン(`#notificationBtn`)にはクリックハンドラが無い（見た目だけの静的アイコン）。
- 金額の`+`/`-`符号、色クラスの決定（`positive`/`negative`, `income`/`expense`）はすべてBlade側の条件分岐で行われ、JSでの再計算はない。

### スクリーンショットとの整合性チェック
- 収支カード「+¥0」「+0.0%」など全項目0円表示 → データ未投入状態と一致（実データがまだ無いテスト環境）。
- グラフはY軸が`¥0〜¥1`のみで棒が見えない → 全月0円のため、Chart.jsが最大値1を仮定してスケーリングしている状態。デザイン上の問題ではなくデータ起因。
- 最近の取引アイテムのアイコンは車(`修繕材料`/`交通費`系)、書類(`セイユー`)、クリップ(`ウェルシア`)など**科目ごとに異なるFontAwesomeアイコン**が使われている。これは設定画面の科目管理で選べる`icon-grid`のアイコン（後述）と対応。
- ヘッダーの通知・プロフィールアイコンはスクリーンショット上も丸ボタンとして視認でき、CSSと一致。

---

## 2. 取引登録フォーム（`pages/transaction.blade.php` + `transaction.js`）

対応スクリーンショット: `docs/spec/screenshot/transaction.png`

### レイアウト構造
- Breeze `$header`スロット: 「取引登録」見出し＋右に`×`アイコンの閉じるボタン（`route('dashboard')`へのリンク）。ページ内独自`.header`は使っていない。
- `.transaction-form-section`（白背景パディング1.5rem、768px以上で最大480px中央寄せ+角丸+影）内に単一フォーム:
  1. 日付（`type="date"`、初期値はJSで本日日付をセット）
  2. 取引元（テキスト入力、プレースホルダー「例：○○銀行、○○クライアント」）
  3. 科目（`<select>`、`<optgroup>`で収入/支出をグルーピング）
  4. 収支区分（ラジオボタン2択のトグルUI、`.transaction-type-toggle`）
  5. 相手方（`<select>`、収支区分に応じて選択肢をJSで出し分け）
  6. 金額（`¥`記号を左に固定表示する`.amount-input-wrapper`、`type="number"`）
  7. メモ（`<textarea>`、最小高さ100px）
  8. 「登録する」送信ボタン（フル幅、青背景、チェックアイコン付き）
- 下部ナビゲーション。

### コンポーネントの見た目
- 入力欄共通: `padding: 0.8rem`, `border: 1px solid #ddd`, `border-radius: 8px`。フォーカス時は青枠+薄い青のグロー(`box-shadow: 0 0 0 2px rgba(58,123,213,0.2)`)。
- 収支区分トグル: 角丸8pxで囲った2分割ボタン。ラジオ自体は非表示(`display:none`)、`<label>`をクリック領域として使うCSSトリックで実装。未選択時は白背景+文字色のみ（収入=緑文字、支出=赤文字）、選択時は該当色の20%不透明背景に着色（`transaction.scss`）。
- 提出ボタン: `#3a7bd5`背景、ホバーで`#2c5ea3`、押下で`#254b82`に段階的に暗くなる。

### 動的挙動（`transaction.js`）
- ページ読込時に日付欄へ`new Date()`をYYYY-MM-DD形式で自動セット。
- 科目`<select>`の`change`イベント: 選択された`<optgroup>`のラベル文字列（"収入"/"支出"）を見て、対応するラジオボタンを自動チェックし、`change`イベントを`dispatchEvent`で発火（→次の相手方フィルタ処理を誘発）。
- 収支区分ラジオの`change`イベント: `.paymentMethodIncome`/`.paymentMethodExpense`クラスの`<option>`の`style.display`を`block`/`none`で切り替え、相手方セレクトの選択肢を絞り込む。
- **`saveTransaction()`・`formatCurrency()`はデッドコード**（呼び出し元が無い）。実際のフォーム送信はJSインターセプトなしの通常HTML POST（`action="/transaction"`）。

### スクリーンショットとの整合性チェック
- 日付欄が`2026/07/11`（今日日付）で初期表示 → JSの自動セット挙動と一致。
- 収支区分トグルは「収入」(緑文字)/「支出」(赤文字)がどちらも白背景の状態で表示されている → 初期状態でどちらのラジオも`checked`でない（`$type`未指定時）ため、選択時の着色スタイルが適用されていない状態と一致。
- 金額欄に`¥`記号がプレフィックスとして固定表示 → `.currency-symbol`のCSSと一致。
- 「相手方を選択してください」がプレースホルダーとして表示され選択肢が出ていない → 収支区分が未選択のため`showPaymentIncome`/`showPaymentExpense`が未発火で、相手方の`<option>`が初期状態のまま（Blade側で`$type !== 'income'`/`'expense'`双方に`display:none`が付き得る、`$type`が空文字のケース）と整合。

---

## 3. 分析画面（`pages/analytics.blade.php` + `analytics.js`）

対応スクリーンショット: `docs/spec/screenshot/analytics.png`

### レイアウト構造
- `.header`: 「取引分析」(h1)のみ。フィルターボタンはBladeでコメントアウト済み(`{{-- <button id="filterBtn">...--}}`)、スクリーンショットにも表示なしで一致。
- `.period-selector`: 開始日〜終了日の`<input type="date">`2つ＋「適用」ボタン（インラインstyleで直接装飾、`.scss`のクラスは使わずBlade内`style=""`属性で色指定）。GETフォームでページ全体をリロードして期間を反映（JS不使用、サーバーサイド処理）。
- `.summary-section`: 3列グリッドの`.summary-card`×3（収入=緑丸アイコン`fa-arrow-down`、支出=赤丸アイコン`fa-arrow-up`、収支=青丸アイコン`fa-coins`）。**アイコンの向きが直感と逆**（収入なのに下向き矢印、支出なのに上向き矢印）である点に注意（デザイン上の見た目としての事実であり、意味的な誤りである可能性がある）。
- `.chart-section`: Chart.js（`<canvas id="monthlyChart">`、高さ220px/768px以上で300px）＋`.chart-tabs`（「月次推移」/「科目別集計」の2タブ、アクティブは青背景+白文字の丸ボタン）。
- `.transactions-section`: 「取引明細」見出し＋収支/科目のフィルタ`<select>`（`onchange="this.form.submit()"`でGET送信、JSインライン記述）。取引一覧、ページネーション（Laravel標準の`links()`）。
- 3つのモーダル（`editTransactionModal`編集/`deleteTransactionModal`削除確認/`filterModal`絞り込み、さらに`deleteConfirmModal`という別の削除確認モーダルも存在＝**同じ目的のモーダルが2つ重複定義**されている）。

### コンポーネントの見た目
- サマリーカード: 白背景、角丸12px、影`0 2px 4px rgba(0,0,0,0.1)`（他セクションより濃いめ）。左に丸アイコン+右にラベル/金額の横並び。
- チャートタブ: 非アクティブは透明背景+グレー文字、アクティブは`#3a7bd5`背景+白文字、`border-radius: 20px`のピル型。
- 取引リスト項目はホバー時に右端から`.transaction-actions`（編集/削除の小型丸ボタン）がフェードイン（`opacity 0→1`、白グラデーションでフェード演出）。ただしこのマークアップ自体は`analytics.blade.php`内に見当たらず、CSSのみ定義されデータバインドされていない可能性がある（**要確認**: `.transaction-actions`を生成するBlade/JSコードが本調査では未特定）。
- モーダル: 中央寄せ`max-width:500px`、開閉時に`translateY(20px)→0`+フェードインの`modal-in`アニメーション0.3s。

### 動的挙動（`analytics.js`）
- **Chart.js初期化**: サーバー埋め込みの`data-monthly`/`data-category`（`<div id="analytics">`のdata属性、JSON文字列）を`JSON.parse`して`chartData.bar`/`chartData.pie`を構築。
- **チャートタブ切替**: `.chart-tab`クリックで`monthlyChart.config.type`を`bar`⇄`pie`に切替え、データセットとY軸オプション/凡例位置(top⇄bottom)も同時に差し替えて`.update()`。円グラフは科目別集計の**先頭5件のみ**（`Object.keys(categoryStats).slice(0,5)`）で、6件目以降は円グラフに反映されない仕様。
- **取引アイテムクリック→編集モーダル**: `.transaction-item[data-id]`をクリックすると、各`data-*`属性から編集フォーム(`#editTransactionModal`)の各フィールドへ値を転記し、収支区分に応じて相手方の選択肢を絞り込み(`showPaymentIncome`/`showPaymentExpense`)、フォームの`action`を`/transaction/{id}`に書き換えてモーダルを開く。**同じ`.transaction-item`クリックに対して2つの重複したイベントリスナー**（`setupAnalyticsEventListeners()`内の1つ目と、同関数内で再度`querySelectorAll(".transaction-item[data-id]")`にアタッチする2つ目、`openEditModal()`呼び出し）が登録されており、クリック時に転記処理とモーダルオープン処理が二重発火する（`openEditModal`自体はモーダル表示のみで転記はしないため実害は小さいが、無駄なDOM操作が二重に走る）。
- **削除フロー**: `#transactionDelete`（編集モーダル内の削除ボタン）→`deleteTransactionModal`を開く→`#confirmDeleteTransactionBtn`クリックで`handleDelete()`が`transactionDeleteForm`の`submit`にリスナーを追加し`action`を`/transaction/{id}`に変更して送信。ただし**`deleteConfirmModal`（別の削除確認モーダル、`#confirmDeleteBtn`）を開くコードがどこにも存在せず**、このモーダルはUIから到達不能なデッドマークアップの可能性が高い。
- **フィルターリセット**: `#resetFilterBtn`クリックで`#filterForm`を`reset()`するのみ（絞り込みモーダル自体を開くボタンはコメントアウトされているため、この機能自体が事実上到達不能）。
- **`updateChart()`はconsole.logのみで中身未実装**（重複関数として`chart-tab`のクリックリスナー内にも同等のロジックがベタ書きされている＝実質のチャート切替はそちらで行われる）。

### スクリーンショットとの整合性チェック
- 期間フィルタが`2026/07/01〜2026/07/31`（今月初〜今月末）で初期表示 → コントローラ側で当月をデフォルトにしている推定と一致（JS起因ではない）。
- サマリーカード3枚が縦1カラムで表示 → `@media (max-width: 480px) { .summary-cards { grid-template-columns: 1fr; } }`がモバイル幅で適用された結果と一致。
- チャートタブ「月次推移」が青背景でアクティブ表示 → 初期`.chart-tab.active`クラスがBladeで付与されている状態と一致。
- 「指定された期間に取引データがありません」というプレースホルダー文言がリスト部に表示 → `@empty`分岐のBladeテキストと一致（データ0件のため）。
- フィルタボタン（フィルターアイコン）がヘッダーに見当たらない → コメントアウトと一致。

---

## 4. 設定画面（`pages/settings.blade.php` + `_settings_categories.blade.php` + `_settings_payment_methods.blade.php` + `settings.js`）

対応スクリーンショット: `docs/spec/screenshot/settings-export.png` / `settings-category.png` / `settings-payment_method.png`

### レイアウト構造
- Breeze `$header`: 「設定」見出し＋右に`?`のヘルプボタン(`#helpBtn`)。ページ内独自`.header`は使っていない（ダッシュボード/分析とは異なる方式）。
- `.settings-menu-section`: 横スクロール可能なタブメニュー(`.settings-menu`、スクロールバー非表示CSS)。7項目のアイコン+ラベル縦積みボタン: データエクスポート/科目管理/相手方管理/プロフィール/通知設定/外観設定/このアプリについて。アクティブタブは薄青背景+青文字(`rgba(58,123,213,0.1)` / `#3a7bd5`)。
  - **メニューに存在しない`budgets`タブ**: `.settings-tab#budgets-tab`というマークアップ（年/月/科目/金額のフォーム＋予算一覧）は存在するが、対応する`.settings-menu-item[data-tab="budgets"]`ボタンがメニューに1つも無い。したがって**予算管理UIはページ上のどこからもクリックで到達できない**（URLで直接タブをアクティブにする手段も無い）。`settings.js`側には`if (this.dataset.tab === "budgets") loadBudgetData();`という分岐が残っており、かつてはメニュー項目が存在した名残と推測される。
- `.settings-content`内、`.settings-tab`のうち1つだけが`display:block`（他は`display:none`）。アクティブタブはBladeの`$page`変数（`category`/`payment_method`/それ以外→export）で初期決定。
- 3つの実装済みタブ＋4つの「開発中」プレースホルダータブ（プロフィール/通知設定/外観設定はグレーの`fa-*`大アイコン＋「この機能は現在開発中です。」文言、`.settings-placeholder`）＋「このアプリについて」タブ（中央寄せの説明文）。
- 2つのモーダル: 科目編集/追加(`categoryModal`、24種類のFontAwesomeアイコンを6列グリッドで選べる`icon-grid`付き)、科目削除確認(`deleteCategoryModal`)。

### 4-1. データエクスポートタブ（スクリーンショット1枚目と対応）
- `.export-options`内に3つの`.export-section`カード（白背景、角丸8px、影）:
  1. 期間選択: 開始日/終了日の`<input type="date">`を2カラムグリッド(`.date-range`、480px以下では1カラムに変化)。
  2. エクスポート形式: 3つの`.format-option`（CSV/Excel/PDF）。ラジオは非表示、`<label>`をカード状に装飾。選択中は青枠+薄青背景。CSVとPDFは`disabled`属性付きでラベルにも「(現在開発中)」と明記、見た目もクリック不可のグレーアウト調（実際にはCSSでの明示的な無効化スタイルは無く、`disabled`属性のブラウザデフォルト挙動のみ）。
  3. エクスポート項目: 「取引データ」「仕訳帳」「科目設定(開発中・disabled)」の3択、同様のカードUI。
  - 下部にフル幅の「データをエクスポート」青ボタン(`#exportButton`)。
- スクリーンショットでは「Excel形式」カードが青枠で選択状態、「取引データ」カードも青枠で選択状態 → `checked`属性のデフォルト値と一致。CSV/PDF/科目設定カードはグレーアウトして見える（ブラウザのdisabledスタイル）。

### 4-2. 科目管理タブ（スクリーンショット2枚目と対応）
- 見出し「科目管理」＋右上「+ 新規追加」ピル型ボタン(`.action-btn`、青背景+白文字+角丸20px)。
- `.category-groups`: 「収入科目」/「支出科目」の2グループ見出し(`<h3>`、下線区切り)、各`.category-item`カード（丸アイコン+科目名＋右端に編集(鉛筆)/削除(ゴミ箱)の2アイコンボタン)。
- スクリーンショットで確認できる科目アイコンと種別:
  - 収入: 「売上」＝緑の`fa-coins`アイコン（`category-icon.income`＝緑10%背景+緑文字）
  - 支出: 「交通費」(車)、「消耗品費」(クリップ)、「通信費」(電話)、「食費」(領収書)、「外注工賃」(ネクタイ姿の人物)、「飼料代金」「装蹄資材」(いずれも`fa-coins`風アイコン、業種特化のカスタム科目と推測される＝会計管理アプリとしては一般的でない「飼料」「装蹄」という語から、畜産・馬関連事業者向けにカスタマイズされた科目データである可能性が高い)
  - いずれも赤10%背景+赤文字の丸アイコン(`category-icon.expense`)と一致。

### 4-3. 相手方管理タブ（スクリーンショット3枚目と対応）
- 見出し「相手方管理」。
- 「新しい相手方を追加」フォーム: 相手方名テキスト入力＋区分`<select>`(支出/収入)＋フル幅青「+ 追加」ボタン。**このフォームだけ`.form-group`のflexレイアウトが縦積みになっている**（`_settings_payment_methods.blade.php`のインラインstyleではなく`.form-group label { display:block }`のデフォルト挙動により、テキスト入力・セレクト・ボタンが縦に並ぶ。スクリーンショットとも一致）。
- 「収入の受取方法」「支出の支払方法」の2セクション、それぞれ`<h3>`見出し(下線)＋登録済み相手方の一覧。各行は名前の`<input>`+区分`<select>`+「更新」ボタンが横並び（インラインstyle `flex:2/1/...`で直接指定、`.scss`にクラス定義は無い）。
- **削除ボタンはBladeでコメントアウト済み**（`{{-- <form>...<button class="action-btn danger-btn">削除</button>...--}}`）→ 相手方の削除はUIから不可能（登録・更新のみ）。スクリーンショットにも削除ボタンは表示されておらず一致。
- スクリーンショットでは「収入の受取方法」に「登録されている収入の支払方法はありません。」という空状態テキストが表示され、「支出の支払方法」には「現金」1件のみが表示 → `@if (!$incomeMethodsFound)`分岐と実データ（現金のみ登録）に一致。

### 動的挙動（`settings.js`）
- **タブ切替 (`setupSettingsMenu`)**: `.settings-menu-item`クリックで、アクティブなメニュー項目/タブのクラスを付け替え。前述の通り`budgets`タブへの導線メニューは存在しない。
- **エクスポート日付初期化 (`setupExportDates`)**: ページ読込時に当月の1日〜末日をJSで計算して`#exportStartDate`/`#exportEndDate`に自動セット（スクリーンショットの`2026/07/01〜2026/07/31`と一致）。
- **科目の描画 (`renderCategories`→`renderCategoryList`)**: サーバーから渡された`data-category`のJSON（`_settings_categories.blade.php`の`#category-list`要素）を`default_type`ごとに振り分け、`innerHTML`でカードをテンプレート文字列生成して挿入。挿入後に編集/削除ボタンへイベントリスナーを再アタッチ(`attachCategoryActionListeners`)。
- **科目編集/追加モーダル (`openCategoryModal`)**: 編集時はグローバル変数`categoryData`から該当科目を検索してフォームに値を転記し、アイコン選択状態(`.icon-option.selected`)も復元。追加時は空フォーム＋デフォルトアイコン`fa-coins`。
- **アイコン選択**: `.icon-option`（24個の丸ボタン）クリックで選択中アイコン表示(`#selectedIcon`)と隠しフィールド(`#categoryIconValue`)を更新、選択枠(`.selected`)をハイライト。
- **科目フォーム送信**: `FormData`から`categoryId`を取得し、値があれば隠しフィールド`#methodInput`を`PATCH`、無ければ`POST`にセットしてから`action`を`/categories/{id}`（新規時はid空文字で`/categories/`）に書き換えてネイティブ送信（JSでの`fetch`は使わずフォーム送信そのもの）。
- **科目削除**: 削除ボタン→確認モーダル→確定で`categoryDeleteForm`の`action`を`/categories/{id}`にセットして送信。
- **予算タブのデータ読み込み (`loadBudgetData`)**: `fetch('/budgets/data')`でJSON取得し`renderBudgetList`で描画。到達不能なタブだが関数自体は`initSettings()`実行時に無条件で1回呼ばれる（ページ読込時に毎回1回だけ裏で予算データ取得のfetchが飛ぶ、UIには出ない）。
- **予算追加/削除**: `fetch('/budgets', {method:'POST'})`/`fetch('/budgets/{id}', {method:'DELETE'})`はJSONレスポンスを期待（[04_frontend.md](04_frontend.md)記載の通りバックエンドとの不整合の可能性あり、要確認）。
- **エクスポート実行 (`exportData`)**: `axios.post('/data-export', ...)`で取引データ取得→Excel形式ならSheetJSでワークシート生成しダウンロード。詳細は[04_frontend.md](04_frontend.md)参照。
- **ヘルプボタン**: `#helpBtn`クリックで`alert("設定画面のヘルプ機能は現在開発中です。")`。

---

## 画面横断で見つかった実装上の不整合まとめ

| 項目 | 内容 | 影響 |
|---|---|---|
| ヘッダー方式の不統一 | ダッシュボード/分析は独自`.header`のみ、取引/設定はBreeze `$header`のみ使用 | 見た目の一貫性はスクリーンショット上ほぼ揃って見えるが、実装が二重管理でありCSS変更時に片方だけ更新漏れするリスク |
| FontAwesomeバージョン差異 | `app.blade.php`は6.5.1、`transaction.blade.php`が個別に6.4.0を追加読込 | 同一アイコン名でもレンダリング結果が微妙に異なる可能性 |
| ダッシュボードの`chartPeriod`セレクタ | HTMLはコメントアウト済みだがJSの`addEventListener`は残存 | `null.addEventListener`で例外、後続の同一`<script>`内コード（プロフィールモーダル初期化）が実行されない可能性（要実機確認） |
| 分析画面の重複イベントリスナー/重複モーダル | `.transaction-item`クリックに2系統のリスナー、削除確認モーダルが2つ(`deleteTransactionModal`/`deleteConfirmModal`) | 無駄なDOM操作の二重発火、保守時にどちらが正か分かりにくい |
| 分析画面のフィルターUI | フィルターボタン・フィルターモーダルの開閉導線がコメントアウトで到達不能 | `filterModal`・`resetFilterBtn`はデッドUI |
| 設定画面の予算タブ | `budgets-tab`のマークアップとJSロジックは存在するが、メニューに導線ボタンが無い | 予算管理機能はUIから完全に到達不能（[03_business_rules.md](03_business_rules.md)のBudget節とも関連） |
| 相手方削除ボタン | Blade側でコメントアウト | 相手方は追加・更新のみ可能で削除不可 |
| 分析画面サマリーカードのアイコン向き | 収入=下向き矢印、支出=上向き矢印 | 一般的な直感（収入=上向き/流入、支出=下向き/流出）と逆になっている可能性 |

## スクリーンショットとの全体整合性

4画面・6枚のスクリーンショットはすべてCSS実装（色・角丸・余白・グリッド列数・レスポンシブブレークポイント）と視覚的に一致しており、乖離は確認されなかった。確認できた唯一の「実データ起因」の見た目（残高0円、グラフが平坦、取引明細が空、相手方が現金のみ）はテスト/初期状態のデータ量によるものであり、CSSやJSの不具合ではない。
