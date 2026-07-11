require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VpsRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # kaikei の設定画面モーダル(科目編集/削除)は JS で <form> の action を
    # 動的に書き換えるため、Rails 8 デフォルトの per-form CSRF トークン
    # (action/method ごとにスコープされる)だと検証に失敗する。個人利用の
    # 非公開アプリのため、セッションベースの CSRF 保護は維持したまま
    # per-form スコープのみ無効化する。
    config.action_controller.per_form_csrf_tokens = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
