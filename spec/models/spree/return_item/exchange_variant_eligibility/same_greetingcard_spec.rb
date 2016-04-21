require 'spec_helper'

module Spree
  module ReturnItem::ExchangeVariantEligibility
    describe SameGreetingcard, :type => :model do
      describe ".eligible_variants" do

        context "greetingcard has no variants" do
          it "returns the master variant for the same greetingcard" do
            greetingcard = create(:greetingcard)
            greetingcard.master.stock_items.first.update_column(:count_on_hand, 10)

            expect(SameGreetingcard.eligible_variants(greetingcard.master)).to eq [greetingcard.master]
          end
        end

        context "greetingcard has variants" do
          it "returns all variants for the same greetingcard" do
            greetingcard = create(:greetingcard, variants: 3.times.map { create(:variant) })
            greetingcard.variants.map { |v| v.stock_items.first.update_column(:count_on_hand, 10) }

            expect(SameGreetingcard.eligible_variants(greetingcard.variants.first).sort).to eq greetingcard.variants.sort
          end
        end

        it "does not return variants for another greetingcard" do
          variant = create(:variant)
          other_greetingcard_variant = create(:variant)
          expect(SameGreetingcard.eligible_variants(variant)).not_to include other_greetingcard_variant
        end

        it "only returns variants that are on hand" do
          greetingcard = create(:greetingcard, variants: 2.times.map { create(:variant) })
          in_stock_variant = greetingcard.variants.first

          in_stock_variant.stock_items.first.update_column(:count_on_hand, 10)
          expect(SameGreetingcard.eligible_variants(in_stock_variant)).to eq [in_stock_variant]
        end
      end

    end
  end
end
