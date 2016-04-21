Spree::BaseController.class_eval do
      
      private
      
      def find_greetingcard(id)
        greetingcard_scope.friendly.find(id.to_s)
      rescue ActiveRecord::RecordNotFound
        greetingcard_scope.find(id)
      end
      
      def greetingcard_scope
        if @current_user_roles.include?("admin")
          scope = Greetingcard.with_deleted.accessible_by(current_ability, :read).includes(*greetingcard_includes)

          unless params[:show_deleted]
            scope = scope.not_deleted
          end
          unless params[:show_discontinued]
            scope = scope.not_discontinued
          end
        else
          scope = Greetingcard.accessible_by(current_ability, :read).active.includes(*greetingcard_includes)
        end

        scope
      end
      
      def greetingcard_includes
        [:option_types, :taxons, greetingcard_properties: :property, variants: variants_associations, master: variants_associations]
      end
end
