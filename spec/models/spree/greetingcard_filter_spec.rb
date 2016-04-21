require 'spec_helper'
require 'spree/core/greetingcard_filters'

describe 'greetingcard filters', :type => :model do
  # Regression test for #1709
  context 'finds greetingcards filtered by brand' do
    let(:greetingcard) { create(:greetingcard) }
    before do
      property = Spree::Property.create!(:name => "brand", :presentation => "brand")
      greetingcard.set_property("brand", "Nike")
    end

    it "does not attempt to call value method on Arel::Table" do
      expect { Spree::Core::GreetingcardFilters.brand_filter }.not_to raise_error
    end

    it "can find greetingcards in the 'Nike' brand" do
      expect(Spree::Greetingcard.brand_any("Nike")).to include(greetingcard)
    end
    it "sorts greetingcards without brand specified" do
      greetingcard.set_property("brand", "Nike")
      create(:greetingcard).set_property("brand", nil)
      expect { Spree::Core::GreetingcardFilters.brand_filter[:labels] }.not_to raise_error
    end
  end
end
