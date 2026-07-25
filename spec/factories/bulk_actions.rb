FactoryBot.define do
  factory :bulk_action do
    account_id { "acc_test" }
    entity_type { "Contact" }
    action_type { "bulk_update" }
    status { "queued" }
    filter { { "status" => "lead" } }
    payload { { "status" => "active" } }

    trait :bulk_archive do
      action_type { "bulk_archive" }
      payload { {} }
    end

    trait :targeting_ids do
      filter { {} }
      contact_ids { [] }
    end

    trait :scheduled do
      status { "scheduled" }
      scheduled_at { 1.hour.from_now }
    end

    trait :processing do
      status { "processing" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
