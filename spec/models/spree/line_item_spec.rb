require 'spec_helper'

describe Spree::LineItem, type: :model do
  let(:order) { create :order_with_line_items, line_items_count: 1 }
  let(:line_item) { order.line_items.first }

  before { create(:store) }

  describe 'Validations' do
    it { expect(line_item).to validate_numericality_of(:quantity).only_integer.with_message(Spree.t('validation.must_be_int')) }
  end

  describe '#ensure_valid_quantity' do
    context 'quantity.nil?' do
      before do
        line_item.quantity = nil
        line_item.valid?
      end

      it { expect(line_item.quantity).to be_zero }
    end

    context 'quantity < 0' do
      before do
        line_item.quantity = -1
        line_item.valid?
      end

      it { expect(line_item.quantity).to be_zero }
    end

    context 'quantity = 0' do
      before do
        line_item.quantity = 0
        line_item.valid?
      end

      it { expect(line_item.quantity).to be_zero }
    end

    context 'quantity > 0' do
      let(:original_quantity) { 1 }

      before do
        line_item.quantity = original_quantity
        line_item.valid?
      end

      it { expect(line_item.quantity).to eq(original_quantity) }
    end
  end

  context '#save' do
    it 'touches the order' do
      expect(line_item.order).to receive(:touch)
      line_item.touch
    end
  end

  context "#discontinued" do
    it "fetches discontinued products" do
      line_item.product.discontinue!
      expect(line_item.reload.product).to be_a Spree::Product
    end
    
    it "fetches discontinued greetingcards" do
      line_item.greetingcard.discontinue!
      expect(line_item.reload.greetingcard).to be_a Spree::Greetingcard
    end

    it "fetches discontinued variants" do
      line_item.variant.discontinue!
      expect(line_item.reload.variant).to be_a Spree::Variant
    end
  end

  context "#destroy" do
    it "returns inventory when a line item is destroyed" do
      expect_any_instance_of(Spree::OrderInventory).to receive(:verify)
      line_item.destroy
    end

    it "deletes inventory units" do
      expect { line_item.destroy }.to change { line_item.inventory_units.count }.from(1).to(0)
    end
  end

  context "#save" do
    context "line item changes" do
      before do
        line_item.quantity = line_item.quantity + 1
      end

      it "triggers adjustment total recalculation" do
        expect(line_item).to receive(:update_tax_charge) # Regression test for https://github.com/spree/spree/issues/4671
        expect(line_item).to receive(:recalculate_adjustments)
        line_item.save
      end
    end

    context "line item does not change" do
      it "does not trigger adjustment total recalculation" do
        expect(line_item).not_to receive(:recalculate_adjustments)
        line_item.save
      end
    end

    context "target_shipment is provided" do
      it "verifies inventory" do
        line_item.target_shipment = Spree::Shipment.new
        expect_any_instance_of(Spree::OrderInventory).to receive(:verify)
        line_item.save
      end
    end
  end

  context "#create" do
    let(:variant) { create(:variant) }

    before do
      create(:tax_rate, zone: order.tax_zone, tax_category: variant.tax_category)
    end

    context "when order has a tax zone" do
      before do
        expect(order.tax_zone).to be_present
      end

      it "creates a tax adjustment" do
        order.contents.add(variant)
        line_item = order.find_line_item_by_variant(variant)
        expect(line_item.adjustments.tax.count).to eq(1)
      end
    end

    context "when order does not have a tax zone" do
      before do
        order.bill_address = nil
        order.ship_address = nil
        order.save
        expect(order.reload.tax_zone).to be_nil
      end

      it "does not create a tax adjustment" do
        order.contents.add(variant)
        line_item = order.find_line_item_by_variant(variant)
        expect(line_item.adjustments.tax.count).to eq(0)
      end
    end
  end

  # Test for #3391
  context '#copy_price' do
    it "copies over a variant's prices" do
      line_item.price = nil
      line_item.cost_price = nil
      line_item.currency = nil
      line_item.copy_price
      variant = line_item.variant
      expect(line_item.price).to eq(variant.price)
      expect(line_item.cost_price).to eq(variant.cost_price)
      expect(line_item.currency).to eq(variant.currency)
    end
  end

  # test for copying prices when the vat changes
  context "#update_price" do
    it "copies over a variants differing price for another vat zone" do
      expect(line_item.variant).to receive(:price_including_vat_for).and_return(12)
      line_item.price = 10
      line_item.update_price
      expect(line_item.price).to eq(12)
    end
  end

  # Test for #3481
  context '#copy_tax_category' do
    it "copies over a variant's tax category" do
      line_item.tax_category = nil
      line_item.copy_tax_category
      expect(line_item.tax_category).to eq(line_item.variant.tax_category)
    end
  end

  describe '#discounted_amount' do
    it "returns the amount minus any discounts" do
      line_item.price = 10
      line_item.quantity = 2
      line_item.taxable_adjustment_total = -5
      expect(line_item.discounted_amount).to eq(15)
    end
  end

  describe '.currency' do
    it 'returns the globally configured currency' do
      line_item.currency == 'USD'
    end
  end

  describe "#discounted_money" do
    it "should return a money object with the discounted amount" do
      expect(line_item.discounted_money.to_s).to eq "$10.00"
    end
  end

  describe "#money" do
    before do
      line_item.price = 3.50
      line_item.quantity = 2
    end

    it "returns a Spree::Money representing the total for this line item" do
      expect(line_item.money.to_s).to eq("$7.00")
    end
  end

  describe '#single_money' do
    before do
      line_item.price = 3.50
      line_item.quantity = 2
    end

    it "returns a Spree::Money representing the price for one variant" do
      expect(line_item.single_money.to_s).to eq("$3.50")
    end
  end

  context "has inventory (completed order so items were already unstocked)" do
    let(:order) { Spree::Order.create(email: 'spree@example.com') }
    let(:variant) { create(:variant) }

    context "nothing left on stock" do
      before do
        variant.stock_items.update_all count_on_hand: 5, backorderable: false
        order.contents.add(variant, 5)
        order.create_proposed_shipments
        order.finalize!
      end

      it "allows to decrease item quantity" do
        line_item = order.line_items.first
        line_item.quantity -= 1
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item.errors_on(:quantity).size).to eq(0)
      end

      it "doesnt allow to increase item quantity" do
        line_item = order.line_items.first
        line_item.quantity += 2
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item.errors_on(:quantity).size).to eq(1)
      end
    end

    context "2 items left on stock" do
      before do
        variant.stock_items.update_all count_on_hand: 7, backorderable: false
        order.contents.add(variant, 5)
        order.create_proposed_shipments
        order.finalize!
      end

      it "allows to increase quantity up to stock availability" do
        line_item = order.line_items.first
        line_item.quantity += 2
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item.errors_on(:quantity).size).to eq(0)
      end

      it "doesnt allow to increase quantity over stock availability" do
        line_item = order.line_items.first
        line_item.quantity += 3
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item.errors_on(:quantity).size).to eq(1)
      end
    end
  end

  context "currency same as order.currency" do
    it "is a valid line item" do
      line_item = order.line_items.first
      line_item.currency = order.currency
      line_item.valid?

      expect(line_item.error_on(:currency).size).to eq(0)
    end
  end

  context "currency different than order.currency" do
    it "is not a valid line item" do
      line_item = order.line_items.first
      line_item.currency = "no currency"
      line_item.valid?

      expect(line_item.error_on(:currency).size).to eq(1)
    end
  end

  describe "#options=" do
    it "can handle updating a blank line item with no order" do
      line_item.options = { price: 123 }
    end

    it "updates the data provided in the options" do
      line_item.options = { price: 123 }
      expect(line_item.price).to eq 123
    end

    it "updates the price based on the options provided" do
      expect(line_item).to receive(:gift_wrap=).with(true)
      expect(line_item.variant).to receive(:gift_wrap_price_modifier_amount_in).with("USD", true).and_return 1.99
      line_item.options = { gift_wrap: true }
      expect(line_item.price).to eq 21.98
    end
  end

  describe "precision of pre_tax_amount" do
    let!(:line_item) { create :line_item, pre_tax_amount: 4.2051 }

    it "keeps four digits of precision even when reloading" do
      expect(line_item.reload.pre_tax_amount).to eq(4.2051)
    end
  end
end