class User < ApplicationRecord
  has_many :kaikei_categories, class_name: "Kaikei::Category", dependent: :destroy
  has_many :kaikei_payment_methods, class_name: "Kaikei::PaymentMethod", dependent: :destroy
  has_many :kaikei_transactions, class_name: "Kaikei::Transaction", dependent: :destroy
  has_many :kaikei_budgets, class_name: "Kaikei::Budget", dependent: :destroy

  validates :email, presence: true
  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def self.from_google_omniauth(auth)
    find_or_create_by(provider: auth.provider, uid: auth.uid) do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.avatar_url = auth.info.image
    end
  end
end
