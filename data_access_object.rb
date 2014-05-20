
module DataAccessObject

  def contains_expected_attributes?(fields, hash)
    contains_expected = true 
    fields.each do |field|
      contains_expected unless (hash[field].nil? == false)
    end
    contains_expected
  end
  
  def populate fields,  hash
    raise  "Not all expected values were passed. Expected #{@fields}" unless contains_expected_attributes?(fields, hash)
    fields.each  { |field_name| instance_variable_set("@#{field_name.to_s}" , hash[field_name]) }
  end


end