require 'spec_helper'

describe "Greetingcard scopes", :type => :model do
  let!(:greetingcard) { create(:greetingcard) }

  describe '#available' do
    context 'when discontinued' do
      let!(:discontinued_greetingcard) { create(:greetingcard, discontinue_on: Time.current - 1.day) }

      it { expect(Spree::Greetingcard.available).not_to include(discontinued_greetingcard) }
    end

    context 'when not discontinued' do
      let!(:greetingcard_2) { create(:greetingcard, discontinue_on: Time.current + 1.day) }

      it { expect(Spree::Greetingcard.available).to include(greetingcard_2) }
    end

    context 'when available' do
      let!(:greetingcard_2) { create(:greetingcard, available_on: Time.current - 1.day) }

      it { expect(Spree::Greetingcard.available).to include(greetingcard_2) }
    end

    context 'when not available' do
      let!(:unavailable_greetingcard) { create(:greetingcard, available_on: Time.current + 1.day) }

      it { expect(Spree::Greetingcard.available).not_to include(unavailable_greetingcard) }
    end

    context 'when multiple prices present' do
      let!(:price_1) { create(:price, currency: 'EUR', variant: greetingcard.master) }
      let!(:price_2) { create(:price, currency: 'EUR', variant: greetingcard.master) }

      it 'should not duplicate greetingcard' do
        expect(Spree::Greetingcard.available).to eq([greetingcard])
      end
    end
  end

  context "A greetingcard assigned to parent and child taxons" do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root

      @parent_taxon = create(:taxon, :name => 'Parent', :taxonomy_id => @taxonomy.id, :parent => @root_taxon)
      @child_taxon = create(:taxon, :name =>'Child 1', :taxonomy_id => @taxonomy.id, :parent => @parent_taxon)
      @parent_taxon.reload # Need to reload for descendents to show up

      greetingcard.taxons << @parent_taxon
      greetingcard.taxons << @child_taxon
    end

    it "calling Greetingcard.in_taxon returns greetingcards in child taxons" do
      greetingcard.taxons -= [@child_taxon]
      expect(greetingcard.taxons.count).to eq(1)

      expect(Spree::Greetingcard.in_taxon(@parent_taxon)).to include(Greetingcard)
    end

    it "calling Greetingcard.in_taxon should not return duplicate records" do
      expect(Spree::Greetingcard.in_taxon(@parent_taxon).to_a.count).to eq(1)
    end

    context 'orders greetingcards based on their ordering within the classifications' do
      let(:other_taxon) { create(:taxon, greetingcards: [greetingcard]) }
      let!(:greetingcard_2) { create(:greetingcard, taxons: [@child_taxon, other_taxon]) }

      it 'by initial ordering' do
        expect(Spree::Greetingcard.in_taxon(@child_taxon)).to eq([greetingcard, greetingcard_2])
        expect(Spree::Greetingcard.in_taxon(other_taxon)).to eq([greetingcard, greetingcard_2])
      end

      it 'after ordering changed' do
        [@child_taxon, other_taxon].each do |taxon|
          Spree::Classification.find_by(:taxon => taxon, :greetingcard => greetingcard).insert_at(2)
          expect(Spree::Greetingcard.in_taxon(taxon)).to eq([greetingcard_2, greetingcard])
        end
      end
    end
  end

  context '#add_simple_scopes' do
    let(:simple_scopes) { [:ascend_by_updated_at, :descend_by_name] }

    before do
      Spree::Greetingcard.add_simple_scopes(simple_scopes)
    end

    context 'define scope' do
      context 'ascend_by_updated_at' do
        context 'on class' do
          it { expect(Spree::Greetingcard.ascend_by_updated_at.to_sql).to eq Spree::Greetingcard.order("#{Spree::Greetingcard.quoted_table_name}.updated_at ASC").to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { expect(Spree::Greetingcard.limit(2).ascend_by_updated_at.to_sql).to eq Spree::Greetingcard.limit(2).order("#{Spree::Greetingcard.quoted_table_name}.updated_at ASC").to_sql }
          it { expect(Spree::Greetingcard.limit(2).ascend_by_updated_at.to_sql).to eq Spree::Greetingcard.ascend_by_updated_at.limit(2).to_sql }
        end
      end

      context 'descend_by_name' do
        context 'on class' do
          it { expect(Spree::Greetingcard.descend_by_name.to_sql).to eq Spree::Greetingcard.order("#{Spree::Greetingcard.quoted_table_name}.name DESC").to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { expect(Spree::Greetingcard.limit(2).descend_by_name.to_sql).to eq Spree::Greetingcard.limit(2).order("#{Spree::Greetingcard.quoted_table_name}.name DESC").to_sql }
          it { expect(Spree::Greetingcard.limit(2).descend_by_name.to_sql).to eq Spree::Greetingcard.descend_by_name.limit(2).to_sql }
        end
      end
    end
  end
end
