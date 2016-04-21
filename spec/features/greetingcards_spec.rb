# encoding: utf-8
require 'spec_helper'

describe "Visiting Greetingcards", type: :feature, inaccessible: true do
  include_context "custom greetingcards"

  let(:store_name) do
    ((first_store = Spree::Store.first) && first_store.name).to_s
  end

  before(:each) do
    visit spree.root_path
  end

  it "should be able to show the shopping cart after adding a greetingcard to it" do
    click_link "Ruby on Rails Ringer T-Shirt"
    expect(page).to have_content("$19.99")

    click_button 'add-to-cart-button'
    expect(page).to have_content("Shopping Cart")
  end

  describe "correct displaying of microdata" do
    let(:greetingcards) { Spree::TestingSupport::Microdata::Document.new(page.body).extract_items }
    let(:ringer) { greetingcards.keep_if { |greetingcard| greetingcard.properties["name"].first.match("Ringer") }.first }

    it "correctly displays the greetingcard name via microdata" do
      expect(ringer.properties["name"]).to eq ["Ruby on Rails Ringer T-Shirt"]
    end

    it "correctly displays the greetingcard image via microdata" do
      expect(ringer.properties['image'].first).to include '/assets/noimage/small'
    end

    it "correctly displays the greetingcard url via microdata" do
      expect(ringer.properties["url"]).to eq ["http://www.example.com/greetingcards/ruby-on-rails-ringer-t-shirt"]
    end
  end

  describe 'meta tags and title' do
    let(:jersey) { Spree::Greetingcard.find_by_name('Ruby on Rails Baseball Jersey') }
    let(:metas) { { meta_description: 'Brand new Ruby on Rails Jersey', meta_title: 'Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel', meta_keywords: 'ror, jersey, ruby' } }

    it 'should return the correct title when displaying a single greetingcard' do
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
      within('div#greetingcard-description') do
        within('h1.greetingcard-title') do
          expect(page).to have_content('Ruby on Rails Baseball Jersey')
        end
      end
    end

    it 'displays metas' do
      jersey.update_attributes metas
      click_link jersey.name
      expect(page).to have_meta(:description, 'Brand new Ruby on Rails Jersey')
      expect(page).to have_meta(:keywords, 'ror, jersey, ruby')
    end

    it 'displays title if set' do
      jersey.update_attributes metas
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey Buy High Quality Geek Apparel')
    end

    it "doesn't use meta_title as heading on page" do
      jersey.update_attributes metas
      click_link jersey.name
      within("h1") do
        expect(page).to have_content(jersey.name)
        expect(page).not_to have_content(jersey.meta_title)
      end
    end

    it 'uses greetingcard name in title when meta_title set to empty string' do
      jersey.update_attributes meta_title: ''
      click_link jersey.name
      expect(page).to have_title('Ruby on Rails Baseball Jersey - ' + store_name)
    end
  end

  context "using Russian Rubles as a currency" do
    before do
      Spree::Config[:currency] = "RUB"
    end

    let!(:greetingcard) do
      greetingcard = Spree::Greetingcard.find_by_name("Ruby on Rails Ringer T-Shirt")
      greetingcard.price = 19.99
      greetingcard.tap(&:save)
    end

    # Regression tests for #2737
    context "uses руб as the currency symbol" do
      it "on greetingcards page" do
        visit spree.root_path
        within("#greetingcard_#{greetingcard.id}") do
          within(".price") do
            expect(page).to have_content("19.99 ₽")
          end
        end
      end

      it "on greetingcard page" do
        visit spree.greetingcard_path(greetingcard)
        within(".price") do
          expect(page).to have_content("19.99 ₽")
        end
      end

      it "when adding a greetingcard to the cart", js: true do
        visit spree.greetingcard_path(greetingcard)
        click_button "Add To Cart"
        click_link "Home"
        within(".cart-info") do
          expect(page).to have_content("19.99 ₽")
        end
      end

      it "when on the 'address' state of the cart", js: true do
        visit spree.greetingcard_path(greetingcard)
        click_button "Add To Cart"
        click_button "Checkout"
        fill_in "order_email", with: "test@example.com"
        click_button 'Continue'
        within("tr[data-hook=item_total]") do
          expect(page).to have_content("19.99 ₽")
        end
      end
    end
  end

  it "should be able to search for a greetingcard" do
    fill_in "keywords", with: "shirt"
    click_button "Search"

    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(1)
  end

  context "a greetingcard with variants" do
    let(:greetingcard) { Spree::Greetingcard.find_by_name("Ruby on Rails Baseball Jersey") }
    let(:option_value) { create(:option_value) }
    let!(:variant) { build(:variant, price: 5.59, greetingcard: greetingcard, option_values: []) }

    before do
      # Need to have two images to trigger the error
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))
      greetingcard.images.create!(:attachment => image)
      greetingcard.images.create!(:attachment => image)

      greetingcard.option_types << option_value.option_type
      variant.option_values << option_value
      variant.save!
    end

    it "should be displayed" do
      expect { click_link greetingcard.name }.to_not raise_error
    end

    it "displays price of first variant listed", js: true do
      click_link greetingcard.name
      within("#greetingcard-price") do
        expect(page).to have_content variant.price
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display out of stock for master greetingcard" do
      greetingcard.master.stock_items.update_all count_on_hand: 0, backorderable: false

      click_link greetingcard.name
      within("#greetingcard-price") do
        expect(page).not_to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if all variants (including master) are out of stock" do
      greetingcard.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }

      click_link greetingcard.name
      within("[data-hook=greetingcard_price]") do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context "a greetingcard with variants, images only for the variants" do
    let(:greetingcard) { Spree::Greetingcard.find_by_name("Ruby on Rails Baseball Jersey") }
    let(:variant1) { create(:variant, greetingcard: greetingcard, price: 9.99) }
    let(:variant2) { create(:variant, greetingcard: greetingcard, price: 10.99) }

    before do
      image = File.open(File.expand_path('../../fixtures/thinking-cat.jpg', __FILE__))
      variant1.images.create!(attachment: image)
      variant2.images.create!(attachment: image)
    end

    it "should not display no image available" do
      visit spree.root_path
      expect(page).to have_xpath("//img[contains(@src,'thinking-cat')]")
    end
  end

  context "an out of stock greetingcard without variants" do
    let(:greetingcard) { Spree::Greetingcard.find_by_name("Ruby on Rails Tote") }

    before do
      greetingcard.master.stock_items.update_all count_on_hand: 0, backorderable: false
    end

    it "does display out of stock for master greetingcard" do
      click_link greetingcard.name
      within("#greetingcard-price") do
        expect(page).to have_content Spree.t(:out_of_stock)
      end
    end

    it "doesn't display cart form if master is out of stock" do
      click_link greetingcard.name
      within("[data-hook=greetingcard_price]") do
        expect(page).not_to have_content Spree.t(:add_to_cart)
      end
    end
  end

  context 'greetingcard with taxons' do
    let(:greetingcard) { Spree::Greetingcard.find_by_name("Ruby on Rails Tote") }
    let(:taxon) { greetingcard.taxons.first }

    it 'displays breadcrumbs for the default taxon when none selected' do
      click_link greetingcard.name
      within("#breadcrumbs") do
        expect(page).to have_content taxon.name
      end
    end

    it 'displays selected taxon in breadcrumbs' do
      taxon = Spree::Taxon.last
      greetingcard.taxons << taxon
      greetingcard.save!
      visit '/t/' + taxon.to_param
      click_link greetingcard.name
      within("#breadcrumbs") do
        expect(page).to have_content taxon.name
      end
    end
  end

  it "should be able to hide greetingcards without price" do
    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(9)
    Spree::Config.show_greetingcards_without_price = false
    Spree::Config.currency = "CAN"
    visit spree.root_path
    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(0)
  end


  it "should be able to display greetingcards priced under 10 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_Under_$10.00"
    within(:css, '#sidebar_greetingcards_search') { click_button "Search" }
    expect(page).to have_content("No greetingcards found")
  end

  it "should be able to display greetingcards priced between 15 and 18 dollars" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_greetingcards_search') { click_button "Search" }

    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(3)
    tmp = page.all('#greetingcards .greetingcard-list-item a').map(&:text).flatten.compact
    tmp.delete("")
    expect(tmp.sort!).to eq(["Ruby on Rails Mug", "Ruby on Rails Stein", "Ruby on Rails Tote"])
  end

  it "should be able to display greetingcards priced between 15 and 18 dollars across multiple pages" do
    Spree::Config.greetingcards_per_page = 2
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$15.00_-_$18.00"
    within(:css, '#sidebar_greetingcards_search') { click_button "Search" }

    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(2)
    greetingcards = page.all('#greetingcards .greetingcard-list-item span[itemprop=name]')
    expect(greetingcards.count).to eq(2)

    find('.pagination .next a').click
    greetingcards = page.all('#greetingcards .greetingcard-list-item span[itemprop=name]')
    expect(greetingcards.count).to eq(1)
  end

  it "should be able to display greetingcards priced 18 dollars and above" do
    within(:css, '#taxonomies') { click_link "Ruby on Rails" }
    check "Price_Range_$18.00_-_$20.00"
    check "Price_Range_$20.00_or_over"
    within(:css, '#sidebar_greetingcards_search') { click_button "Search" }

    expect(page.all('#greetingcards .greetingcard-list-item').size).to eq(4)
    tmp = page.all('#greetingcards .greetingcard-list-item a').map(&:text).flatten.compact
    tmp.delete("")
    expect(tmp.sort!).to eq(["Ruby on Rails Bag",
                         "Ruby on Rails Baseball Jersey",
                         "Ruby on Rails Jr. Spaghetti",
                         "Ruby on Rails Ringer T-Shirt"])
  end

  it "should be able to put a greetingcard without a description in the cart" do
    greetingcard = FactoryGirl.create(:base_greetingcard, :description => nil, :name => 'Sample', :price => '19.99')
    visit spree.greetingcard_path(greetingcard)
    expect(page).to have_content "This greetingcard has no description"
    click_button 'add-to-cart-button'
    expect(page).to have_content "This greetingcard has no description"
  end

  it "shouldn't be able to put a greetingcard without a current price in the cart" do
    greetingcard = FactoryGirl.create(:base_greetingcard, :description => nil, :name => 'Sample', :price => '19.99')
    Spree::Config.currency = "CAN"
    Spree::Config.show_greetingcards_without_price = true
    visit spree.greetingcard_path(greetingcard)
    expect(page).to have_content "This greetingcard is not available in the selected currency."
    expect(page).not_to have_content "add-to-cart-button"
  end

  it "should return the correct title when displaying a single greetingcard" do
    greetingcard = Spree::Greetingcard.find_by_name("Ruby on Rails Baseball Jersey")
    click_link greetingcard.name

    within("div#greetingcard-description") do
      within("h1.greetingcard-title") do
        expect(page).to have_content("Ruby on Rails Baseball Jersey")
      end
    end
  end
end
