require 'shared_examples/protect_greetingcard_actions'
require 'spec_helper'

module Spree
  describe Api::V1::GreetingcardsController, :type => :controller do
    render_views

    let!(:greetingcard) { create(:greetingcard) }
    let(:attributes) { [:id, :name, :description, :price, :available_on, :slug, :meta_description, :meta_keywords, :taxon_ids] }

    context "without authentication" do
      before { Spree::Api::Config[:requires_authentication] = false }

      it "retrieves a list of greetingcards" do
        api_get :index
        expect(json_response["greetingcards"].first).to have_attributes(attributes)
        expect(json_response["count"]).to eq(1)
        expect(json_response["current_page"]).to eq(1)
        expect(json_response["pages"]).to eq(1)
      end

      it_behaves_like "modifying greetingcard actions are restricted"
    end
  end
end

