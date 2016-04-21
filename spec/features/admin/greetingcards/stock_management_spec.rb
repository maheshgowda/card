require 'spec_helper'

describe "Stock Management", type: :feature, js: true do
  stub_authorization!

  context "given a greetingcard with a variant and a stock location" do
    let!(:stock_location) { create(:stock_location, name: 'Default') }
    let!(:greetingcard) { create(:greetingcard, name: 'apache baseball cap', price: 10) }
    let!(:variant) { greetingcard.master }

    before do
      stock_location.stock_item(variant).update_column(:count_on_hand, 10)
      visit spree.stock_admin_greetingcard_path(greetingcard)
    end

    context "toggle backorderable for a variant's stock item" do
      let(:backorderable) { find ".stock_item_backorderable" }

      before do
        expect(backorderable).to be_checked
        backorderable.set(false)
        wait_for_ajax
      end

      it "persists the value when page reload" do
        visit current_path
        expect(backorderable).not_to be_checked
      end
    end

    context "toggle track inventory for a variant's stock item" do
      let(:track_inventory) { find ".track_inventory_checkbox" }

      before do
        expect(track_inventory).to be_checked
        track_inventory.set(false)
        wait_for_ajax
      end

      it "persists the value when page reloaded" do
        visit current_path
        expect(track_inventory).not_to be_checked
      end
    end

    # Regression test for #2896
    # The regression was that unchecking the last checkbox caused a redirect
    # to happen. By ensuring that we're still on an /admin/greetingcards URL, we
    # assert that the redirect is *not* happening.
    it "can toggle backorderable for the second variant stock item" do
      new_location = create(:stock_location, name: "Another Location")
      visit current_url

      new_location_backorderable = find "#stock_item_backorderable_#{new_location.id}"
      new_location_backorderable.set(false)
      wait_for_ajax

      expect(page.current_url).to include("/admin/greetingcards")
    end

    it "can create a new stock movement" do
      fill_in "stock_movement_quantity", with: 5
      select2 "default", from: "Stock Location"
      click_button "Add Stock"

      expect(page).to have_content('successfully created')

      within(:css, '.stock_location_info table') do
        expect(column_text(2)).to eq '15'
      end
    end

    it "can create a new negative stock movement" do
      fill_in "stock_movement_quantity", with: -5
      select2 "default", from: "Stock Location"
      click_button "Add Stock"

      expect(page).to have_content('successfully created')

      within(:css, '.stock_location_info table') do
        expect(column_text(2)).to eq '5'
      end
    end

    context "with multiple variants" do
      let!(:variant) { create(:variant, greetingcard: greetingcard, sku: 'SPREEC') }
      before do
        variant.stock_items.first.update_column(:count_on_hand, 30)
        visit current_url
      end

      it "can create a new stock movement for the specified variant" do
        fill_in "stock_movement_quantity", with: 10
        select2 "SPREEC", from: "Variant"
        click_button "Add Stock"

        expect(page).to have_content('successfully created')

        within("#listing_greetingcard_stock tr", :text => "SPREEC") do
          within("table") do
            expect(column_text(2)).to eq '40'
          end
        end
      end
    end

    # Regression test for #3304
    context "with no stock location" do
      let(:greetingcard) { create(:greetingcard, name: 'apache baseball cap', price: 10) }
      let(:variant) { create(:variant, greetingcard: greetingcard, sku: 'FOOBAR') }

      before do
        Spree::StockLocation.delete_all

        visit spree.stock_admin_greetingcard_path(greetingcard)
      end

      it "redirects to stock locations page", js: false do
        expect(page).to have_content(Spree.t(:stock_management_requires_a_stock_location))
        expect(page.current_url).to include("admin/stock_locations")
      end
    end
  end
end