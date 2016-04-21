require 'spec_helper'

Spree::Product.class_eval do
  attribute :slug, ActiveRecord::Type::String.new(limit: 255)
  # Slug currently has no validation for maximum length
  validates :slug, db_maximum_length: true
end

Spree::Greetingcard.class_eval do
  attribute :slug, ActiveRecord::Type::String.new(limit: 255)
  # Slug currently has no validation for maximum length
  validates :slug, db_maximum_length: true
end

describe DbMaximumLengthValidator, type: :model do
  let(:limit_for_slug) { Spree::Product.columns_hash['slug'].limit.to_i }
  let(:product) { Spree::Product.new }
  let(:limit_for_slug) { Spree::Greetingcard.columns_hash['slug'].limit.to_i }
  let(:greetingcard) { Spree::Greetingcard.new }
  let(:slug) { 'x' * (limit_for_slug + 1) }

  before do
    product.slug = slug
    greetingcard.slug = slug
  end

  it 'should maximum validate slug' do
    product.valid?
    expect(product.errors[:slug]).to include(I18n.t("errors.messages.too_long", count: limit_for_slug))
    greetingcard.valid?
    expect(greetingcard.errors[:slug]).to include(I18n.t("errors.messages.too_long", count: limit_for_slug))
  end
end
