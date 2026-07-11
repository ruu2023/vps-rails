class Kaikei::PaymentMethod < ApplicationRecord
  self.table_name = "kaikei_payment_methods"
  self.inheritance_column = nil

  TYPES = %w[income expense].freeze

  belongs_to :user
  has_many :transactions, class_name: "Kaikei::Transaction", foreign_key: :payment_method_id, inverse_of: :payment_method

  validates :name, presence: true
  validates :type, inclusion: { in: TYPES }
end
