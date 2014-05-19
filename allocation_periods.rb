require_relative './date.rb'


module AllocationPeriods


    FREIGHT_ACCUM_START_DATE ||= Date.new(2012,4,1).mctwf_sunday_of_week

    ALLOCATION_PERIODS =  
    [
      Date.new(2012,4, 1)..Date.new(2015,3,28),
      Date.new(2015,3,29)..Date.new(2018,3,31),
      Date.new(2018,4, 1)..Date.new(2021,3,27),
      Date.new(2021,3, 28)..Date.new(2024,3,30)
    ]


  def current_allocation_period
    ALLOCATION_PERIODS.first{|x| x.cover? Date.today }
  end

end
