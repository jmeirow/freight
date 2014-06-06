require 'pp'
require_relative './data_access_object.rb'


class Bookmark < DataAccessObject 

  def set_fields
    @fields = [ :member_id, :has_enough_money,    :date_initial_statement_created ]
  end


  def initial_statement_created?
    !(date_initial_statement_created.nil?)
  end

end

