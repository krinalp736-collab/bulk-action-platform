require "rails_helper"

RSpec.describe BulkActions::Registry do
  describe ".resolve" do
    it "resolves a registered entity/action pair to its strategy class" do
      expect(described_class.resolve("Contact", "bulk_update")).to eq(BulkActions::ContactBulkUpdate)
      expect(described_class.resolve("Contact", "bulk_archive")).to eq(BulkActions::ContactBulkArchive)
    end

    it "raises UnknownActionError for an unregistered pair" do
      expect { described_class.resolve("Contact", "bulk_teleport") }
        .to raise_error(described_class::UnknownActionError)
    end
  end

  describe ".registered?" do
    it "is true for a registered pair" do
      expect(described_class.registered?("Contact", "bulk_update")).to be(true)
    end

    it "is false for an unregistered pair" do
      expect(described_class.registered?("Contact", "bulk_teleport")).to be(false)
      expect(described_class.registered?("Company", "bulk_update")).to be(false)
    end
  end
end
