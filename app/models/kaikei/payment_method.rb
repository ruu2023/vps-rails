class Kaikei::PaymentMethod < ApplicationRecord
  self.table_name = "kaikei_payment_methods"
  self.inheritance_column = nil

  TYPES = %w[income expense].freeze

  belongs_to :user
  has_many :transactions, class_name: "Kaikei::Transaction", foreign_key: :payment_method_id, inverse_of: :payment_method

  default_scope { where(deleted_at: nil) }

  validates :name, presence: true
  validates :type, inclusion: { in: TYPES }

  def discard
    update(deleted_at: Time.current)
  end

  def discarded?
    deleted_at.present?
  end
end
