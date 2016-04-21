module Spree
  module ReturnItem::ExchangeVariantEligibility
    class SameGreetingcard
      def self.eligible_variants(variant)
        Spree::Variant.where(greetingcard_id: variant.greetingcard_id, is_master: variant.is_master?).in_stock
      end
    end
  end
end
