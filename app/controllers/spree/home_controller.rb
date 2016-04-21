module Spree
  class HomeController < Spree::StoreController
    helper 'spree/products'
    helper 'spree/greetingcards'
    respond_to :html

    def index
      @searcher = build_searcher(params.merge(include_images: true))
      @products = @searcher.retrieve_products.includes(:possible_promotions)
      @greetingcards = @searcher.retrieve_greetingcards.includes(:possible_promotions)
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end
  end
end
