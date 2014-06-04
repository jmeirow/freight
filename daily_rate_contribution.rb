require_relative './data_access_object.rb'

class DailyRateContribution < DataAccessObject

  def set_fields
    @fields = [  :member_id, :week_starting_date, :user_date, :amount, :company_information_id]
  end

end
