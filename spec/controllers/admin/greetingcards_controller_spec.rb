require 'spec_helper'

describe Spree::Admin::GreetingcardsController, type: :controller do
  stub_authorization!

  context "#index" do
    let(:ability_user) { stub_model(Spree::LegacyUser, :has_spree_role? => true) }

    # Regression test for #1259
    it "can find a greetingcard by SKU" do
      greetingcard = create(:greetingcard, :sku => "ABC123")
      spree_get :index, :q => { :sku_start => "ABC123" }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(greetingcard)
    end
  end


  # regression test for #801
  describe '#destroy' do
    let(:greetingcard) { mock_model(Spree::Greetingcard) }
    let(:greetingcards) { double(ActiveRecord::Relation) }

    def send_request
      spree_delete :destroy, id: greetingcard, format: :js
    end

    context 'will successfully destroy greetingcard' do
      before do
        allow(Spree::Greetingcard).to receive(:friendly).and_return(greetingcards)
        allow(greetingcards).to receive(:find).with(greetingcard.id.to_s).and_return(greetingcard)
        allow(greetingcard).to receive(:destroy).and_return(true)
      end

      describe 'expects to receive' do
        it { expect(Spree::Greetingcard).to receive(:friendly).and_return(greetingcards) }
        it { expect(greetingcards).to receive(:find).with(greetingcard.id.to_s).and_return(greetingcard) }
        it { expect(greetingcard).to receive(:destroy).and_return(true) }

        after { send_request }
      end

      describe 'assigns' do
        before { send_request }
        it { expect(assigns(:greetingcard)).to eq(greetingcard) }
      end

      describe 'response' do
        before { send_request }
        it { expect(response).to have_http_status(:ok) }
        it { expect(flash[:success]).to eq(Spree.t('notice_messages.greetingcard_deleted')) }
      end
    end

    context 'will not successfully destroy greetingcard' do
      let!(:error_message) { 'Test error' }

      before do
        allow(Spree::Greetingcard).to receive(:friendly).and_return(greetingcards)
        allow(greetingcards).to receive(:find).with(greetingcard.id.to_s).and_return(greetingcard)
        allow(greetingcard).to receive(:destroy).and_return(false)
        allow(greetingcard).to receive_message_chain(:errors, :full_messages).and_return([error_message])
      end

      describe 'expects to receive' do
        it { expect(Spree::Greetingcard).to receive(:friendly).and_return(greetingcards) }
        it { expect(greetingcards).to receive(:find).with(greetingcard.id.to_s).and_return(greetingcard) }
        it { expect(greetingcard).to receive(:destroy).and_return(false) }

        after { send_request }
      end

      describe 'assigns' do
        before { send_request }
        it { expect(assigns(:greetingcard)).to eq(greetingcard) }
      end

      describe 'response' do
        before { send_request }
        it { expect(response).to have_http_status(:ok) }
        it { expect(flash[:error]).to eq(error_message) }
      end
    end
  end

  context "stock" do
    let(:greetingcard) { create(:greetingcard) }
    it "restricts stock location based on accessible attributes" do
      expect(Spree::StockLocation).to receive(:accessible_by).and_return([])
      spree_get :stock, :id => greetingcard
    end
  end
end
