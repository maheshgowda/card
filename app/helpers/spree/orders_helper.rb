require 'truncate_html'
require 'app/helpers/truncate_html_helper'

module Spree
  module OrdersHelper
    include TruncateHtmlHelper

    def truncated_product_description(product)
      truncate_html(raw(product.description))
    end
    
    def truncated_greetingcard_description(greetingcard)
      truncate_html(raw(greetingcard.description))
    end

    def order_just_completed?(order)
      flash[:order_completed] && order.present?
    end
  end
end
