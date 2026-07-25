class Contact < ApplicationRecord
  enum :status, { lead: "lead", active: "active", inactive: "inactive", archived: "archived" },
       default: "lead", validate: true

  validates :account_id, presence: true
  validates :name, presence: true
  validates :email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
end
