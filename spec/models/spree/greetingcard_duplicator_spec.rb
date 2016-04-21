require 'spec_helper'

module Spree

  describe Spree::GreetingcardDuplicator, :type => :model do

    let(:greetingcard) { create(:greetingcard, properties: [create(:property, name: "MyProperty")])}
    let!(:duplicator) { Spree::GreetingcardDuplicator.new(greetingcard)}

    let(:image) { File.open(File.expand_path('../../../fixtures/thinking-cat.jpg', __FILE__)) }
    let(:params) { {:viewable_id => greetingcard.master.id, :viewable_type => 'Spree::Variant', :attachment => image, :alt => "position 1", :position => 1} }

    before do
      Spree::Image.create(params)
    end

    it "will duplicate the greetingcard" do
      expect{duplicator.duplicate}.to change{Spree::Greetingcard.count}.by(1)
    end

    context 'when image duplication enabled' do

      it "will duplicate the greetingcard images" do
        expect{duplicator.duplicate}.to change{Spree::Image.count}.by(1)
      end

    end

    context 'when image duplication disabled' do

      let!(:duplicator) { Spree::GreetingcardDuplicator.new(greetingcard, false) }

      it "will not duplicate the greetingcard images" do
        expect{duplicator.duplicate}.to change{Spree::Image.count}.by(0)
      end

    end

    context 'image duplication default' do

      context 'when default is set to true' do

        it 'clones images if no flag passed to initializer' do
          expect{duplicator.duplicate}.to change{Spree::Image.count}.by(1)
        end

      end

      context 'when default is set to false' do

        before do
          GreetingcardtDuplicator.clone_images_default = false
        end

        after do
          GreetingcardDuplicator.clone_images_default = true
        end

        it 'does not clone images if no flag passed to initializer' do
          expect{GreetingcardDuplicator.new(greetingcard).duplicate}.to change{Spree::Image.count}.by(0)
        end

      end

    end

    context "greetingcard attributes" do
      let!(:new_greetingcard) {duplicator.duplicate}

      it "will set an unique name" do
        expect(new_greetingcard.name).to eql "COPY OF #{greetingcard.name}"
      end

      it "will set an unique sku" do
        expect(new_greetingcard.sku).to include "COPY OF SKU"
      end

      it "copied the properties" do
        expect(new_greetingcard.greetingcard_properties.count).to be 1
        expect(new_greetingcard.greetingcard_properties.first.property.name).to eql "MyProperty"
      end
    end

    context "with variants" do
      let(:option_type) { create(:option_type, name: "MyOptionType")}
      let(:option_value1) { create(:option_value, name: "OptionValue1", option_type: option_type)}
      let(:option_value2) { create(:option_value, name: "OptionValue2", option_type: option_type)}

      let!(:variant1) { create(:variant, greetingcard: greetingcard, option_values: [option_value1]) }
      let!(:variant2) { create(:variant, greetingcard: greetingcard, option_values: [option_value2]) }

      it  "will duplciate the variants" do
        # will change the count by 3, since there will be a master variant as well
        expect{duplicator.duplicate}.to change{Spree::Variant.count}.by(3)
      end

      it "will not duplicate the option values" do
        expect{duplicator.duplicate}.to change{Spree::OptionValue.count}.by(0)
      end

    end
  end
end
