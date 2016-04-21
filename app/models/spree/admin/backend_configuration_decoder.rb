Spree::BackendConfiguration.class_eval do 
    
    GREETINGCARD_TABS       ||= [:greetingcards, :option_types, :prototypes,
                            :variants, :greetingcard_properties, :taxonomies,
                            :taxons]
end