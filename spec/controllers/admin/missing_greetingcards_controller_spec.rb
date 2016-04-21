require 'spec_helper'
# This test exists in this file because in the standard admin/greetingcards_controller spec
# There is the stub_authorization call. This call is not triggered for this test because
# the load_resource filter in Spree::Admin::ResourceController is prepended to the filter chain
# this means this call is triggered before the authorize_admin call and in this case
# the load_resource filter halts the request meaning authorize_admin is not called at all.
describe Spree::Admin::GreetingcardsController, :type => :controller do
  stub_authorization!

  # Regression test for GH #538
  it "cannot find a non-existent greetingcard" do
    spree_get :edit, :id => "non-existent-greetingcard"
    expect(response).to redirect_to(spree.admin_greetingcards_path)
    expect(flash[:error]).to eql("Greetingcard is not found")
  end
end


