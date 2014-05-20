
require_relative './data_access_object.rb'


class DailyRateContribution 
  include DataAccessObject 

  attr_accessor :member_id, :week_starting_date, :user_date, :amount, :company_information_id

  

  def initialize attributes
    fields =  [:member_id, :week_starting_date, :user_date, :amount, :company_information_id]
    populate fields, attributes
  end

end
