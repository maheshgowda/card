require 'spec_helper'

describe Spree::OptionType, :type => :model do
  context "touching" do
    it "should touch a product" do
      product_option_type = create(:product_option_type)
      option_type = product_option_type.option_type
      product = product_option_type.product
      product.update_column(:updated_at, 1.day.ago)
      option_type.touch
      expect(product.reload.updated_at).to be_within(3.seconds).of(Time.current)
    end
    
    it "should touch a greetingcard" do
      greetingcard_option_type = create(:greetingcard_option_type)
      option_type = greetingcard_option_type.option_type
      greetingcard = greetingcard_option_type.greetingcard
      greetingcard.update_column(:updated_at, 1.day.ago)
      option_type.touch
      expect(greetingcard.reload.updated_at).to be_within(3.seconds).of(Time.current)
    end
  end
end
