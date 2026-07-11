# 取引フォームの Stimulus コントローラ確認

出典: `app/javascript/controllers/kaikei/transaction_form_controller.js`、
`app/views/kaikei/transactions/_form.html.erb`。
以下は実際のコードの書き出し(推測なし)。

## 存在するコントローラ

`app/javascript/controllers/kaikei/transaction_form_controller.js` の1つのみ。
identifier は `kaikei--transaction-form`(`app/javascript/controllers/kaikei/` 配下の
`transaction_form_controller.js` に対して stimulus-loading が自動採番する名前で、
コード上でのマッピング根拠は `_form.html.erb` 側の
`data: { controller: "kaikei--transaction-form" }`)。

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "type"]

  syncType() {
    const selected = this.categoryTarget.selectedOptions[0]
    const defaultType = selected?.dataset.defaultType
    if (defaultType) {
      this.typeTarget.value = defaultType
    }
  }
}
```

`app/javascript/controllers` 配下には他に `application.js`、`hello_controller.js`、
`kaikei/chart_controller.js` があるが、取引フォームに関わるのは
`kaikei/transaction_form_controller.js` のみ(`hello_controller` はデフォルトの
スキャフォールド、`chart_controller` はダッシュボードのグラフ用)。

## `_form.html.erb` 側のController/Target/Action紐付け

コントローラの起点(フォーム全体):

```erb
<%= form_with model: transaction, scope: :kaikei_transaction, url: url, local: true,
      data: { controller: "kaikei--transaction-form" }, class: "space-y-6" do |f| %>
```

### 科目セレクト(`category` target)

```erb
<%= f.select :category_id,
      options_for_select(
        @categories.map { |c| [ c.name, c.id, { data: { default_type: c.default_type } } ] },
        transaction.category_id
      ),
      { include_blank: "科目を選択してください" },
      data: { "kaikei--transaction-form-target": "category", action: "change->kaikei--transaction-form#syncType" },
      class: input_class %>
```

- `data-kaikei--transaction-form-target="category"` により `this.categoryTarget` として
  コントローラから参照できる。
- 各`<option>`に `options_for_select` の第三要素 `{ data: { default_type: c.default_type } }`
  経由で `data-default-type` 属性が付与される(値は `Kaikei::Category#default_type`、
  `"income"` または `"expense"`)。
- `data-action="change->kaikei--transaction-form#syncType"` により、この`<select>`の
  `change`イベントで `syncType()` が呼ばれる。

### 収支区分セレクト(`type` target)

```erb
<%= f.select :type, [ [ "収入", "income" ], [ "支出", "expense" ] ],
      {}, data: { "kaikei--transaction-form-target": "type" },
      class: input_class %>
```

- `data-kaikei--transaction-form-target="type"` により `this.typeTarget` として参照できる。
- この要素自体には `data-action` は付いていない(`change`イベントに対するリスナー登録なし)。

### 支払方法セレクト(相手方に相当する唯一のセレクト)

```erb
<%= f.collection_select :payment_method_id, @payment_methods, :id, :name,
      { include_blank: "支払方法を選択してください" }, class: input_class %>
```

- `data-controller`・`data-*-target`・`data-action` のいずれも付与されていない。
  Stimulusコントローラからの参照・イベント連携は無い。

## `dataset.defaultType` の読み取り方(`syncType()`内)

```js
syncType() {
  const selected = this.categoryTarget.selectedOptions[0]
  const defaultType = selected?.dataset.defaultType
  if (defaultType) {
    this.typeTarget.value = defaultType
  }
}
```

- `this.categoryTarget.selectedOptions[0]` で科目セレクトの現在選択中の`<option>`要素を取得。
- その`<option>`要素の `dataset.defaultType`(=ERB側で埋め込んだ `data-default-type` 属性)を読む。
- `include_blank` の空`<option>`が選択されている場合、`data-default-type` 属性が無いため
  `selected?.dataset.defaultType` は `undefined` となり、`if (defaultType)` が false になって
  `typeTarget.value` は書き換えられない(ガード節)。
- 値が取れた場合のみ `this.typeTarget.value = defaultType` で収支区分`<select>`の値を
  直接上書きする。

## 現在のイベント連携のまとめ

- 発火するイベントは科目セレクトの `change` のみ(`change->kaikei--transaction-form#syncType`)。
- `syncType()` は 科目セレクト → 収支区分セレクトの一方向の値同期のみを行う
  (`categoryTarget` を読んで `typeTarget` に書く)。
- 収支区分セレクト側の `change` イベントに対するリスナー・アクションはコード上に存在しない。
- 支払方法セレクトに対する `data-action` / target 登録もコード上に存在せず、
  科目や収支区分の選択に応じて支払方法の選択肢を絞り込むような処理は無い。
- `transaction_form_controller.js` に `connect()`・`disconnect()` などの
  ライフサイクルコールバックは定義されていない(`syncType` メソッドのみ)。
