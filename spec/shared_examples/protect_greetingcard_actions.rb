shared_examples "modifying greetingcard actions are restricted" do
  it "cannot create a new greetingcard if not an admin" do
    api_post :create, :greetingcard => { :name => "Brand new greetingcard!" }
    assert_unauthorized!
  end

  it "cannot update a greetingcard" do
    api_put :update, :id => greetingcard.to_param, :greetingcard => { :name => "I hacked your store!" }
    assert_unauthorized!
  end

  it "cannot delete a greetingcard" do
    api_delete :destroy, :id => greetingcard.to_param
    assert_unauthorized!
  end
end

