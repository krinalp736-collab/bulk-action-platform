FactoryBot.define do
  factory :contact do
    account_id { "acc_test" }
    name { "Test Contact" }
    sequence(:email) { |n| "contact#{n}@example.com" }
    age { 30 }
    status { "lead" }
  end
end
