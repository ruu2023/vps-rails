# デフォルトはブラウザセッション終了で切れる Cookie(有効期限指定なし)。
# 個人利用の非公開アプリで頻繁な再ログインが不要なため、1年まで延長する。
Rails.application.config.session_store :cookie_store, key: "_vps_rails_session", expire_after: 1.year
