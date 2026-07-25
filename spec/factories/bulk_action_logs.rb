FactoryBot.define do
  factory :bulk_action_log do
    bulk_action
    entity_type { "Contact" }
    sequence(:entity_id) { |n| n }
    status { "pending" }
  end
end
