FactoryBot.define do
  factory :bulk_action_batch do
    bulk_action
    sequence(:batch_number) { |n| n }
    status { "pending" }
  end
end
