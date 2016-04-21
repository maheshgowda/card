Spree::Api::V1::ClassificationsController.class_eval do
    
    def update
          authorize! :update, Greetingcard
          authorize! :update, Taxon
          classification = Spree::Classification.find_by(
            greetingcard_id: params[:greetingcard_id],
            taxon_id: params[:taxon_id]
          )
          # Because position we get back is 0-indexed.
          # acts_as_list is 1-indexed.
          classification.insert_at(params[:position].to_i + 1)
          render nothing: true
    end
end