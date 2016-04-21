require 'spec_helper'

describe Spree::Promotion::Rules::Greetingcard, :type => :model do
  let(:rule) { Spree::Promotion::Rules::Greetingcard.new(rule_options) }
  let(:rule_options) { {} }

  context "#eligible?(order)" do
    let(:order) { Spree::Order.new }

    it "should be eligible if there are no greetingcards" do
      allow(rule).to receive_messages(:eligible_greetingcards => [])
      expect(rule).to be_eligible(order)
    end

    before do
      3.times { |i| instance_variable_set("@greetingcard#{i}", mock_model(Spree::Greetingcard)) }
    end

    context "with 'any' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'any') }

      it "should be eligible if any of the greetingcards is in eligible greetingcards" do
        allow(order).to receive_messages(:greetingcards => [@greetingcard1, @greetingcard2])
        allow(rule).to receive_messages(:eligible_greetingcards => [@greetingcard2, @greetingcard3])
        expect(rule).to be_eligible(order)
      end

      context "when none of the greetingcards are eligible greetingcards" do
        before do
          allow(order).to receive_messages(greetingcards: [@greetingcard1])
          allow(rule).to receive_messages(eligible_greetingcards: [@greetingcard2, @greetingcard3])
        end
        it { expect(rule).not_to be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "You need to add an applicable greetingcard before applying this coupon code."
        end
      end
    end

    context "with 'all' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'all') }

      it "should be eligible if all of the eligible greetingcards are ordered" do
        allow(order).to receive_messages(:greetingcards => [@greetingcard3, @greetingcard2, @greetingcard1])
        allow(rule).to receive_messages(:eligible_greetingcards => [@greetingcard2, @greetingcard3])
        expect(rule).to be_eligible(order)
      end

      context "when any of the eligible greetingcards is not ordered" do
        before do
          allow(order).to receive_messages(greetingcards: [@greetingcard1, @greetingcard2])
          allow(rule).to receive_messages(eligible_greetingcards: [@greetingcard1, @greetingcard2, @greetingcard3])
        end
        it { expect(rule).not_to be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied because you don't have all of the necessary greetingcards in your cart."
        end
      end
    end

    context "with 'none' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'none') }

      it "should be eligible if none of the order's greetingcards are in eligible greetingcards" do
        allow(order).to receive_messages(:greetingcards => [@greetingcard1])
        allow(rule).to receive_messages(:eligible_greetingcards => [@greetingcard2, @greetingcard3])
        expect(rule).to be_eligible(order)
      end

      context "when any of the order's greetingcards are in eligible greetingcards" do
        before do
          allow(order).to receive_messages(greetingcards: [@greetingcard1, @greetingcard2])
          allow(rule).to receive_messages(eligible_greetingcards: [@greetingcard2, @greetingcard3])
        end
        it { expect(rule).not_to be_eligible(order) }
        it "sets an error message" do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "Your cart contains a greetingcard that prevents this coupon code from being applied."
        end
      end
    end
  end

  describe '#actionable?' do
    subject do
      rule.actionable?(line_item)
    end

    let(:rule_line_item) { Spree::LineItem.new(greetingcard: rule_greetingcard) }
    let(:other_line_item) { Spree::LineItem.new(greetingcard: other_greetingcard) }

    let(:rule_options) { super().merge(greetingcards: [rule_greetingcard]) }
    let(:rule_greetingcard) { mock_model(Spree::Greetingcard) }
    let(:other_greetingcard) { mock_model(Spree::Greetingcard) }

    context "with 'any' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'any') }

      context 'for greetingcard in rule' do
        let(:line_item) { rule_line_item }
        it { should be_truthy }
      end

      context 'for greetingcard not in rule' do
        let(:line_item) { other_line_item }
        it { should be_falsey }
      end
    end

    context "with 'all' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'all') }

      context 'for greetingcard in rule' do
        let(:line_item) { rule_line_item }
        it { should be_truthy }
      end

      context 'for greetingcard not in rule' do
        let(:line_item) { other_line_item }
        it { should be_falsey }
      end
    end

    context "with 'none' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'none') }

      context 'for greetingcard in rule' do
        let(:line_item) { rule_line_item }
        it { should be_falsey }
      end

      context 'for greetingcard not in rule' do
        let(:line_item) { other_line_item }
        it { should be_truthy }
      end
    end
  end
end
