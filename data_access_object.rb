require 'pp'

class DataAccessObject


  #
  # boolean methods that answers the question "did the passed in hash have all the keys declared by @fields?""
  #
  def contains_expected_attributes?(hash)

    contains_expected = true 
    @fields.each do |field|
      contains_expected = false unless @fields.include?(field)
    end
    contains_expected
  end
  

  def create_method(name, &block)
    self.class.send(:define_method, name, &block)
  end



  #
  # create instance variables for all of the hash keys
  #
  def populate  hash
    raise  "Not all expected values were passed. Expected #{@fields}" unless contains_expected_attributes?(hash)
    @fields.each  do |field_name| 
      instance_variable_set("@#{field_name.to_s}" , hash[field_name])  
      create_method (field_name.to_sym) do 
        instance_eval("@#{field_name}")
      end
      create_method ("#{field_name}=".to_sym) do |value|
        @dirty = true
        instance_eval("@#{field_name} = value")
      end
    end
  end


 
  #
  # call this methods when loading data from the database - in other words, re-hydrating an object with known state.
  #
  def self.load(hash)
    instance = allocate    
    instance.set_fields
    instance.load(hash)
    instance
  end


  def insert?
    @type == 'insert'
  end


  def update?
    @type == 'update'
  end


  #
  #  called on the instance, note that dirty is set to false.
  #
  def load(hash) 
    populate(hash)
    @dirty = false
    @type = 'update'
  end



  #
  # Call this method when creating a the bookmark for the first time 
  #
  def self.load_new(hash)
    instance = allocate
    instance.set_fields
    instance.load_new(hash)
    instance
  end


  #
  #  called on the instance, note that dirty is set to true.
  #
  def load_new(hash)
    populate(hash)
    @dirty = true
    @type = 'insert'
  end



  def dirty?
    @dirty
  end

end
