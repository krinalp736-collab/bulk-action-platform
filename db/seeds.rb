# Loads the demo contact dataset (db/seeds/contacts.csv, ~2,000 rows across
# two demo accounts, with a handful of intentional duplicate emails to
# exercise the de-duplication feature). Streams the file with CSV.foreach and
# writes in batches via insert_all — the same "never load the whole set into
# memory" discipline the bulk-action pipeline itself uses, just applied here
# at seed time too.
#
# Idempotent: no-ops if contacts already exist so `rails db:seed` is safe to
# re-run. Run `Contact.delete_all` first if you want a fresh reload.

require "csv"

if Contact.exists?
  puts "Contacts already present (#{Contact.count}) — skipping seed. Run Contact.delete_all first to reload."
else
  csv_path = Rails.root.join("db/seeds/contacts.csv")
  batch = []
  batch_size = 500
  total = 0
  now = Time.current

  CSV.foreach(csv_path, headers: true) do |row|
    batch << {
      account_id: row["account_id"],
      name: row["name"],
      email: row["email"],
      age: row["age"],
      status: row["status"],
      created_at: now,
      updated_at: now
    }

    if batch.size == batch_size
      Contact.insert_all(batch)
      total += batch.size
      batch = []
    end
  end

  unless batch.empty?
    Contact.insert_all(batch)
    total += batch.size
  end

  puts "Seeded #{total} contacts from #{csv_path}."
end
