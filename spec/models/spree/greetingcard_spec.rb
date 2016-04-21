# coding: UTF-8

require 'spec_helper'

module ThirdParty
  class Extension < Spree::Base
    # nasty hack so we don't have to create a table to back this fake model
    self.table_name = 'spree_greetingcards'
  end
end

describe Spree::Greetingcard, :type => :model do

  describe 'Associations' do
    it 'should have many promotions' do
      is_expected.to have_many(:promotions).
        class_name('Spree::Promotion').through(:promotion_rules)
    end

    it 'should have many possible_promotions' do
      is_expected.to have_many(:possible_promotions).
        class_name('Spree::Promotion').through(:promotion_rules).source(:promotion)
    end
  end

  context 'greetingcard instance' do
    let(:greetingcard) { create(:greetingcard) }
    let(:variant) { create(:variant, :greetingcard => greetingcard) }

    context '#duplicate' do
      before do
        allow(greetingcard).to receive_messages :taxons => [create(:taxon)]
      end

      it 'duplicates greetingcard' do
        clone = greetingcard.duplicate
        expect(clone.name).to eq('COPY OF ' + greetingcard.name)
        expect(clone.master.sku).to eq('COPY OF ' + greetingcard.master.sku)
        expect(clone.taxons).to eq(greetingcard.taxons)
        expect(clone.images.size).to eq(greetingcard.images.size)
      end

      it 'calls #duplicate_extra' do
        expect_any_instance_of(Spree::Greetingcard).to receive(:duplicate_extra)
          .with(greetingcard)
        expect(greetingcard).to_not receive(:duplicate_extra)
        greetingcard.duplicate
      end
    end

    context "master variant" do

      context "when master variant changed" do
        before do
          greetingcard.master.sku = "Something changed"
        end

        it "saves the master" do
          expect(greetingcard.master).to receive(:save!)
          greetingcard.save
        end
      end

      context "when master default price changed" do
        before do
          master = greetingcard.master
          master.default_price.price = 11
          master.save!
          greetingcard.master.default_price.price = 12
        end

        it "saves the master" do
          expect(greetingcard.master).to receive(:save!)
          greetingcard.save
        end

        it "saves the default price" do
          expect(greetingcard.master.default_price).to receive(:save)
          greetingcard.save
        end
      end

      context "when master variant and price haven't changed" do
        it "does not save the master" do
          expect(greetingcard.master).not_to receive(:save!)
          greetingcard.save
        end
      end
    end

    context "greetingcard has no variants" do
      context "#destroy" do
        it "should set deleted_at value" do
          greetingcard.destroy
          expect(greetingcard.deleted_at).not_to be_nil
          expect(greetingcard.master.reload.deleted_at).not_to be_nil
        end
      end
    end

    context "greetingcard has variants" do
      before do
        create(:variant, :greetingcard => greetingcard)
      end

      context "#destroy" do
        it "should set deleted_at value" do
          greetingcard.destroy
          expect(greetingcard.deleted_at).not_to be_nil
          expect(greetingcard.variants_including_master.all? { |v| !v.deleted_at.nil? }).to be true
        end
      end
    end

    context "#price" do
      # Regression test for #1173
      it 'strips non-price characters' do
        greetingcard.price = "$10"
        expect(greetingcard.price).to eq(10.0)
      end
    end

    context "#display_price" do
      before { greetingcard.price = 10.55 }

      it "shows the amount" do
        expect(greetingcard.display_price.to_s).to eq("$10.55")
      end

      context "with currency set to JPY" do
        before do
          greetingcard.master.default_price.currency = 'JPY'
          greetingcard.master.default_price.save!
          Spree::Config[:currency] = 'JPY'
        end

        it "displays the currency in yen" do
          expect(greetingcard.display_price.to_s).to eq("¥11")
        end
      end
    end

    context "#available?" do
      it "should be available if date is in the past" do
        greetingcard.available_on = 1.day.ago
        expect(greetingcard).to be_available
      end

      it "should not be available if date is nil or in the future" do
        greetingcard.available_on = nil
        expect(greetingcard).not_to be_available

        greetingcard.available_on = 1.day.from_now
        expect(greetingcard).not_to be_available
      end

      it "should not be available if destroyed" do
        greetingcard.destroy
        expect(greetingcard).not_to be_available
      end
    end

    context "#can_supply?" do
      it "should be true" do
        expect(greetingcard.can_supply?).to be(true)
      end

      it "should be false" do
        greetingcard.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }
        expect(greetingcard.can_supply?).to be(false)
      end
    end

    context "variants_and_option_values" do
      let!(:high) { create(:variant, greetingcard: greetingcard) }
      let!(:low) { create(:variant, greetingcard: greetingcard) }

      before { high.option_values.destroy_all }

      it "returns only variants with option values" do
        expect(greetingcard.variants_and_option_values).to eq([low])
      end
    end

    describe 'Variants sorting' do
      ORDER_REGEXP = /ORDER BY (\`|\")spree_variants(\`|\").(\'|\")position(\'|\") ASC/

      context 'without master variant' do
        it 'sorts variants by position' do
          expect(greetingcard.variants.to_sql).to match(ORDER_REGEXP)
        end
      end

      context 'with master variant' do
        it 'sorts variants by position' do
          expect(greetingcard.variants_including_master.to_sql).to match(ORDER_REGEXP)
        end
      end
    end

    context "has stock movements" do
      let(:variant) { greetingcard.master }
      let(:stock_item) { variant.stock_items.first }

      it "doesnt raise ReadOnlyRecord error" do
        Spree::StockMovement.create!(stock_item: stock_item, quantity: 1)
        expect { greetingcard.destroy }.not_to raise_error
      end
    end

    # Regression test for #3737
    context "has stock items" do
      it "can retrieve stock items" do
        expect(greetingcard.master.stock_items.first).not_to be_nil
        expect(greetingcard.stock_items.first).not_to be_nil
      end
    end

    context "slugs" do

      it "normalizes slug on update validation" do
        greetingcard.slug = "hey//joe"
        greetingcard.valid?
        expect(greetingcard.slug).not_to match "/"
      end

      context "when greetingcard destroyed" do

        it "renames slug" do
          expect { greetingcard.destroy }.to change { greetingcard.slug }
        end

        context "when slug is already at or near max length" do

          before do
            greetingcard.slug = "x" * 255
            greetingcard.save!
          end

          it "truncates renamed slug to ensure it remains within length limit" do
            greetingcard.destroy
            expect(greetingcard.slug.length).to eq 255
          end

        end

      end

      it "validates slug uniqueness" do
        existing_greetingcard = greetingcard
        new_greetingcard = create(:greetingcard)
        new_greetingcard.slug = existing_greetingcard.slug

        expect(new_greetingcard.valid?).to eq false
      end

      it "falls back to 'name-sku' for slug if regular name-based slug already in use" do
        greetingcard1 = build(:greetingcard)
        greetingcard1.name = "test"
        greetingcard1.sku = "123"
        greetingcard1.save!

        greetingcard2 = build(:greetingcard)
        greetingcard2.name = "test"
        greetingcard2.sku = "456"
        greetingcard2.save!

        expect(greetingcard2.slug).to eq 'test-456'
      end
    end

    context "hard deletion" do
      it "doesnt raise ActiveRecordError error" do
        expect { greetingcard.really_destroy! }.to_not raise_error
      end
    end

    context 'history' do
      before(:each) do
        @greetingcard = create(:greetingcard)
      end

      it 'should keep the history when the greetingcard is destroyed' do
        @greetingcard.destroy

        expect(@greetingcard.slugs.with_deleted).to_not be_empty
      end

      it 'should update the history when the greetingcard is restored' do
        @greetingcard.destroy

        @greetingcard.restore(recursive: true)

        latest_slug = @greetingcard.slugs.find_by slug: @greetingcard.slug
        expect(latest_slug).to_not be_nil
      end
    end
  end

  context "properties" do
    let(:greetingcard) { create(:greetingcard) }

    it "should properly assign properties" do
      greetingcard.set_property('the_prop', 'value1')
      expect(greetingcard.property('the_prop')).to eq('value1')

      greetingcard.set_property('the_prop', 'value2')
      expect(greetingcard.property('the_prop')).to eq('value2')
    end

    it "should not create duplicate properties when set_property is called" do
      expect {
        greetingcard.set_property('the_prop', 'value2')
        greetingcard.save
        greetingcard.reload
      }.not_to change(greetingcard.properties, :length)

      expect {
        greetingcard.set_property('the_prop_new', 'value')
        greetingcard.save
        greetingcard.reload
        expect(greetingcard.property('the_prop_new')).to eq('value')
      }.to change { greetingcard.properties.length }.by(1)
    end

    context 'optional property_presentation' do
      subject { Spree::Property.where(name: 'foo').first.presentation }
      let(:name) { 'foo' }
      let(:presentation) { 'baz' }

      describe 'is not used' do
        before { greetingcard.set_property(name, 'bar') }
        it { is_expected.to eq name }
      end

      describe 'is used' do
        before { greetingcard.set_property(name, 'bar', presentation) }
        it { is_expected.to eq presentation }
      end
    end

    # Regression test for #2455
    it "should not overwrite properties' presentation names" do
      Spree::Property.where(:name => 'foo').first_or_create!(:presentation => "Foo's Presentation Name")
      greetingcard.set_property('foo', 'value1')
      greetingcard.set_property('bar', 'value2')
      expect(Spree::Property.where(:name => 'foo').first.presentation).to eq("Foo's Presentation Name")
      expect(Spree::Property.where(:name => 'bar').first.presentation).to eq("bar")
    end

    # Regression test for #4416
    context "#possible_promotions" do
      let!(:possible_promotion) { create(:promotion, advertise: true, starts_at: 1.day.ago) }
      let!(:unadvertised_promotion) { create(:promotion, advertise: false, starts_at: 1.day.ago) }
      let!(:inactive_promotion) { create(:promotion, advertise: true, starts_at: 1.day.since) }

      before do
        greetingcard.promotion_rules.create!(promotion: possible_promotion)
        greetingcard.promotion_rules.create!(promotion: unadvertised_promotion)
        greetingcard.promotion_rules.create!(promotion: inactive_promotion)
      end

      it "lists the promotion as a possible promotion" do
        expect(greetingcard.possible_promotions).to include(possible_promotion)
        expect(greetingcard.possible_promotions).to_not include(unadvertised_promotion)
        expect(greetingcard.possible_promotions).to_not include(inactive_promotion)
      end
    end
  end

  context '#create' do
    let!(:prototype) { create(:prototype) }
    let!(:greetingcard) { Spree::Greetingcard.new(name: "Foo", price: 1.99, shipping_category_id: create(:shipping_category).id) }

    before { greetingcard.prototype_id = prototype.id }

    context "when prototype is supplied" do
      it "should create properties based on the prototype" do
        greetingcard.save
        expect(greetingcard.properties.count).to eq(1)
      end
    end

    context "when prototype with option types is supplied" do
      def build_option_type_with_values(name, values)
        values.each_with_object(create :option_type, name: name) do |val, ot|
          ot.option_values.create(name: val.downcase, presentation: val)
        end
      end

      let(:prototype) do
        size = build_option_type_with_values("size", %w(Small Medium Large))
        create(:prototype, :name => "Size", :option_types => [ size ])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      it "should create option types based on the prototype" do
        greetingcard.save
        expect(greetingcard.option_type_ids.length).to eq(1)
        expect(greetingcard.option_type_ids).to eq(prototype.option_type_ids)
      end

      it "should create greetingcard option types based on the prototype" do
        greetingcard.save
        expect(greetingcard.greetingcard_option_types.pluck(:option_type_id)).to eq(prototype.option_type_ids)
      end

      it "should create variants from an option values hash with one option type" do
        greetingcard.option_values_hash = option_values_hash
        greetingcard.save
        expect(greetingcard.variants.length).to eq(3)
      end

      it "should still create variants when option_values_hash is given but prototype id is nil" do
        greetingcard.option_values_hash = option_values_hash
        greetingcard.prototype_id = nil
        greetingcard.save
        expect(greetingcard.option_type_ids.length).to eq(1)
        expect(greetingcard.option_type_ids).to eq(prototype.option_type_ids)
        expect(greetingcard.variants.length).to eq(3)
      end

      it "should create variants from an option values hash with multiple option types" do
        color = build_option_type_with_values("color", %w(Red Green Blue))
        logo  = build_option_type_with_values("logo", %w(Ruby Rails Nginx))
        option_values_hash[color.id.to_s] = color.option_value_ids
        option_values_hash[logo.id.to_s] = logo.option_value_ids
        greetingcard.option_values_hash = option_values_hash
        greetingcard.save
        greetingcard.reload
        expect(greetingcard.option_type_ids.length).to eq(3)
        expect(greetingcard.variants.length).to eq(27)
      end
    end
  end

  context "#images" do
    let(:greetingcard) { create(:greetingcard) }
    let(:image) { File.open(File.expand_path('../../../fixtures/thinking-cat.jpg', __FILE__)) }
    let(:params) { {:viewable_id => greetingcard.master.id, :viewable_type => 'Spree::Variant', :attachment => image, :alt => "position 2", :position => 2} }

    before do
      Spree::Image.create(params)
      Spree::Image.create(params.merge({:alt => "position 1", :position => 1}))
      Spree::Image.create(params.merge({:viewable_type => 'ThirdParty::Extension', :alt => "position 1", :position => 2}))
    end

    it "only looks for variant images" do
      expect(greetingcard.images.size).to eq(2)
    end

    it "should be sorted by position" do
      expect(greetingcard.images.pluck(:alt)).to eq(["position 1", "position 2"])
    end
  end

  # Regression tests for #2352
  context "classifications and taxons" do
    it "is joined through classifications" do
      reflection = Spree::Greetingcard.reflect_on_association(:taxons)
      expect(reflection.options[:through]).to eq(:classifications)
    end

    it "will delete all classifications" do
      reflection = Spree::Greetingcard.reflect_on_association(:classifications)
      expect(reflection.options[:dependent]).to eq(:delete_all)
    end
  end

  context '#total_on_hand' do
    let(:greetingcard) { create(:greetingcard) }

    it 'should be infinite if track_inventory_levels is false' do
      Spree::Config[:track_inventory_levels] = false
      expect(build(:greetingcard, :variants_including_master => [build(:master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'should be infinite if variant is on demand' do
      Spree::Config[:track_inventory_levels] = true
      expect(build(:greetingcard, :variants_including_master => [build(:on_demand_master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'should return sum of stock items count_on_hand' do
      greetingcard.stock_items.first.set_count_on_hand 5
      greetingcard.variants_including_master(true) # force load association
      expect(greetingcard.total_on_hand).to eql(5)
    end

    it 'should return sum of stock items count_on_hand when variants_including_master is not loaded' do
      greetingcard.stock_items.first.set_count_on_hand 5
      expect(greetingcard.reload.total_on_hand).to eql(5)
    end
  end

  # Regression spec for https://github.com/spree/spree/issues/5588
  context '#validate_master when duplicate SKUs entered' do
    let!(:first_greetingcard) { create(:greetingcard, sku: 'a-sku') }
    let(:second_greetingcard) { build(:greetingcard, sku: 'a-sku') }

    subject { second_greetingcard }
    it { is_expected.to be_invalid }
  end

  it "initializes a master variant when building a greetingcard" do
    greetingcard = Spree::Greetingcard.new
    expect(greetingcard.master.is_master).to be true
  end

  context "#discontinue!" do
    let(:greetingcard) { create(:greetingcard, sku: 'a-sku') }

    it "sets the discontinued" do
      greetingcard.discontinue!
      greetingcard.reload
      expect(greetingcard.discontinued?).to be(true)
    end

    it "changes updated_at" do
      expect { greetingcard.discontinue! }.to change { greetingcard.updated_at }
    end
  end

  context "#discontinued?" do
    let(:greetingcard_live) { build(:greetingcard, sku: "a-sku") }
    it "should be false" do
      expect(greetingcard_live.discontinued?).to be(false)
    end

    let(:greetingcard_discontinued) { build(:greetingcard, sku: "a-sku", discontinue_on: Time.now - 1.day)  }
    it "should be true" do
      expect(greetingcard_discontinued.discontinued?).to be(true)
    end
  end
end
