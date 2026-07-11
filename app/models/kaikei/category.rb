class Kaikei::Category < ApplicationRecord
  self.table_name = "kaikei_categories"

  TYPES = %w[income expense].freeze
  ICONS = %w[
    fa-coins fa-car fa-paperclip fa-phone fa-receipt fa-user-tie
    fa-house fa-utensils fa-cart-shopping fa-gas-pump fa-plane fa-gift
    fa-briefcase fa-money-bill fa-credit-card fa-piggy-bank fa-hand-holding-dollar fa-building
    fa-screwdriver-wrench fa-book fa-heart-pulse fa-graduation-cap fa-shirt fa-wifi
  ].freeze

  belongs_to :user
  has_many :transactions, class_name: "Kaikei::Transaction", foreign_key: :category_id, inverse_of: :category
  has_many :budgets, class_name: "Kaikei::Budget", foreign_key: :category_id, inverse_of: :category

  default_scope { where(deleted_at: nil) }

  validates :name, presence: true
  validates :default_type, inclusion: { in: TYPES }

  def discard
    update(deleted_at: Time.current)
  end

  def discarded?
    deleted_at.present?
  end
end
