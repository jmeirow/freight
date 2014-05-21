require_relative './data_access_object.rb'


class FreightBankWeek 
  include DataAccessObject 

  attr_accessor :txn_id, :week_starting_date, :damages



  def initialize attributes  
    fields =  [:txn_id, :week_starting_date, :damages]
    populate fields, attributes
  end

end


