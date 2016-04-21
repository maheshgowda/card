require 'spec_helper'

describe 'greetingcards', :type => :feature, :caching => true do
  let!(:greetingcard) { create(:greetingcard) }
  let!(:greetingcard2) { create(:greetingcard) }
  let!(:taxonomy) { create(:taxonomy) }
  let!(:taxon) { create(:taxon, :taxonomy => taxonomy) }

  before do
    greetingcard2.update_column(:updated_at, 1.day.ago)
    # warm up the cache
    visit spree.root_path
    assert_written_to_cache("views/en/USD/spree/greetingcards/all--#{greetingcard.updated_at.utc.to_s(:number)}")
    assert_written_to_cache("views/en/USD/spree/greetingcards/#{greetingcard.id}-#{greetingcard.updated_at.utc.to_s(:number)}")
    assert_written_to_cache("views/en/spree/taxonomies/#{taxonomy.id}")
    assert_written_to_cache("views/en/taxons/#{taxon.updated_at.utc.to_i}")

    clear_cache_events
  end

  it "reads from cache upon a second viewing" do
    visit spree.root_path
    expect(cache_writes.count).to eq(0)
  end

  it "busts the cache when a greetingcard is updated" do
    greetingcard.update_column(:updated_at, 1.day.from_now)
    visit spree.root_path
    assert_written_to_cache("views/en/USD/spree/greetingcards/all--#{greetingcard.updated_at.utc.to_s(:number)}")
    assert_written_to_cache("views/en/USD/spree/greetingcards/#{greetingcard.id}-#{greetingcard.updated_at.utc.to_s(:number)}")
    expect(cache_writes.count).to eq(2)
  end

  it "busts the cache when all greetingcards are deleted" do
    greetingcard.destroy
    greetingcard2.destroy
    visit spree.root_path
    assert_written_to_cache("views/en/USD/spree/greetingcards/all--#{Date.today.to_s(:number)}-0")
    expect(cache_writes.count).to eq(1)
  end

  it "busts the cache when the newest greetingcard is deleted" do
    greetingcard.destroy
    visit spree.root_path
    assert_written_to_cache("views/en/USD/spree/greetingcards/all--#{greetingcard2.updated_at.utc.to_s(:number)}")
    expect(cache_writes.count).to eq(1)
  end

  it "busts the cache when an older greetingcard is deleted" do
    greetingcard2.destroy
    visit spree.root_path
    assert_written_to_cache("views/en/USD/spree/greetingcards/all--#{greetingcard.updated_at.utc.to_s(:number)}")
    expect(cache_writes.count).to eq(1)
  end
end
