require 'spec_helper'
require 'shared_examples/protect_greetingcard_actions'

module Spree
  describe Api::V1::GreetingcardsController, :type => :controller do
    render_views

    let!(:greetingcard) { create(:greetingcard) }
    let!(:inactive_greetingcard) { create(:greetingcard, available_on: Time.current.tomorrow, name: "inactive") }
    let(:base_attributes) { Api::ApiHelpers.greetingcard_attributes }
    let(:show_attributes) { base_attributes.dup.push(:has_variants) }
    let(:new_attributes) { base_attributes }

    let(:greetingcard_data) do
      { name: "The Other Greetingcard",
        price: 19.99,
        shipping_category_id: create(:shipping_category).id }
    end
    let(:attributes_for_variant) do
      h = attributes_for(:variant).except(:option_values, :greetingcard)
      h.merge({
        options: [
          { name: "size", value: "small" },
          { name: "color", value: "black" }
        ]
      })
    end

    before do
      stub_authentication!
    end

    context "as a normal user" do
      context "with caching enabled" do
        let!(:greetingcard_2) { create(:greetingcard) }

        before do
          ActionController::Base.perform_caching = true
        end

        it "returns unique greetingcards" do
          api_get :index
          greetingcard_ids = json_response["greetingcards"].map { |p| p["id"] }
          expect(greetingcard_ids.uniq.count).to eq(greetingcard_ids.count)
        end

        after do
          ActionController::Base.perform_caching = false
        end
      end

      it "retrieves a list of greetingcards" do
        api_get :index
        expect(json_response["greetingcards"].first).to have_attributes(show_attributes)
        expect(json_response["total_count"]).to eq(1)
        expect(json_response["current_page"]).to eq(1)
        expect(json_response["pages"]).to eq(1)
        expect(json_response["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      it "retrieves a list of greetingcards by id" do
        api_get :index, :ids => [greetingcard.id]
        expect(json_response["greetingcards"].first).to have_attributes(show_attributes)
        expect(json_response["total_count"]).to eq(1)
        expect(json_response["current_page"]).to eq(1)
        expect(json_response["pages"]).to eq(1)
        expect(json_response["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      context "greetingcard has more than one price" do
        before { greetingcard.master.prices.create currency: "EUR", amount: 22 }

        it "returns distinct greetingcards only" do
          api_get :index
          expect(assigns(:greetingcards).map(&:id).uniq).to eq assigns(:greetingcards).map(&:id)
        end
      end

      it "retrieves a list of greetingcards by ids string" do
        second_greetingcard = create(:greetingcard)
        api_get :index, :ids => [greetingcard.id, second_greetingcard.id].join(",")
        expect(json_response["greetingcards"].first).to have_attributes(show_attributes)
        expect(json_response["greetingcards"][1]).to have_attributes(show_attributes)
        expect(json_response["total_count"]).to eq(2)
        expect(json_response["current_page"]).to eq(1)
        expect(json_response["pages"]).to eq(1)
        expect(json_response["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      it "does not return inactive greetingcards when queried by ids" do
        api_get :index, :ids => [inactive_greetingcard.id]
        expect(json_response["count"]).to eq(0)
      end

      it "does not list unavailable greetingcards" do
        api_get :index
        expect(json_response["greetingcards"].first["name"]).not_to eq("inactive")
      end

      context "pagination" do
        it "can select the next page of greetingcards" do
          second_greetingcard = create(:greetingcard)
          api_get :index, :page => 2, :per_page => 1
          expect(json_response["greetingcards"].first).to have_attributes(show_attributes)
          expect(json_response["total_count"]).to eq(2)
          expect(json_response["current_page"]).to eq(2)
          expect(json_response["pages"]).to eq(2)
        end

        it 'can control the page size through a parameter' do
          create(:greetingcard)
          api_get :index, :per_page => 1
          expect(json_response['count']).to eq(1)
          expect(json_response['total_count']).to eq(2)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(2)
        end
      end

      it "can search for greetingcards" do
        create(:greetingcard, :name => "The best greetingcard in the world")
        api_get :index, :q => { :name_cont => "best" }
        expect(json_response["greetingcards"].first).to have_attributes(show_attributes)
        expect(json_response["count"]).to eq(1)
      end

      it "gets a single greetingcard" do
        greetingcard.master.images.create!(:attachment => image("thinking-cat.jpg"))
        create(:variant, greetingcard: greetingcard)
        greetingcard.variants.first.images.create!(:attachment => image("thinking-cat.jpg"))
        greetingcard.taxons << create(:taxon)

        api_get :show, :id => greetingcard.to_param

        expect(json_response).to have_attributes(show_attributes)
        expect(json_response['variants'].first).to have_attributes([:name,
                                                              :is_master,
                                                              :price,
                                                              :images,
                                                              :in_stock])

        expect(json_response['variants'].first['images'].first).to have_attributes([:attachment_file_name,
                                                                                :attachment_width,
                                                                                :attachment_height,
                                                                                :attachment_content_type,
                                                                                :mini_url,
                                                                                :small_url,
                                                                                :greetingcard_url,
                                                                                :large_url])

        expect(json_response["classifications"].first).to have_attributes([:taxon_id, :position, :taxon])
        expect(json_response["classifications"].first['taxon']).to have_attributes([:id, :name, :pretty_name, :permalink, :taxonomy_id, :parent_id])
      end

      context "tracking is disabled" do
        before { Config.track_inventory_levels = false }

        it "still displays valid json with total_on_hand Float::INFINITY" do
          api_get :show, :id => greetingcard.to_param
          expect(response).to be_ok
          expect(json_response[:total_on_hand]).to eq nil
        end

        after { Config.track_inventory_levels = true }
      end

      context "finds a greetingcard by slug first then by id" do
        let!(:other_greetingcard) { create(:greetingcard, :slug => "these-are-not-the-droids-you-are-looking-for") }

        before do
          greetingcard.update_column(:slug, "#{other_greetingcard.id}-and-1-ways")
        end

        specify do
          api_get :show, :id => greetingcard.to_param
          expect(json_response["slug"]).to match(/and-1-ways/)
          greetingcard.destroy

          api_get :show, :id => other_greetingcard.id
          expect(json_response["slug"]).to match(/droids/)
        end
      end

      it "cannot see inactive greetingcards" do
        api_get :show, :id => inactive_greetingcard.to_param
        assert_not_found!
      end

      it "returns a 404 error when it cannot find a greetingcard" do
        api_get :show, :id => "non-existant"
        assert_not_found!
      end

      it "can learn how to create a new greetingcard" do
        api_get :new
        expect(json_response["attributes"]).to eq(new_attributes.map(&:to_s))
        required_attributes = json_response["required_attributes"]
        expect(required_attributes).to include("name")
        expect(required_attributes).to include("price")
        expect(required_attributes).to include("shipping_category")
      end

      it_behaves_like "modifying greetingcard actions are restricted"
    end

    context "as an admin" do
      let(:taxon_1) { create(:taxon) }
      let(:taxon_2) { create(:taxon) }

      sign_in_as_admin!

      it "can see all greetingcards" do
        api_get :index
        expect(json_response["greetingcards"].count).to eq(2)
        expect(json_response["count"]).to eq(2)
        expect(json_response["current_page"]).to eq(1)
        expect(json_response["pages"]).to eq(1)
      end

      # Regression test for #1626
      context "deleted greetingcards" do
        before do
          create(:greetingcard, :deleted_at => 1.day.ago)
        end

        it "does not include deleted greetingcards" do
          api_get :index
          expect(json_response["greetingcards"].count).to eq(2)
        end

        it "can include deleted greetingcards" do
          api_get :index, :show_deleted => 1
          expect(json_response["greetingcards"].count).to eq(3)
        end
      end

      describe "creating a greetingcard" do
        it "can create a new greetingcard" do
          api_post :create, :greetingcard => { :name => "The Other Greetingcard",
                                          :price => 19.99,
                                          :shipping_category_id => create(:shipping_category).id }
          expect(json_response).to have_attributes(base_attributes)
          expect(response.status).to eq(201)
        end

        it "creates with embedded variants" do
          greetingcard_data.merge!({
            variants: [attributes_for_variant, attributes_for_variant]
          })

          api_post :create, :greetingcard => greetingcard_data
          expect(response.status).to eq 201

          variants = json_response['variants']
          expect(variants.count).to eq(2)
          expect(variants.last['option_values'][0]['name']).to eq('small')
          expect(variants.last['option_values'][0]['option_type_name']).to eq('size')

          expect(json_response['option_types'].count).to eq(2) # size, color
        end
          api_post :create, :greetingcard => greetingcard_data
        end

        it "can create a new greetingcard with option_types" do
          greetingcard_data.merge!({
            option_types: ['size', 'color']
          })

          api_post :create, :greetingcard => greetingcard_data
          expect(json_response['option_types'].count).to eq(2)
        end

        it "creates greetingcard with option_types ids" do
          option_type = create(:option_type)
          greetingcard_data.merge!(option_type_ids: [option_type.id])
          api_post :create, greetingcard: greetingcard_data
          expect(json_response['option_types'].first['id']).to eq option_type.id
        end

        it "creates with shipping categories" do
          hash = { :name => "The Other Greetingcard",
                   :price => 19.99,
                   :shipping_category => "Free Ships" }

          api_post :create, :greetingcard => hash
          expect(response.status).to eq 201

          shipping_id = ShippingCategory.find_by_name("Free Ships").id
          expect(json_response['shipping_category_id']).to eq shipping_id
        end

        it "puts the created greetingcard in the given taxons" do
          greetingcard_data[:taxon_ids] = [taxon_1.id, taxon_2.id]
          api_post :create, greetingcard: greetingcard_data
          expect(json_response["taxon_ids"]).to eq([taxon_1.id, taxon_2.id])
        end

        # Regression test for #2140
        context "with authentication_required set to false" do
          before do
            Spree::Api::Config.requires_authentication = false
          end

          after do
            Spree::Api::Config.requires_authentication = true
          end

          it "can still create a greetingcard" do
            api_post :create, :greetingcard => greetingcard_data, :token => "fake"
            expect(json_response).to have_attributes(show_attributes)
            expect(response.status).to eq(201)
          end
        end

        it "cannot create a new greetingcard with invalid attributes" do
          api_post :create, greetingcard: {}
          expect(response.status).to eq(422)
          expect(json_response["error"]).to eq("Invalid resource. Please fix errors and try again.")
          errors = json_response["errors"]
          errors.delete("slug") # Don't care about this one.
          expect(errors.keys).to match_array(["name", "price", "shipping_category"])
        end
      end

      context 'updating a greetingcard' do
        it "can update a greetingcard" do
          api_put :update, :id => greetingcard.to_param, :greetingcard => { :name => "New and Improved Greetingcard!" }
          expect(response.status).to eq(200)
        end

        it "can create new option types on a greetingcard" do
          api_put :update, :id => greetingcard.to_param, :greetingcard => { :option_types => ['shape', 'color'] }
          expect(json_response['option_types'].count).to eq(2)
        end

        it "can create new variants on a greetingcard" do
          api_put :update, :id => greetingcard.to_param, :greetingcard => { :variants => [attributes_for_variant, attributes_for_variant.merge(sku: "ABC-#{Kernel.rand(9999)}")] }
          expect(response.status).to eq 200
          expect(json_response['variants'].count).to eq(2) # 2 variants

          variants = json_response['variants'].select { |v| !v['is_master'] }
          expect(variants.last['option_values'][0]['name']).to eq('small')
          expect(variants.last['option_values'][0]['option_type_name']).to eq('size')

          expect(json_response['option_types'].count).to eq(2) # size, color
        end

        it "can update an existing variant on a greetingcard" do
          variant_hash = {
            :sku => '123', :price => 19.99, :options => [{:name => "size", :value => "small"}]
          }
          variant_id = greetingcard.variants.create!({ greetingcard: greetingcard }.merge(variant_hash)).id

          api_put :update, :id => greetingcard.to_param, :greetingcard => {
            :variants => [
              variant_hash.merge(
                :id => variant_id.to_s,
                :sku => '456',
                :options => [{:name => "size", :value => "large" }]
              )
            ]
          }

          expect(json_response['variants'].count).to eq(1)
          variants = json_response['variants'].select { |v| !v['is_master'] }
          expect(variants.last['option_values'][0]['name']).to eq('large')
          expect(variants.last['sku']).to eq('456')
          expect(variants.count).to eq(1)
        end

        it "cannot update a greetingcard with an invalid attribute" do
          api_put :update, :id => greetingcard.to_param, :greetingcard => { :name => "" }
          expect(response.status).to eq(422)
          expect(json_response["error"]).to eq("Invalid resource. Please fix errors and try again.")
          expect(json_response["errors"]["name"]).to eq(["can't be blank"])
        end

        it "puts the updated greetingcard in the given taxons" do
          api_put :update, id: greetingcard.to_param, greetingcard: { taxon_ids: [taxon_1.id, taxon_2.id] }
          expect(json_response["taxon_ids"].to_set).to eql([taxon_1.id, taxon_2.id].to_set)
        end
      end

      it "can delete a greetingcard" do
        expect(greetingcard.deleted_at).to be_nil
        api_delete :destroy, :id => greetingcard.to_param
        expect(response.status).to eq(204)
        expect(greetingcard.reload.deleted_at).not_to be_nil
      end
    end
  end
end
