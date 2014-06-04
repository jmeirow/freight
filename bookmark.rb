require 'pp'
require_relative './data_access_object.rb'


class Bookmark < DataAccessObject 

  def set_fields
    @fields = [ :member_id, :has_enough_money, :statement_created, :sufficient_balance_date]
  end

end

