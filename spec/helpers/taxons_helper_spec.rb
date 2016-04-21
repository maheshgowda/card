require 'spec_helper'

describe Spree::TaxonsHelper, :type => :helper do
  # Regression test for #4382
  it "#taxon_preview" do
    taxon = create(:taxon)
    child_taxon = create(:taxon, parent: taxon)
    product_1 = create(:product)
    product_2 = create(:product)
    product_3 = create(:product)
    taxon.products << product_1
    taxon.products << product_2
    child_taxon.products << product_3

    expect(taxon_preview(taxon.reload)).to eql([product_1, product_2, product_3])
    
    greetingcard_1 = create(:greetingcard)
    greetingcard_2 = create(:greetingcard)
    greetingcard_3 = create(:greetingcard)
    taxon.greetingcards << greetingcard_1
    taxon.greetingcards << greetingcard_2
    child_taxon.greetingcards << greetingcard_3

    expect(taxon_preview(taxon.reload)).to eql([greetingcard_1, greetingcard_2, greetingcard_3])
  end
end
