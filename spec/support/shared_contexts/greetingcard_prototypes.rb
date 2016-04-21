shared_context "greetingcard prototype" do

  def build_option_type_with_values(name, values)
    ot = FactoryGirl.create(:option_type, :name => name)
    values.each do |val|
      ot.option_values.create(:name => val.downcase, :presentation => val)
    end
    ot
  end

  let(:greetingcard_attributes) do
    # FactoryGirl.attributes_for is un-deprecated!
    #   https://github.com/thoughtbot/factory_girl/issues/274#issuecomment-3592054
    FactoryGirl.attributes_for(:base_greetingcard)
  end

  let(:prototype) do
    size = build_option_type_with_values("size", %w(Small Medium Large))
    FactoryGirl.create(:prototype, :name => "Size", :option_types => [ size ])
  end

  let(:option_values_hash) do
    hash = {}
    prototype.option_types.each do |i|
      hash[i.id.to_s] = i.option_value_ids
    end
    hash
  end

end
