require_relative './data_access_object.rb'

class FreightBankWeek < DataAccessObject 

  def set_fields
    @fields = [  :txn_id, :week_starting_date, :damages]
  end

end


